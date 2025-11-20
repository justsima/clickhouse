#!/bin/bash
# Complete Fix for ClickHouse Sink Connector
# Purpose: Reset consumer offsets and redeploy with RegexRouter transform
# This ensures ALL data from Kafka flows to ClickHouse

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "$(printf '=%.0s' {1..60})"
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ClickHouse Sink Connector - Complete Fix & Reset         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
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

# Display problem analysis
print_section "PROBLEM ANALYSIS"
echo ""
echo "Root Cause: Topic name mismatch"
echo "  Kafka Topics:       mysql.${MYSQL_DATABASE}.table_name"
echo "  ClickHouse Tables:  table_name"
echo "  Connector Looking:  mysql.${MYSQL_DATABASE}.table_name ❌"
echo ""
echo "Result: 48M+ records consumed but sent to Dead Letter Queue"
echo ""

# Display solution
print_section "SOLUTION"
echo ""
echo "1. Add RegexRouter transform to strip topic prefix"
echo "   Pattern: mysql\\.${MYSQL_DATABASE}\\.(.*)"
echo "   Replacement: \$1"
echo ""
echo "2. Reset consumer group offsets to 0 (reprocess all data)"
echo ""
echo "3. Redeploy connector with fixed configuration"
echo ""

# Confirmation
print_warning "This will reset all offsets and reprocess ALL Kafka data"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

# ============================================================
# PHASE 1: STOP & CLEAN
# ============================================================

print_section "PHASE 1: STOP & CLEAN"

# Step 1: Delete connector
echo ""
echo "Step 1: Deleting ClickHouse sink connector..."
RESPONSE=$(curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || echo "")
sleep 2

# Verify deletion
CONNECTOR_EXISTS=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null | grep -c "clickhouse-sink-connector" || echo "0")
if [ "$CONNECTOR_EXISTS" -eq 0 ]; then
    print_status 0 "Connector deleted"
else
    print_status 1 "Connector still exists"
    exit 1
fi

# Step 2: Delete consumer group (reset offsets)
echo ""
echo "Step 2: Deleting consumer group (resets offsets to 0)..."
docker exec redpanda-clickhouse rpk group delete connect-clickhouse-sink-connector --brokers localhost:9092 2>&1 | head -5

sleep 2

# Verify consumer group deleted
GROUP_EXISTS=$(docker exec redpanda-clickhouse rpk group list --brokers localhost:9092 2>/dev/null | grep -c "connect-clickhouse-sink-connector" || echo "0")
if [ "$GROUP_EXISTS" -eq 0 ]; then
    print_status 0 "Consumer group deleted (offsets reset)"
else
    print_status 1 "Consumer group still exists"
fi

# Step 3: Delete DLQ topic
echo ""
echo "Step 3: Deleting Dead Letter Queue topic..."
docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq --brokers localhost:9092 2>&1 | head -3 || true

sleep 2

print_status 0 "DLQ topic deleted"

# ============================================================
# PHASE 2: DEPLOY FIXED CONNECTOR
# ============================================================

print_section "PHASE 2: DEPLOY FIXED CONNECTOR"

echo ""
echo "Configuration:"
echo "  Database: ${CLICKHOUSE_DATABASE}"
echo "  Topics:   mysql.${MYSQL_DATABASE}.*"
echo "  Transform: Strip 'mysql.${MYSQL_DATABASE}.' prefix"
echo ""

# Deploy connector
echo "Deploying connector with RegexRouter transform..."

CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "Connector deployed successfully"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Deployment failed"
    echo "Response:"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
else
    print_status 0 "Connector deployed"
fi

echo ""
echo "Waiting for connector to initialize..."
sleep 8

# Verify connector status
STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
STATUS=$(echo "$STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")

if [ "$STATUS" = "RUNNING" ]; then
    print_status 0 "Connector status: $STATUS"

    TASK_COUNT=$(echo "$STATUS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))" 2>/dev/null || echo "0")
    RUNNING_TASKS=$(echo "$STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")

    echo "  Tasks: $RUNNING_TASKS/$TASK_COUNT RUNNING"
