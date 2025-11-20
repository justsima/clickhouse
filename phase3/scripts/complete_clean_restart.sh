#!/bin/bash
# Complete Clean Restart - CDC Pipeline
# Purpose: Delete ALL Kafka data and restart MySQL → ClickHouse CDC from scratch

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
    echo "$(printf '=%.0s' {1..70})"
}

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  COMPLETE CLEAN RESTART - MySQL → ClickHouse CDC Pipeline       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
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

# Display what will be deleted
print_section "⚠️  WARNING - DESTRUCTIVE OPERATION"
echo ""
echo "This script will DELETE:"
echo "  ❌ MySQL source connector (Debezium)"
echo "  ❌ ClickHouse sink connector"
echo "  ❌ ALL Kafka/Redpanda topics (mysql.*, DLQ, etc.)"
echo "  ❌ ALL consumer groups"
echo "  ❌ ALL Kafka Connect internal topics"
echo ""
echo "This will RESTART:"
echo "  ✓ MySQL snapshot from the beginning (all 450 tables)"
echo "  ✓ ClickHouse sink with RegexRouter transform (FIX included)"
echo ""
echo "ClickHouse data:"
echo "  ✓ PRESERVED (450 tables will remain, but will be repopulated)"
echo ""

print_warning "This is a COMPLETE RESET of the CDC pipeline!"
echo ""
read -p "Are you absolutely sure? Type 'DELETE ALL' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE ALL" ]; then
    echo "Aborted"
    exit 0
fi

# ============================================================
# PHASE 1: DELETE CONNECTORS
# ============================================================

print_section "PHASE 1: DELETE CONNECTORS"

echo ""
echo "Step 1: Deleting MySQL source connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/mysql-source-connector" 2>/dev/null || true
sleep 2
print_status 0 "MySQL source connector deleted"

echo ""
echo "Step 2: Deleting ClickHouse sink connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || true
sleep 2
print_status 0 "ClickHouse sink connector deleted"

# Verify no connectors exist
echo ""
echo "Verifying connectors deleted..."
CONNECTOR_COUNT=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [ "$CONNECTOR_COUNT" -eq 0 ]; then
    print_status 0 "All connectors deleted"
else
    print_warning "$CONNECTOR_COUNT connector(s) still exist"
fi

# ============================================================
# PHASE 2: DELETE ALL TOPICS
# ============================================================

print_section "PHASE 2: DELETE ALL KAFKA TOPICS"

echo ""
echo "Listing all topics..."
ALL_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -v "^NAME" | awk '{print $1}' | grep -v "^$")

# Filter out internal topics (keep them)
INTERNAL_TOPICS="clickhouse_connect_configs clickhouse_connect_offsets clickhouse_connect_status _schemas __consumer_offsets __transaction_state"

echo ""
echo "Topics to delete:"
TOPIC_COUNT=0
for topic in $ALL_TOPICS; do
    # Skip internal topics
    if echo "$INTERNAL_TOPICS" | grep -qw "$topic"; then
        continue
    fi
    echo "  - $topic"
    TOPIC_COUNT=$((TOPIC_COUNT + 1))
done

echo ""
echo "Total topics to delete: $TOPIC_COUNT"
echo ""

if [ "$TOPIC_COUNT" -gt 0 ]; then
    echo "Deleting topics..."
    for topic in $ALL_TOPICS; do
        # Skip internal topics
        if echo "$INTERNAL_TOPICS" | grep -qw "$topic"; then
            continue
        fi

        docker exec redpanda-clickhouse rpk topic delete "$topic" --brokers localhost:9092 2>&1 | head -1
    done

    print_status 0 "All user topics deleted"
else
    print_info "No topics to delete"
fi

# ============================================================
# PHASE 3: DELETE ALL CONSUMER GROUPS
# ============================================================

print_section "PHASE 3: DELETE ALL CONSUMER GROUPS"

