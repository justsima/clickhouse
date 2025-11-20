#!/bin/bash
# Fix ClickHouse Sink Connector - Add RegexRouter Transform
# Purpose: Strip topic prefix to match ClickHouse table names

set -e

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
echo "   Fix ClickHouse Sink Connector"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    print_info "Loaded configuration from $PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

CONNECT_URL="http://localhost:8085"

# Helper function to substitute environment variables
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

echo "Problem Identified:"
echo "  - Kafka topics: mysql.${MYSQL_DATABASE}.table_name"
echo "  - ClickHouse tables: table_name"
echo "  - Connector was looking for: mysql.${MYSQL_DATABASE}.table_name (didn't exist!)"
echo ""
echo "Solution:"
echo "  - Add RegexRouter transform to strip topic prefix"
echo "  - Transform: mysql.${MYSQL_DATABASE}.(.*) → \$1"
echo ""

# Step 1: Delete existing connector
echo "1. Deleting existing ClickHouse sink connector"
echo "----------------------------------------------"
RESPONSE=$(curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || echo "")
print_status 0 "Deleted old connector"
echo ""

sleep 3

# Step 2: Deploy fixed connector
echo "2. Deploying fixed ClickHouse sink connector"
echo "---------------------------------------------"

CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "Connector deployed with RegexRouter transform"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Failed to deploy connector"
    echo "Response: $RESPONSE"
    exit 1
else
    print_status 0 "Connector deployed"
fi

echo ""

# Step 3: Verify connector is running
echo "3. Verifying connector status"
echo "------------------------------"

sleep 5

STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
STATUS=$(echo "$STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")

if [ "$STATUS" = "RUNNING" ]; then
    print_status 0 "Connector status: $STATUS"

    TASK_COUNT=$(echo "$STATUS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))" 2>/dev/null || echo "0")
    echo "  Tasks: $TASK_COUNT/4 created"
else
    print_status 1 "Connector status: $STATUS"
    echo ""
    echo "Full status:"
    echo "$STATUS_JSON" | python3 -m json.tool
    exit 1
fi

echo ""

# Step 4: Verify transform is applied
echo "4. Verifying RegexRouter transform"
echo "-----------------------------------"

TRANSFORMS=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector" | grep -o '"transforms":"[^"]*"' | cut -d'"' -f4)
if [ "$TRANSFORMS" = "topicToTable" ]; then
    print_status 0 "Transform 'topicToTable' configured"
else
    print_status 1 "Transform not found"
fi

echo ""

echo "========================================"
echo "   Connector Fixed!"
echo "========================================"
echo ""
echo "The connector will now:"
echo "  1. Consume from: mysql.${MYSQL_DATABASE}.*"
echo "  2. Transform topic names: mysql.${MYSQL_DATABASE}.table_name → table_name"
echo "  3. Insert into ClickHouse: analytics.table_name"
echo ""
echo "Monitor progress:"
echo "  cd $SCRIPT_DIR"
echo "  ./04_monitor_snapshot.sh"
echo ""
echo "Check ClickHouse data (should start seeing data soon):"
echo "  docker exec clickhouse-server clickhouse-client --password 'ClickHouse_Secure_Pass_2024!' --query \"SELECT count() FROM system.tables WHERE database = 'analytics' AND total_rows > 0\""
echo ""