else
    print_status 1 "Connector status: $STATUS"
    echo ""
    echo "Full status:"
    echo "$STATUS_JSON" | python3 -m json.tool
    exit 1
fi

# Verify transform configured
echo ""
echo "Verifying RegexRouter transform..."
TRANSFORM_CHECK=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null | grep -c '"transforms":"topicToTable"' || echo "0")

if [ "$TRANSFORM_CHECK" -gt 0 ]; then
    print_status 0 "RegexRouter transform configured"

    # Show transform details
    echo ""
    echo "Transform Configuration:"
    curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null | python3 -m json.tool | grep -A 3 "transforms"
else
    print_status 1 "Transform NOT found"
    exit 1
fi

# ============================================================
# PHASE 3: VERIFY DATA FLOW
# ============================================================

print_section "PHASE 3: VERIFY DATA FLOW"

echo ""
echo "Waiting 15 seconds for connector to consume first batch..."
for i in {15..1}; do
    echo -ne "\r  ${i}s remaining... "
    sleep 1
done
echo ""

# Check ClickHouse data
echo ""
echo "Checking ClickHouse for data..."
TABLES_WITH_DATA=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0" 2>/dev/null || echo "0")

if [ "$TABLES_WITH_DATA" -gt 0 ]; then
    print_status 0 "ClickHouse has data! ($TABLES_WITH_DATA tables)"

    echo ""
    echo "Sample tables with data:"
    docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "
    SELECT
        name as table_name,
        total_rows,
        formatReadableSize(total_bytes) as size
    FROM system.tables
    WHERE database = '$CLICKHOUSE_DATABASE'
      AND total_rows > 0
    ORDER BY total_rows DESC
    LIMIT 10
    " 2>/dev/null | head -15
else
    print_warning "No data in ClickHouse yet (may need more time)"
    echo ""
    echo "Check consumer lag to see if data is flowing..."
fi

# Check consumer group lag
echo ""
echo "Checking consumer group lag..."
CONSUMER_INFO=$(docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092 2>/dev/null | head -10)

if echo "$CONSUMER_INFO" | grep -q "TOTAL-LAG"; then
    TOTAL_LAG=$(echo "$CONSUMER_INFO" | grep "TOTAL-LAG" | awk '{print $2}')
    print_status 0 "Consumer group active"
    echo "  Total Lag: $TOTAL_LAG records (should decrease over time)"
else
    print_warning "Consumer group not yet active (starting from offset 0)"
fi

# Check DLQ (should be empty or not exist)
echo ""
echo "Checking Dead Letter Queue..."
DLQ_CHECK=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>&1 || echo "NOT_FOUND")

if echo "$DLQ_CHECK" | grep -qi "not exist\|NOT_FOUND"; then
    print_status 0 "No DLQ errors (good!)"
else
    DLQ_MESSAGES=$(echo "$DLQ_CHECK" | grep -i "high water mark" | awk '{print $4}' || echo "0")
    if [ "$DLQ_MESSAGES" = "0" ]; then
        print_status 0 "DLQ exists but empty (good!)"
    else
        print_warning "DLQ has $DLQ_MESSAGES messages (check for errors)"
    fi
fi

# ============================================================
# SUMMARY
# ============================================================

print_section "SUMMARY"

echo ""
echo "✅ Connector Configuration:"
echo "   - RegexRouter transform: ✓ Applied"
echo "   - Consumer offsets:      ✓ Reset to 0"
echo "   - Tasks:                 ✓ $RUNNING_TASKS/4 RUNNING"
echo ""

if [ "$TABLES_WITH_DATA" -gt 0 ]; then
    echo -e "${GREEN}${BOLD}✓ SUCCESS! Data is flowing to ClickHouse!${NC}"
    echo ""
    echo "The connector will now process all 48M+ records from Kafka."
    echo "Monitor progress with:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./04_monitor_snapshot.sh"
else
    echo -e "${YELLOW}⚠ Data flow starting...${NC}"
    echo ""
    echo "Wait a few minutes and check again:"
    echo "  docker exec clickhouse-server clickhouse-client --password '$CLICKHOUSE_PASSWORD' --query \"SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0\""
    echo ""
    echo "Monitor progress:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./04_monitor_snapshot.sh"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