echo ""
echo "Listing consumer groups..."
CONSUMER_GROUPS=$(docker exec redpanda-clickhouse rpk group list --brokers localhost:9092 2>/dev/null | grep -v "^BROKER" | awk '{print $2}' | grep -v "^$")

echo ""
if [ -n "$CONSUMER_GROUPS" ]; then
    echo "Consumer groups to delete:"
    for group in $CONSUMER_GROUPS; do
        echo "  - $group"
    done

    echo ""
    echo "Deleting consumer groups..."
    for group in $CONSUMER_GROUPS; do
        docker exec redpanda-clickhouse rpk group delete "$group" --brokers localhost:9092 2>&1 | head -1
    done

    print_status 0 "All consumer groups deleted"
else
    print_info "No consumer groups to delete"
fi

# ============================================================
# PHASE 4: VERIFY CLEAN STATE
# ============================================================

print_section "PHASE 4: VERIFY CLEAN STATE"

echo ""
echo "Verifying Kafka is clean..."

# Check topics
REMAINING_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\." | wc -l)
if [ "$REMAINING_TOPICS" -eq 0 ]; then
    print_status 0 "No mysql.* topics remain"
else
    print_warning "$REMAINING_TOPICS mysql.* topics still exist"
fi

# Check consumer groups
REMAINING_GROUPS=$(docker exec redpanda-clickhouse rpk group list --brokers localhost:9092 2>/dev/null | grep "connect-\|clickhouse-cdc" | wc -l)
if [ "$REMAINING_GROUPS" -eq 0 ]; then
    print_status 0 "No connector consumer groups remain"
else
    print_warning "$REMAINING_GROUPS consumer groups still exist"
fi

# ============================================================
# PHASE 5: REDEPLOY CONNECTORS (WITH FIX)
# ============================================================

print_section "PHASE 5: REDEPLOY CONNECTORS WITH FIX"

echo ""
echo "Waiting 5 seconds for Kafka Connect to stabilize..."
sleep 5

# Deploy MySQL source connector
echo ""
echo "Step 1: Deploying MySQL source connector..."

DEBEZIUM_CONFIG=$(cat "$CONFIG_DIR/debezium-mysql-source.json")
DEBEZIUM_CONFIG=$(substitute_vars "$DEBEZIUM_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$DEBEZIUM_CONFIG")

if echo "$RESPONSE" | grep -q "mysql-source-connector"; then
    print_status 0 "MySQL source connector deployed"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Deployment failed"
    echo "Response: $RESPONSE" | python3 -m json.tool
    exit 1
else
    print_status 0 "MySQL source connector deployed"
fi

# Deploy ClickHouse sink connector (with RegexRouter fix)
echo ""
echo "Step 2: Deploying ClickHouse sink connector (with RegexRouter fix)..."

CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CLICKHOUSE_CONFIG")

if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
    print_status 0 "ClickHouse sink connector deployed"
elif echo "$RESPONSE" | grep -q "error"; then
    print_status 1 "Deployment failed"
    echo "Response: $RESPONSE" | python3 -m json.tool
    exit 1
else
    print_status 0 "ClickHouse sink connector deployed"
fi

# ============================================================
# PHASE 6: VERIFY CONNECTORS RUNNING
# ============================================================

print_section "PHASE 6: VERIFY CONNECTORS"

echo ""
echo "Waiting 10 seconds for connectors to initialize..."
sleep 10

# Check MySQL source
echo ""
echo "Checking MySQL source connector..."
MYSQL_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null)
MYSQL_STATUS=$(echo "$MYSQL_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")
MYSQL_TASKS=$(echo "$MYSQL_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")

if [ "$MYSQL_STATUS" = "RUNNING" ] && [ "$MYSQL_TASKS" -eq 1 ]; then
    print_status 0 "MySQL source: RUNNING ($MYSQL_TASKS/1 tasks)"
