#!/bin/bash
# Fix MySQL Connector Task Failure
# Purpose: Reset Kafka Connect internal state and redeploy connectors
# Issue: MySQL connector RUNNING but task FAILED (schema history topic missing)

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

print_section() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Fix MySQL Connector Task Failure - Complete Reset       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

CONNECT_URL="http://localhost:8085"

# Helper function
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

# ============================================================
# STEP 1: DELETE EXISTING CONNECTORS
# ============================================================

print_section "STEP 1: DELETE EXISTING CONNECTORS"

echo ""
print_info "Deleting MySQL source connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/mysql-source-connector" 2>/dev/null || true
sleep 2
print_status 0 "MySQL connector deleted"

echo ""
print_info "Deleting ClickHouse sink connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || true
sleep 2
print_status 0 "ClickHouse connector deleted"

# ============================================================
# STEP 2: DELETE KAFKA CONNECT INTERNAL TOPICS
# ============================================================

print_section "STEP 2: RESET KAFKA CONNECT INTERNAL STATE"

echo ""
print_info "This will delete Kafka Connect's memory of previous connectors"
echo ""

echo "Deleting clickhouse_connect_offsets..."
docker exec redpanda-clickhouse rpk topic delete clickhouse_connect_offsets --brokers localhost:9092 2>&1 | head -3
sleep 1

echo ""
echo "Deleting clickhouse_connect_configs..."
docker exec redpanda-clickhouse rpk topic delete clickhouse_connect_configs --brokers localhost:9092 2>&1 | head -3
sleep 1

echo ""
echo "Deleting clickhouse_connect_status..."
docker exec redpanda-clickhouse rpk topic delete clickhouse_connect_status --brokers localhost:9092 2>&1 | head -3
sleep 1

print_status 0 "Kafka Connect internal topics deleted"

# ============================================================
# STEP 3: RESTART KAFKA CONNECT
# ============================================================

print_section "STEP 3: RESTART KAFKA CONNECT"

echo ""
print_info "Restarting Kafka Connect container..."
docker restart kafka-connect-clickhouse

echo ""
print_info "Waiting 30 seconds for Kafka Connect to initialize..."
for i in {30..1}; do
    echo -ne "\r  ${i}s remaining... "
    sleep 1
done
echo ""

# Verify Kafka Connect is responding
if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
    print_status 0 "Kafka Connect is responding"
else
    print_status 1 "Kafka Connect not responding yet, waiting 10 more seconds..."
    sleep 10
fi

# ============================================================
# STEP 4: REDEPLOY CONNECTORS
# ============================================================

print_section "STEP 4: REDEPLOY CONNECTORS"

echo ""
echo "Step 1: Deploy MySQL source connector"
echo "--------------------------------------"

DEBEZIUM_CONFIG=$(cat "$CONFIG_DIR/debezium-mysql-source.json")
DEBEZIUM_CONFIG=$(substitute_vars "$DEBEZIUM_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$DEBEZIUM_CONFIG")

if echo "$RESPONSE" | grep -q "mysql-source-connector"; then
    print_status 0 "MySQL source connector deployed"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Deployment failed"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
else
    print_status 0 "MySQL source connector deployed"
fi

echo ""
echo "Step 2: Deploy ClickHouse sink connector"
echo "-----------------------------------------"

CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "ClickHouse sink connector deployed"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Deployment failed"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
else
    print_status 0 "ClickHouse sink connector deployed"
fi

# ============================================================
# STEP 5: VERIFY CONNECTORS
# ============================================================

print_section "STEP 5: VERIFY CONNECTORS"

echo ""
print_info "Waiting 15 seconds for connectors to initialize..."
sleep 15

echo ""
echo "Checking MySQL source connector..."
MYSQL_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null)
MYSQL_STATE=$(echo "$MYSQL_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")
MYSQL_TASK_STATE=$(echo "$MYSQL_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(tasks[0].get('state') if tasks else 'NO_TASKS')" 2>/dev/null || echo "NO_TASKS")

