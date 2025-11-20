#!/bin/bash
# Systematic CDC Pipeline Verification and Fix
# Checks everything step by step and fixes issues

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

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     CDC Pipeline - Complete Verification & Fix           ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# ============================================================
# STEP 1: VERIFY CLICKHOUSE TABLES
# ============================================================

print_section "STEP 1: Verify ClickHouse Analytics Database"

TABLE_COUNT=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null)

if [ "$TABLE_COUNT" -eq 450 ]; then
    print_status 0 "ClickHouse has $TABLE_COUNT tables in '$CLICKHOUSE_DATABASE' database"
else
    print_status 1 "Expected 450 tables, found $TABLE_COUNT"
    echo "Run: cd $SCRIPT_DIR && ./02_create_clickhouse_schema.sh"
    exit 1
fi

# ============================================================
# STEP 2: VERIFY PORTS
# ============================================================

print_section "STEP 2: Verify Port Configuration"

# Check Kafka Connect port
if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
    print_status 0 "Kafka Connect API responding on port 8085"
else
    print_status 1 "Kafka Connect not responding on port 8085"
    exit 1
fi

# Check ClickHouse port
if curl -s http://localhost:8123/ping 2>/dev/null | grep -q "Ok"; then
    print_status 0 "ClickHouse HTTP responding on port 8123"
else
    print_status 1 "ClickHouse not responding on port 8123"
    exit 1
fi

# Check Redpanda
if docker exec redpanda-clickhouse rpk cluster health --brokers localhost:9092 2>/dev/null | grep -q "Healthy"; then
    print_status 0 "Redpanda broker healthy on port 9092"
else
    print_status 1 "Redpanda broker not healthy"
    exit 1
fi

# ============================================================
# STEP 3: CHECK CONNECTOR CONFIGURATIONS
# ============================================================

print_section "STEP 3: Verify Connector Configurations"

# Check MySQL source config
print_info "Checking MySQL source connector config..."
if [ -f "$CONFIG_DIR/debezium-mysql-source.json" ]; then
    print_status 0 "MySQL source config exists"

    # Check key settings
    MYSQL_HOST_CHECK=$(grep -c "\"database.hostname\": \"\${MYSQL_HOST}\"" "$CONFIG_DIR/debezium-mysql-source.json")
    SNAPSHOT_MODE=$(grep "snapshot.mode" "$CONFIG_DIR/debezium-mysql-source.json" | grep -o '"[^"]*"' | tail -1 | tr -d '"')

    echo "  MySQL Host: \${MYSQL_HOST} → $MYSQL_HOST"
    echo "  Database: $MYSQL_DATABASE"
    echo "  Snapshot mode: $SNAPSHOT_MODE"
else
    print_status 1 "MySQL source config missing"
    exit 1
fi

# Check ClickHouse sink config
print_info "Checking ClickHouse sink connector config..."
if [ -f "$CONFIG_DIR/clickhouse-sink.json" ]; then
    print_status 0 "ClickHouse sink config exists"

    # Check RegexRouter transform
    TRANSFORM_CHECK=$(grep -c '"transforms": "topicToTable"' "$CONFIG_DIR/clickhouse-sink.json")

    if [ "$TRANSFORM_CHECK" -gt 0 ]; then
        print_status 0 "RegexRouter transform configured"
        echo "  Pattern: mysql\\.${MYSQL_DATABASE}\\.(.*)"
        echo "  Replacement: \$1"
    else
        print_status 1 "RegexRouter transform NOT configured"
        exit 1
    fi
else
    print_status 1 "ClickHouse sink config missing"
    exit 1
fi

# ============================================================
# STEP 4: CHECK DEPLOYED CONNECTORS
# ============================================================

print_section "STEP 4: Check Deployed Connectors"

CONNECTORS=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null)

