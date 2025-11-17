#!/bin/bash
# Phase 3 - Deploy Connectors Script
# Purpose: Deploy Debezium MySQL Source and ClickHouse JDBC Sink connectors

set +e

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

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

echo "========================================"
echo "   Connector Deployment"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    print_error ".env file not found"
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
    result=$(echo "$result" | sed "s/\${CLICKHOUSE_NATIVE_PORT}/$CLICKHOUSE_NATIVE_PORT/g")
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
echo "2. Installing ClickHouse JDBC Driver"
echo "-------------------------------------"

print_info "Checking if ClickHouse JDBC driver is installed..."

# Check if driver already exists
if docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-jdbc/clickhouse-jdbc.jar &>/dev/null; then
    print_status 0 "ClickHouse JDBC driver already installed"
else
    echo "Installing ClickHouse JDBC driver..."

    # Download ClickHouse JDBC driver
    JDBC_VERSION="0.6.0"
    JDBC_URL="https://github.com/ClickHouse/clickhouse-java/releases/download/v${JDBC_VERSION}/clickhouse-jdbc-${JDBC_VERSION}-shaded.jar"

    docker exec kafka-connect-clickhouse bash -c "
        mkdir -p /kafka/connect/clickhouse-jdbc &&
        cd /kafka/connect/clickhouse-jdbc &&
        curl -L -o clickhouse-jdbc.jar '$JDBC_URL' 2>&1
    " | grep -v "^\s*$" | head -5

    # Verify download
    if docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-jdbc/clickhouse-jdbc.jar &>/dev/null; then
        FILESIZE=$(docker exec kafka-connect-clickhouse stat -c%s /kafka/connect/clickhouse-jdbc/clickhouse-jdbc.jar)

        if [ "$FILESIZE" -gt 1000000 ]; then
            print_status 0 "ClickHouse JDBC driver installed (${FILESIZE} bytes)"

            print_info "Restarting Kafka Connect to load JDBC driver..."
            docker restart kafka-connect-clickhouse >/dev/null 2>&1

            # Wait for Kafka Connect to be ready
            print_info "Waiting for Kafka Connect to initialize..."
            for i in {1..12}; do
                if curl -s "$CONNECT_URL/" | grep -q "version"; then
                    print_status 0 "Kafka Connect restarted and ready"
                    break
                fi
                echo -n "."
                sleep 5
            done
            echo ""
        else
            print_error "Downloaded file is too small ($FILESIZE bytes) - download failed"
            exit 1
        fi
    else
        print_error "JDBC driver download failed"
        exit 1
    fi
fi

echo ""
echo "3. Verifying Available Connectors"
echo "-----------------------------------"

# List available connectors with retry
CONNECTORS=""
for attempt in {1..5}; do
    CONNECTORS=$(curl -s "$CONNECT_URL/connector-plugins" 2>/dev/null | grep -o '"class":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$CONNECTORS" ]; then
        break
    fi
    echo "Waiting for connector plugins to load (attempt $attempt/5)..."
    sleep 3
done

if [ -z "$CONNECTORS" ]; then
    print_error "Could not retrieve connector plugins from Kafka Connect"
    echo "Try manually: curl http://localhost:8085/connector-plugins"
    exit 1
fi

print_info "Available connector plugins:"
echo "$CONNECTORS" | grep -E "(MySql|Jdbc)" | sed 's/^/  - /'

# Verify Debezium MySQL and JDBC Sink are available
if echo "$CONNECTORS" | grep -q "io.debezium.connector.mysql.MySqlConnector"; then
    print_status 0 "Debezium MySQL connector available"
else
    print_error "Debezium MySQL connector not found"
    echo "Available connectors:"
    echo "$CONNECTORS"
    exit 1
fi

if echo "$CONNECTORS" | grep -q "io.debezium.connector.jdbc.JdbcSinkConnector"; then
    print_status 0 "Debezium JDBC Sink connector available"
else
    print_error "Debezium JDBC Sink connector not found"
    echo "Available connectors:"
    echo "$CONNECTORS"
    exit 1
fi

echo ""
echo "4. Deploying Debezium MySQL Source Connector"
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
elif echo "$RESPONSE" | grep -q "error"; then
    print_error "Failed to deploy Debezium connector"
    echo "Response: $RESPONSE"
    exit 1
else
    print_status 0 "Debezium MySQL source connector deployed"
fi

echo ""
echo "5. Deploying ClickHouse JDBC Sink Connector"
echo "--------------------------------------------"

# Read and substitute template - use JDBC sink config
if [ -f "$CONFIG_DIR/clickhouse-jdbc-sink.json" ]; then
    CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-jdbc-sink.json")
else
    print_error "clickhouse-jdbc-sink.json not found"
    echo "Using Debezium JDBC Sink connector for ClickHouse"
    exit 1
fi

CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

# Delete existing connector if it exists
curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || true
sleep 2

# Deploy connector
RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "ClickHouse JDBC sink connector deployed"
elif echo "$RESPONSE" | grep -q "error"; then
    print_error "Failed to deploy ClickHouse sink connector"
    echo "Response: $RESPONSE" | head -20
    echo ""
    echo "This is expected if JDBC driver needs additional configuration."
    echo "Data will still be captured in Kafka topics."
fi

echo ""
echo "6. Verifying Connector Status"
echo "------------------------------"

sleep 5

# Check Debezium status
print_info "Checking Debezium MySQL source connector..."
DEBEZIUM_STATUS=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")

if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
    print_status 0 "Debezium connector status: $DEBEZIUM_STATUS"
else
    print_status 1 "Debezium connector status: $DEBEZIUM_STATUS"
    echo "Check logs: docker logs kafka-connect-clickhouse | tail -50"
fi

# Check ClickHouse sink status
print_info "Checking ClickHouse JDBC sink connector..."
SINK_STATUS=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "NOT_DEPLOYED")

if [ "$SINK_STATUS" = "RUNNING" ]; then
    print_status 0 "ClickHouse sink connector status: $SINK_STATUS"
elif [ "$SINK_STATUS" = "NOT_DEPLOYED" ]; then
    echo -e "${YELLOW}⚠ ClickHouse sink connector not deployed${NC}"
    echo "  Data will be in Kafka topics but not automatically written to ClickHouse"
    echo "  You can consume manually or use alternative approaches"
else
    print_status 1 "ClickHouse sink connector status: $SINK_STATUS"
fi

echo ""
echo "7. Listing Active Connectors"
echo "-----------------------------"

ACTIVE_CONNECTORS=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null)
echo "$ACTIVE_CONNECTORS" | python3 -m json.tool 2>/dev/null || echo "$ACTIVE_CONNECTORS"

echo ""
echo "========================================"
echo "   Deployment Summary"
echo "========================================"
echo ""
echo "Connectors deployed:"
echo "  - Debezium MySQL Source: $DEBEZIUM_STATUS"
echo "  - ClickHouse JDBC Sink: $SINK_STATUS"
echo ""
echo "Monitoring URLs:"
echo "  Kafka Connect API: $CONNECT_URL"
echo "  Redpanda Console: http://localhost:8086"
echo ""
echo "Check connector details:"
echo "  curl $CONNECT_URL/connectors/mysql-source-connector/status | jq"
echo ""

if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Snapshot has started!${NC}"
    echo ""
    echo "Next step: Run 04_monitor_snapshot.sh to track progress"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ Debezium connector not running properly${NC}"
    echo "Check logs and fix issues before proceeding"
    echo ""
    exit 1
fi
