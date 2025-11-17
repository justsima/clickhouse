#!/bin/bash
# Phase 3 - Deploy Connectors Script
# Purpose: Deploy Debezium MySQL Source and ClickHouse Sink connectors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "========================================"
echo "   Connector Deployment"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Helper function to substitute environment variables in JSON
substitute_vars() {
    local template="$1"
    local result="$template"

    result=$(echo "$result" | sed "s/\${MYSQL_HOST}/$MYSQL_HOST/g")
    result=$(echo "$result" | sed "s/\${MYSQL_PORT}/$MYSQL_PORT/g")
    result=$(echo "$result" | sed "s/\${MYSQL_USER}/$MYSQL_USER/g")
    result=$(echo "$result" | sed "s|\${MYSQL_PASSWORD}|$MYSQL_PASSWORD|g")
    result=$(echo "$result" | sed "s/\${MYSQL_DATABASE}/$MYSQL_DATABASE/g")
    result=$(echo "$result" | sed "s/\${CLICKHOUSE_HOST}/$CLICKHOUSE_HOST/g")
    result=$(echo "$result" | sed "s/\${CLICKHOUSE_PORT}/$CLICKHOUSE_PORT/g")
    result=$(echo "$result" | sed "s/\${CLICKHOUSE_USER}/$CLICKHOUSE_USER/g")
    result=$(echo "$result" | sed "s|\${CLICKHOUSE_PASSWORD}|$CLICKHOUSE_PASSWORD|g")
    result=$(echo "$result" | sed "s/\${CLICKHOUSE_DATABASE}/$CLICKHOUSE_DATABASE/g")

    echo "$result"
}

echo "1. Checking Kafka Connect Status"
echo "---------------------------------"

CONNECT_URL="http://localhost:8085"

if curl -s "$CONNECT_URL/" | grep -q "version"; then
    print_status 0 "Kafka Connect is running"
else
    print_status 1 "Kafka Connect is not responding"
    echo "Please ensure Phase 2 services are running"
    exit 1
fi

echo ""
echo "2. Installing ClickHouse Connector Plugin"
echo "------------------------------------------"

print_info "Checking if ClickHouse connector is installed..."

# Check if connector plugin exists
PLUGINS=$(curl -s "$CONNECT_URL/connector-plugins" | grep -o "ClickHouseSinkConnector" || echo "")

if [ -z "$PLUGINS" ]; then
    echo -e "${YELLOW}ClickHouse connector not found. Installing...${NC}"

    # Download and install ClickHouse Kafka connector
    docker exec kafka-connect-clickhouse bash -c "
        cd /tmp &&
        curl -L -o clickhouse-kafka-connect.tar.gz \
            https://github.com/ClickHouse/clickhouse-kafka-connect/releases/download/v1.0.0/clickhouse-kafka-connect-v1.0.0.tar.gz &&
        mkdir -p /kafka/connect/clickhouse-connector &&
        tar -xzf clickhouse-kafka-connect.tar.gz -C /kafka/connect/clickhouse-connector &&
        rm clickhouse-kafka-connect.tar.gz
    " 2>&1 | grep -v "curl: "

    echo ""
    print_info "Restarting Kafka Connect to load new plugin..."
    docker restart kafka-connect-clickhouse
    sleep 20

    print_status 0 "ClickHouse connector installed"
else
    print_status 0 "ClickHouse connector already installed"
fi

echo ""
echo "3. Deploying Debezium MySQL Source Connector"
echo "---------------------------------------------"

# Read and substitute template
DEBEZIUM_CONFIG=$(cat "$CONFIG_DIR/debezium-mysql-source.json")
DEBEZIUM_CONFIG=$(substitute_vars "$DEBEZIUM_CONFIG")

# Delete existing connector if it exists
curl -s -X DELETE "$CONNECT_URL/connectors/mysql-source-connector" 2>/dev/null || true
sleep 2

# Deploy connector
RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$DEBEZIUM_CONFIG")

if echo "$RESPONSE" | grep -q "mysql-source-connector"; then
    print_status 0 "Debezium MySQL source connector deployed"
else
    print_status 1 "Failed to deploy Debezium connector"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "4. Deploying ClickHouse Sink Connector"
echo "---------------------------------------"

# Read and substitute template
CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

# Delete existing connector if it exists
curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || true
sleep 2

# Deploy connector
RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "ClickHouse sink connector deployed"
else
    print_status 1 "Failed to deploy ClickHouse sink connector"
    echo "Response: $RESPONSE"
    echo "Note: If this fails, we may need to use an alternative sink approach"
fi

echo ""
echo "5. Verifying Connector Status"
echo "------------------------------"

sleep 5

# Check Debezium status
print_info "Checking Debezium MySQL source connector..."
DEBEZIUM_STATUS=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
    print_status 0 "Debezium connector status: $DEBEZIUM_STATUS"
else
    print_status 1 "Debezium connector status: $DEBEZIUM_STATUS"
    echo "Check logs: docker logs kafka-connect-clickhouse"
fi

# Check ClickHouse sink status
print_info "Checking ClickHouse sink connector..."
SINK_STATUS=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "NOT_FOUND")
if [ "$SINK_STATUS" = "RUNNING" ]; then
    print_status 0 "ClickHouse sink connector status: $SINK_STATUS"
elif [ "$SINK_STATUS" = "NOT_FOUND" ]; then
    echo -e "${YELLOW}⚠ ClickHouse sink connector not deployed (will use alternative approach)${NC}"
else
    print_status 1 "ClickHouse sink connector status: $SINK_STATUS"
fi

echo ""
echo "6. Listing Active Connectors"
echo "-----------------------------"

curl -s "$CONNECT_URL/connectors" | python3 -m json.tool 2>/dev/null || curl -s "$CONNECT_URL/connectors"

echo ""
echo ""
echo "========================================"
echo "   Deployment Complete!"
echo "========================================"
echo ""
echo "Connectors deployed:"
echo "  - Debezium MySQL Source: $DEBEZIUM_STATUS"
echo "  - ClickHouse Sink: $SINK_STATUS"
echo ""
echo "Monitoring URLs:"
echo "  Kafka Connect API: $CONNECT_URL"
echo "  Redpanda Console: http://localhost:8086"
echo ""
echo "Check connector details:"
echo "  curl $CONNECT_URL/connectors/mysql-source-connector/status | jq"
echo ""
echo "Next step: Run 04_monitor_snapshot.sh to track progress"
echo ""