echo "  Connector state: $MYSQL_STATE"
echo "  Task state: $MYSQL_TASK_STATE"

if [ "$MYSQL_TASK_STATE" = "RUNNING" ]; then
    print_status 0 "MySQL connector: RUNNING (1/1 tasks)"
else
    print_status 1 "MySQL connector task: $MYSQL_TASK_STATE"
    echo ""
    echo "Task error details:"
    echo "$MYSQL_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(tasks[0].get('trace') if tasks else 'No trace available')" 2>/dev/null | head -20
fi

echo ""
echo "Checking ClickHouse sink connector..."
SINK_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
SINK_STATE=$(echo "$SINK_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")
SINK_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")

echo "  Connector state: $SINK_STATE"
echo "  Running tasks: $SINK_TASKS/4"

if [ "$SINK_STATE" = "RUNNING" ] && [ "$SINK_TASKS" -eq 4 ]; then
    print_status 0 "ClickHouse sink: RUNNING (4/4 tasks)"
else
    print_status 1 "ClickHouse sink: $SINK_STATE ($SINK_TASKS/4 tasks)"
fi

# ============================================================
# STEP 6: CHECK INITIAL PROGRESS
# ============================================================

print_section "STEP 6: CHECK INITIAL PROGRESS"

echo ""
print_info "Waiting 20 seconds for MySQL snapshot to start..."
for i in {20..1}; do
    echo -ne "\r  ${i}s remaining... "
    sleep 1
done
echo ""

echo ""
echo "Checking for new topics..."
NEW_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\\.${MYSQL_DATABASE}\\." | wc -l || echo "0")

if [ "$NEW_TOPICS" -gt 0 ]; then
    print_status 0 "MySQL snapshot started! ($NEW_TOPICS topics created)"

    echo ""
    echo "Sample topics:"
    docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\\.${MYSQL_DATABASE}\\." | head -5
else
    print_info "No topics created yet (may need more time)"
fi

# ============================================================
# SUMMARY
# ============================================================

print_section "SUMMARY"

echo ""
echo "Connector Status:"
echo "  MySQL source:     $MYSQL_STATE - Task: $MYSQL_TASK_STATE"
echo "  ClickHouse sink:  $SINK_STATE - Tasks: $SINK_TASKS/4"
echo ""

if [ "$MYSQL_TASK_STATE" = "RUNNING" ] && [ "$SINK_TASKS" -eq 4 ]; then
    echo -e "${GREEN}${BOLD}✓ SUCCESS! MySQL connector task is now RUNNING!${NC}"
    echo ""
    echo "The CDC pipeline is working:"
    echo "  MySQL → Debezium → Redpanda → ClickHouse ✓"
    echo ""
    echo "Next Steps:"
    echo "  1. Monitor progress:"
    echo "     cd $SCRIPT_DIR"
    echo "     ./04_monitor_snapshot.sh"
    echo ""
    echo "  2. Check ClickHouse data (after a few minutes):"
    echo "     docker exec clickhouse-server clickhouse-client --password '$CLICKHOUSE_PASSWORD' --query \"SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0\""
elif [ "$MYSQL_TASK_STATE" = "RUNNING" ]; then
    echo -e "${YELLOW}⚠ MySQL connector working but ClickHouse sink needs attention${NC}"
    echo ""
    echo "MySQL connector is now fixed. Check ClickHouse sink status."
else
    echo -e "${RED}✗ MySQL connector task still FAILED${NC}"
    echo ""
    echo "Please check the error details above."
    echo ""
    echo "Common issues:"
    echo "  - MySQL connectivity (check host/port/credentials)"
    echo "  - MySQL binlog not enabled"
    echo "  - MySQL user permissions"
    echo ""
    echo "Verify MySQL setup:"
    echo "  cd $PROJECT_ROOT/phase1/scripts"
    echo "  ./02_mysql_validation.sh"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
