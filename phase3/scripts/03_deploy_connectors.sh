#!/bin/bash
# Phase 3 - Deploy Connectors Script
# Purpose: Deploy Debezium MySQL Source and ClickHouse JDBC Sink connectors

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"
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

# Load environment variables from centralized .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    print_info "Loaded configuration from $PROJECT_ROOT/.env"
else
    print_error ".env file not found at $PROJECT_ROOT/.env"
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

CONNECT_URL="http://localhost:8083"

if curl -s "$CONNECT_URL/" | grep -q "version"; then
    print_status 0 "Kafka Connect is running"
else
    print_status 1 "Kafka Connect is not responding"
    echo "Please ensure Phase 2 services are running"
    exit 1
fi

echo ""
echo "2. Verifying ClickHouse Kafka Connect Connector"
echo "------------------------------------------------"

print_info "Checking if ClickHouse Kafka Connect connector is loaded..."

# Check if connector is available in plugins (more reliable than file check)
if curl -s "$CONNECT_URL/connector-plugins" 2>/dev/null | grep -q "ClickHouseSinkConnector"; then
    print_status 0 "ClickHouse Kafka Connect connector already loaded"
elif docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-kafka/*.jar &>/dev/null 2>&1; then
    print_status 0 "ClickHouse Kafka Connect connector files found"
    print_info "Connector will be loaded automatically"
else
    echo "Installing ClickHouse Kafka Connect connector..."

    # Download ClickHouse Kafka Connect connector
    # Using official ClickHouse connector from GitHub releases
    CONNECTOR_VERSION="1.0.13"
    CONNECTOR_URL="https://github.com/ClickHouse/clickhouse-kafka-connect/releases/download/v${CONNECTOR_VERSION}/clickhouse-kafka-connect-v${CONNECTOR_VERSION}.zip"

    docker exec kafka-connect-clickhouse bash -c "
        mkdir -p /tmp/clickhouse-connector &&
        cd /tmp/clickhouse-connector &&
        curl -L -o connector.zip '$CONNECTOR_URL' 2>&1 &&
        unzip -q connector.zip &&
        mkdir -p /kafka/connect/clickhouse-kafka &&
        cp *.jar /kafka/connect/clickhouse-kafka/ &&
        cd / &&
        rm -rf /tmp/clickhouse-connector
    " | grep -v "^\s*$" | head -10

    # Verify installation
    if docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-kafka/*.jar &>/dev/null 2>&1; then
        JAR_COUNT=$(docker exec kafka-connect-clickhouse ls -1 /kafka/connect/clickhouse-kafka/*.jar 2>/dev/null | wc -l)
        print_status 0 "ClickHouse Kafka Connect connector installed ($JAR_COUNT JAR files)"

        print_info "Restarting Kafka Connect to load connector..."
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
        print_error "Connector installation failed"
        echo "Trying alternative installation method..."

        # Alternative: Install from Maven Central
        docker exec kafka-connect-clickhouse bash -c "
            mkdir -p /kafka/connect/clickhouse-kafka &&
            cd /kafka/connect/clickhouse-kafka &&
            curl -L -o clickhouse-kafka-connect.jar 'https://repo1.maven.org/maven2/com/clickhouse/clickhouse-kafka-connect/1.0.13/clickhouse-kafka-connect-1.0.13-all.jar' 2>&1
        " | grep -v "^\s*$" | head -5

        if docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-kafka/*.jar &>/dev/null 2>&1; then
            print_status 0 "Connector installed via Maven Central"
            docker restart kafka-connect-clickhouse >/dev/null 2>&1
            sleep 10
        else
            print_error "Both installation methods failed"
            echo "You may need to manually download the connector"
            exit 1
        fi
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
    echo "Try manually: curl http://localhost:8083/connector-plugins"
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

if echo "$CONNECTORS" | grep -q "com.clickhouse.kafka.connect.ClickHouseSinkConnector"; then
    print_status 0 "ClickHouse Kafka Connect Sink connector available"
else
    print_error "ClickHouse Kafka Connect Sink connector not found"
    echo ""
    echo "Available connectors:"
    echo "$CONNECTORS"
    echo ""
    echo "The connector may need to be installed manually."
    echo "Please ensure the connector JAR is in /kafka/connect/clickhouse-kafka/"
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
echo "5. Deploying ClickHouse Kafka Connect Sink Connector"
echo "-----------------------------------------------------"

# Read and substitute template - use ClickHouse native Kafka connector
if [ -f "$CONFIG_DIR/clickhouse-sink.json" ]; then
    CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
else
    print_error "clickhouse-sink.json not found"
    echo "ClickHouse Kafka Connect sink configuration missing"
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
echo "6. Verifying Connector Status and Tasks"
echo "----------------------------------------"

sleep 5

# Check Debezium status
print_info "Checking Debezium MySQL source connector..."
DEBEZIUM_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null)
DEBEZIUM_STATUS=$(echo "$DEBEZIUM_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")

if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
    print_status 0 "Debezium connector status: $DEBEZIUM_STATUS"
else
    print_status 1 "Debezium connector status: $DEBEZIUM_STATUS"
    echo "Check logs: docker logs kafka-connect-clickhouse | tail -50"
fi

# CRITICAL: Check if MySQL source connector tasks are created
MYSQL_TASK_COUNT=$(echo "$DEBEZIUM_STATUS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))" 2>/dev/null || echo "0")
MYSQL_EXPECTED_TASKS=1

echo -n "  MySQL Source Tasks: "
if [ "$MYSQL_TASK_COUNT" -eq "$MYSQL_EXPECTED_TASKS" ]; then
    echo -e "${GREEN}$MYSQL_TASK_COUNT/$MYSQL_EXPECTED_TASKS created${NC}"

    # Check task states
    MYSQL_RUNNING_TASKS=$(echo "$DEBEZIUM_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")
    if [ "$MYSQL_RUNNING_TASKS" -eq "$MYSQL_EXPECTED_TASKS" ]; then
        print_status 0 "  All $MYSQL_RUNNING_TASKS tasks are RUNNING"
    else
        echo -e "${YELLOW}⚠ Warning: Only $MYSQL_RUNNING_TASKS/$MYSQL_EXPECTED_TASKS tasks are RUNNING${NC}"
    fi
else
    echo -e "${RED}$MYSQL_TASK_COUNT/$MYSQL_EXPECTED_TASKS - NO TASKS CREATED!${NC}"
    echo -e "${RED}✗ CRITICAL: MySQL source connector has no tasks${NC}"
    echo ""
    echo "This means the snapshot cannot start!"
    echo "Possible causes:"
    echo "  • MySQL binlog not enabled"
    echo "  • Missing MySQL user permissions (REPLICATION SLAVE/CLIENT)"
    echo "  • MySQL connectivity issues"
    echo ""
    echo "Run diagnostic: ./diagnose_mysql_connector.sh"
fi

echo ""

# Check ClickHouse sink status
print_info "Checking ClickHouse Kafka Connect sink connector..."
SINK_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
SINK_STATUS=$(echo "$SINK_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "NOT_DEPLOYED")

if [ "$SINK_STATUS" = "RUNNING" ]; then
    print_status 0 "ClickHouse sink connector status: $SINK_STATUS"

    # Check task count
    SINK_TASK_COUNT=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))" 2>/dev/null || echo "0")
    SINK_EXPECTED_TASKS=4

    echo -n "  ClickHouse Sink Tasks: "
    if [ "$SINK_TASK_COUNT" -eq "$SINK_EXPECTED_TASKS" ]; then
        echo -e "${GREEN}$SINK_TASK_COUNT/$SINK_EXPECTED_TASKS created${NC}"
    else
        echo -e "${YELLOW}$SINK_TASK_COUNT/$SINK_EXPECTED_TASKS created (expected $SINK_EXPECTED_TASKS)${NC}"
    fi

    # Check task states
    SINK_RUNNING_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")
    SINK_FAILED_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='FAILED'))" 2>/dev/null || echo "0")

    if [ "$SINK_RUNNING_TASKS" -eq "$SINK_EXPECTED_TASKS" ]; then
        print_status 0 "  All $SINK_RUNNING_TASKS tasks are RUNNING"
    elif [ "$SINK_FAILED_TASKS" -gt 0 ]; then
        echo -e "${RED}✗ Warning: $SINK_FAILED_TASKS task(s) are FAILED${NC}"
        echo "  Check logs: docker logs kafka-connect-clickhouse | grep ERROR"
    else
        echo -e "${YELLOW}⚠ Warning: Only $SINK_RUNNING_TASKS/$SINK_EXPECTED_TASKS tasks are RUNNING${NC}"
    fi
elif [ "$SINK_STATUS" = "NOT_DEPLOYED" ]; then
    echo -e "${YELLOW}⚠ ClickHouse sink connector not deployed${NC}"
    echo "  Data will be in Kafka topics but not automatically written to ClickHouse"
else
    print_status 1 "ClickHouse sink connector status: $SINK_STATUS"
    echo "  Check connector logs for errors"
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
echo "  - ClickHouse Kafka Connect Sink: $SINK_STATUS"
echo ""
echo "Monitoring URLs:"
echo "  Kafka Connect API: $CONNECT_URL"
echo "  Redpanda Console: http://localhost:8086"
echo ""
echo "Check connector details:"
echo "  curl $CONNECT_URL/connectors/mysql-source-connector/status | jq"
echo ""

if [ "$DEBEZIUM_STATUS" = "RUNNING" ] && [ "$MYSQL_TASK_COUNT" -eq "$MYSQL_EXPECTED_TASKS" ]; then
    echo -e "${GREEN}✓ Connectors deployed successfully with all tasks running!${NC}"
    echo ""
    echo "Next step: Run 04_monitor_snapshot.sh to track progress"
    echo ""
    exit 0
elif [ "$DEBEZIUM_STATUS" = "RUNNING" ] && [ "$MYSQL_TASK_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ CRITICAL: MySQL connector is RUNNING but has NO TASKS${NC}"
    echo ""
    echo "The snapshot cannot start without tasks."
    echo "This is the most common issue with Debezium MySQL connectors."
    echo ""
    echo "Next step: Run diagnostic to identify the cause"
    echo "  ./diagnose_mysql_connector.sh"
    echo ""
    exit 1
else
    echo -e "${YELLOW}⚠ Connectors not running properly${NC}"
    echo "Check logs and fix issues before proceeding"
    echo ""
    exit 1
fi