# MySQL Source
if echo "$CONNECTORS" | grep -q "mysql-source-connector"; then
    print_info "MySQL source connector exists"

    MYSQL_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null)
    MYSQL_STATE=$(echo "$MYSQL_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
    MYSQL_TASK_STATE=$(echo "$MYSQL_STATUS_JSON" | grep -o '"state":"[^"]*"' | tail -1 | cut -d'"' -f4)

    echo "  Connector state: $MYSQL_STATE"
    echo "  Task state: $MYSQL_TASK_STATE"

    if [ "$MYSQL_TASK_STATE" = "FAILED" ]; then
        print_status 1 "MySQL task FAILED"

        # Check for schema history topic error
        if echo "$MYSQL_STATUS_JSON" | grep -q "db history topic is missing"; then
            echo ""
            echo "  Issue: Schema history topic missing (deleted during cleanup)"
            echo "  Fix: Redeploy MySQL connector"
            MYSQL_NEEDS_REDEPLOY=true
        fi
    elif [ "$MYSQL_TASK_STATE" = "RUNNING" ]; then
        print_status 0 "MySQL connector working"
        MYSQL_NEEDS_REDEPLOY=false
    else
        echo "  Unknown state: $MYSQL_TASK_STATE"
        MYSQL_NEEDS_REDEPLOY=true
    fi
else
    print_info "MySQL source connector not deployed"
    MYSQL_NEEDS_REDEPLOY=true
fi

# ClickHouse Sink
if echo "$CONNECTORS" | grep -q "clickhouse-sink-connector"; then
    print_info "ClickHouse sink connector exists"

    SINK_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
    SINK_STATE=$(echo "$SINK_STATUS_JSON" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
    SINK_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null)

    echo "  Connector state: $SINK_STATE"
    echo "  Running tasks: $SINK_TASKS/4"

    if [ "$SINK_STATE" = "RUNNING" ] && [ "$SINK_TASKS" -eq 4 ]; then
        print_status 0 "ClickHouse sink working"
        SINK_NEEDS_REDEPLOY=false
    else
        SINK_NEEDS_REDEPLOY=true
    fi
else
    print_info "ClickHouse sink connector not deployed"
    SINK_NEEDS_REDEPLOY=true
fi

# ============================================================
# STEP 5: FIX ISSUES
# ============================================================

print_section "STEP 5: Fix Issues"

if [ "$MYSQL_NEEDS_REDEPLOY" = true ] || [ "$SINK_NEEDS_REDEPLOY" = true ]; then
    echo ""
    echo "Issues detected. Will redeploy connectors."
    echo ""

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

    # Fix MySQL connector
    if [ "$MYSQL_NEEDS_REDEPLOY" = true ]; then
        print_info "Redeploying MySQL source connector..."

        # Delete
        curl -s -X DELETE "$CONNECT_URL/connectors/mysql-source-connector" 2>/dev/null || true
        sleep 3

        # Deploy
        DEBEZIUM_CONFIG=$(cat "$CONFIG_DIR/debezium-mysql-source.json")
        DEBEZIUM_CONFIG=$(substitute_vars "$DEBEZIUM_CONFIG")

        RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
            -H "Content-Type: application/json" \
            -d "$DEBEZIUM_CONFIG")

        if echo "$RESPONSE" | grep -q "mysql-source-connector"; then
            print_status 0 "MySQL connector redeployed"
        else
            print_status 1 "Failed to deploy MySQL connector"
            echo "$RESPONSE" | python3 -m json.tool
        fi
    fi

    # Fix ClickHouse connector
    if [ "$SINK_NEEDS_REDEPLOY" = true ]; then
        print_info "Redeploying ClickHouse sink connector..."

        # Delete
        curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null || true
        sleep 3

        # Deploy
        CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
        CLICKHOUSE_CONFIG=$(substitute_vars "$CLICKHOUSE_CONFIG")

        RESPONSE=$(curl -s -X POST "$CONNECT_URL/connectors" \
            -H "Content-Type: application/json" \
            -d "$CLICKHOUSE_CONFIG")

        if echo "$RESPONSE" | grep -q "clickhouse-sink-connector"; then
            print_status 0 "ClickHouse connector redeployed"
        else
            print_status 1 "Failed to deploy ClickHouse connector"
            echo "$RESPONSE" | python3 -m json.tool
        fi
    fi
else
    print_status 0 "No issues detected - connectors working"
fi

# ============================================================
# STEP 6: VERIFY WORKING
# ============================================================

print_section "STEP 6: Final Verification"

echo ""
print_info "Waiting 15 seconds for connectors to stabilize..."
sleep 15

# Check MySQL
MYSQL_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null)
MYSQL_TASK_STATE=$(echo "$MYSQL_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(tasks[0].get('state') if tasks else 'NO_TASKS')" 2>/dev/null)

if [ "$MYSQL_TASK_STATE" = "RUNNING" ]; then
    print_status 0 "MySQL source: RUNNING (1/1 tasks)"
else
    print_status 1 "MySQL source: $MYSQL_TASK_STATE"
fi

# Check ClickHouse
SINK_STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null)
SINK_TASKS=$(echo "$SINK_STATUS_JSON" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='RUNNING'))" 2>/dev/null)

if [ "$SINK_TASKS" -eq 4 ]; then
    print_status 0 "ClickHouse sink: RUNNING (4/4 tasks)"
else
    print_status 1 "ClickHouse sink: $SINK_TASKS/4 tasks"
fi

# Check for topics
TOPIC_COUNT=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "mysql\.$MYSQL_DATABASE\." || echo "0")

echo ""
if [ "$TOPIC_COUNT" -gt 0 ]; then
    print_status 0 "MySQL snapshot started ($TOPIC_COUNT topics created)"
else
    print_info "Waiting for MySQL snapshot to start (may take 1-2 minutes)"
fi

# ============================================================
# SUMMARY
# ============================================================

print_section "SUMMARY"

echo ""
echo "Configuration:"
echo "  ✓ ClickHouse tables: 450"
echo "  ✓ Kafka Connect: http://localhost:8085"
echo "  ✓ ClickHouse HTTP: http://localhost:8123"
echo "  ✓ Redpanda broker: localhost:9092"
echo ""
echo "Connectors:"
echo "  MySQL source: $MYSQL_TASK_STATE"
echo "  ClickHouse sink: $SINK_TASKS/4 tasks RUNNING"
echo ""
echo "Next steps:"
echo "  1. Monitor snapshot progress:"
echo "     cd $SCRIPT_DIR"
echo "     ./04_monitor_snapshot.sh"
echo ""
echo "  2. Check ClickHouse data (after a few minutes):"
echo "     docker exec clickhouse-server clickhouse-client --password '$CLICKHOUSE_PASSWORD' --query \"SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0\""
echo ""
echo "═══════════════════════════════════════════════════════════"