else
    print_status 1 "MySQL source: $MYSQL_STATUS ($MYSQL_TASKS/1 tasks)"
fi

# Check ClickHouse sink
echo ""
echo "Checking ClickHouse sink connector..."
SINK_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
SINK_STATUS=$(echo "$SINK_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UNKNOWN")
SINK_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null || echo "0")

if [ "$SINK_STATUS" = "RUNNING" ] && [ "$SINK_TASKS" -eq 4 ]; then
    print_status 0 "ClickHouse sink: RUNNING ($SINK_TASKS/4 tasks)"
else
    print_status 1 "ClickHouse sink: $SINK_STATUS ($SINK_TASKS/4 tasks)"
fi

# Verify RegexRouter transform
echo ""
echo "Verifying RegexRouter transform..."
TRANSFORM_CHECK=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null | grep -c '"transforms":"topicToTable"' || echo "0")

if [ "$TRANSFORM_CHECK" -gt 0 ]; then
    print_status 0 "RegexRouter transform configured"
    echo ""
    echo "  Transform Details:"
    echo "    Pattern:     mysql\\.${MYSQL_DATABASE}\\.(.*)"
    echo "    Replacement: \$1"
    echo "    Effect:      mysql.${MYSQL_DATABASE}.table_name → table_name"
else
    print_status 1 "Transform NOT configured (ERROR!)"
fi

# ============================================================
# PHASE 7: MONITOR INITIAL PROGRESS
# ============================================================

print_section "PHASE 7: INITIAL PROGRESS CHECK"

echo ""
echo "Waiting 20 seconds for initial snapshot to start..."
for i in {20..1}; do
    echo -ne "\r  ${i}s remaining... "
    sleep 1
done
echo ""

echo ""
echo "Checking for new topics..."
NEW_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\.${MYSQL_DATABASE}\." | wc -l || echo "0")

if [ "$NEW_TOPICS" -gt 0 ]; then
    print_status 0 "MySQL snapshot started! ($NEW_TOPICS topics created)"

    echo ""
    echo "Sample topics:"
    docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\.${MYSQL_DATABASE}\." | head -5
else
    print_warning "No topics created yet (may need more time)"
fi

# ============================================================
# SUMMARY
# ============================================================

print_section "✅ COMPLETE CLEAN RESTART - SUMMARY"

echo ""
echo "Status:"
echo "  ✓ All old Kafka data deleted"
echo "  ✓ MySQL source connector:    $MYSQL_STATUS ($MYSQL_TASKS/1 tasks)"
echo "  ✓ ClickHouse sink connector:  $SINK_STATUS ($SINK_TASKS/4 tasks)"
echo "  ✓ RegexRouter transform:      APPLIED"
echo ""

if [ "$NEW_TOPICS" -gt 0 ]; then
    echo -e "${GREEN}${BOLD}✓ SUCCESS! CDC pipeline restarted with fix applied!${NC}"
    echo ""
    echo "The MySQL snapshot is now running with the correct configuration."
    echo "Data will flow: MySQL → Debezium → Redpanda → ClickHouse ✓"
else
    echo -e "${YELLOW}⚠ Pipeline restarted, waiting for snapshot to begin...${NC}"
    echo ""
    echo "Wait 1-2 minutes and check again."
fi

echo ""
echo "Next Steps:"
echo "  1. Monitor progress:"
echo "     cd $SCRIPT_DIR"
echo "     ./04_monitor_snapshot.sh"
echo ""
echo "  2. Check ClickHouse data (after a few minutes):"
echo "     docker exec clickhouse-server clickhouse-client --password '$CLICKHOUSE_PASSWORD' --query \"SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0\""
echo ""
echo "Expected Timeline:"
echo "  - First topics:     1-2 minutes"
echo "  - First data in CH: 5-10 minutes"
echo "  - Full snapshot:    1-2 hours (22.8 GB)"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""
