#!/bin/bash
# Phase 3 - Monitor Snapshot Progress Script
# Purpose: Monitor the MySQL snapshot progress in real-time

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

CONNECT_URL="http://localhost:8085"
MONITOR_INTERVAL=10
CH_PASSWORD="ClickHouse_Secure_Pass_2024!"

clear

echo "========================================"
echo "   MySQL to ClickHouse Snapshot Monitor"
echo "========================================"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

get_connector_status() {
    local connector="$1"
    curl -s "$CONNECT_URL/connectors/$connector/status" 2>/dev/null || echo '{"error":"not found"}'
}

get_clickhouse_total_rows() {
    docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
        "SELECT formatReadableQuantity(sum(total_rows)) FROM system.tables WHERE database = 'analytics'" 2>/dev/null || echo "0"
}

get_clickhouse_table_count() {
    docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
        "SELECT count() FROM system.tables WHERE database = 'analytics'" 2>/dev/null || echo "0"
}

get_kafka_topic_count() {
    docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep -c "mysql\." || echo "0"
}

get_kafka_total_messages() {
    local total=0
    local topics=$(docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep "mysql\." | awk '{print $1}' || echo "")

    for topic in $topics; do
        local count=$(docker exec redpanda-clickhouse rpk topic describe "$topic" 2>/dev/null | grep "High Watermark" | awk '{sum+=$3} END {print sum}' || echo "0")
        total=$((total + count))
    done

    echo "$total"
}

# Initial values
PREV_ROWS=0
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))

    clear

    echo "========================================"
    echo "   Snapshot Progress Monitor"
    echo "========================================"
    echo ""
    echo -e "${CYAN}Monitoring started: $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}Elapsed time: ${ELAPSED_MIN} minutes${NC}"
    echo ""

    # Connector Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Connector Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    DEBEZIUM_STATUS=$(get_connector_status "mysql-source-connector")
    DEBEZIUM_STATE=$(echo "$DEBEZIUM_STATUS" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
    DEBEZIUM_TASKS=$(echo "$DEBEZIUM_STATUS" | grep -o '"state":"RUNNING"' | wc -l)

    if [ "$DEBEZIUM_STATE" = "RUNNING" ]; then
        echo -e "  MySQL Source: ${GREEN}$DEBEZIUM_STATE${NC} (Tasks: $DEBEZIUM_TASKS)"
    else
        echo -e "  MySQL Source: ${RED}$DEBEZIUM_STATE${NC}"
    fi

    SINK_STATUS=$(get_connector_status "clickhouse-sink-connector")
    SINK_STATE=$(echo "$SINK_STATUS" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$SINK_STATE" = "RUNNING" ]; then
        echo -e "  ClickHouse Sink: ${GREEN}$SINK_STATE${NC}"
    elif [ -z "$SINK_STATE" ] || [ "$SINK_STATE" = "error" ]; then
        echo -e "  ClickHouse Sink: ${YELLOW}OPTIONAL${NC} (using direct writes)"
    else
        echo -e "  ClickHouse Sink: ${RED}$SINK_STATE${NC}"
    fi

    echo ""

    # Kafka Topics
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Kafka Topics"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    TOPIC_COUNT=$(get_kafka_topic_count)
    KAFKA_MESSAGES=$(get_kafka_total_messages)

    echo "  Topics created: $TOPIC_COUNT"
    echo "  Total messages: $(printf "%'d" $KAFKA_MESSAGES)"
    echo ""

    # ClickHouse Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ClickHouse Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    TABLE_COUNT=$(get_clickhouse_table_count)
    TOTAL_ROWS=$(get_clickhouse_total_rows)

    echo "  Tables populated: $TABLE_COUNT"
    echo "  Total rows: $TOTAL_ROWS"

    # Calculate throughput
    if [ "$PREV_ROWS" != "0" ]; then
        CURRENT_ROWS_NUM=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
            "SELECT sum(total_rows) FROM system.tables WHERE database = 'analytics'" 2>/dev/null || echo "0")

        ROWS_DELTA=$((CURRENT_ROWS_NUM - PREV_ROWS))
        ROWS_PER_SEC=$((ROWS_DELTA / MONITOR_INTERVAL))

        if [ "$ROWS_PER_SEC" -gt 0 ]; then
            echo -e "  Throughput: ${GREEN}$(printf "%'d" $ROWS_PER_SEC) rows/sec${NC}"
        else
            echo "  Throughput: 0 rows/sec"
        fi

        PREV_ROWS=$CURRENT_ROWS_NUM
    else
        PREV_ROWS=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
            "SELECT sum(total_rows) FROM system.tables WHERE database = 'analytics'" 2>/dev/null || echo "0")
    fi

    echo ""

    # Top 5 tables by row count
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Top 5 Tables by Row Count"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
        "SELECT name, formatReadableQuantity(total_rows) as rows
         FROM system.tables
         WHERE database = 'analytics'
         ORDER BY total_rows DESC
         LIMIT 5
         FORMAT PrettyCompact" 2>/dev/null || echo "  No data yet"

    echo ""

    # Recent errors (if any)
    ERROR_COUNT=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null | grep -c '"type":"ERROR"' 2>/dev/null || echo "0")
    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n' | head -1)
    if [ ! -z "$ERROR_COUNT" ] && [ "$ERROR_COUNT" -gt 0 ] 2>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "  ${RED}⚠ Errors Detected: $ERROR_COUNT${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Check logs: docker logs kafka-connect-clickhouse"
        echo ""
    fi

    # Completion check
    if [ "$DEBEZIUM_STATE" = "RUNNING" ]; then
        # Check if snapshot is complete
        SNAPSHOT_STATUS=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null | grep -o '"SnapshotCompleted":"[^"]*"' || echo "")
        if echo "$SNAPSHOT_STATUS" | grep -q "true"; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "  ${GREEN}✓ Snapshot Complete!${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Run 05_validate_data.sh to verify data accuracy"
            echo ""
            break
        fi
    fi

    echo "Next update in $MONITOR_INTERVAL seconds..."
    sleep $MONITOR_INTERVAL
done
