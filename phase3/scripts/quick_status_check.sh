#!/bin/bash
# Quick Status Check - Monitor CDC Pipeline Without Disruption
# Run this periodically to track progress

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Quick Status Check - $(date +'%Y-%m-%d %H:%M:%S')           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 1. Connector Status
echo -e "${BOLD}1. Connector Status${NC}"
MYSQL_STATUS=$(curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['connector']['state'], '- Task:', data['tasks'][0]['state'])" 2>/dev/null || echo "ERROR")
CLICKHOUSE_STATUS=$(curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | python3 -c "import sys,json; data=json.load(sys.stdin); tasks=[t for t in data['tasks'] if t['state']=='RUNNING']; print(data['connector']['state'], '- Tasks:', len(tasks), '/4')" 2>/dev/null || echo "ERROR")

echo "  MySQL Source:     $MYSQL_STATUS"
echo "  ClickHouse Sink:  $CLICKHOUSE_STATUS"
echo ""

# 2. Data Progress
echo -e "${BOLD}2. Data Sync Progress${NC}"
CH_TABLES=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0" 2>/dev/null || echo "?")
CH_ROWS=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT sum(total_rows) FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "?")

echo "  Tables with data: $CH_TABLES / 450"
echo "  Total rows:       $(printf "%'d" $CH_ROWS)"
echo ""

# 3. Consumer Lag
echo -e "${BOLD}3. Consumer Lag${NC}"
CONSUMER_LAG=$(docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092 2>/dev/null | grep "TOTAL-LAG" | awk '{print $2}')
if [ -n "$CONSUMER_LAG" ] && [ "$CONSUMER_LAG" != "0" ]; then
    echo "  Records waiting:  $(printf "%'d" $CONSUMER_LAG)"

    # Calculate ETA (rough estimate: 1M rows per 10 mins = 100K per min)
    MINUTES_LEFT=$((CONSUMER_LAG / 100000))
    HOURS=$((MINUTES_LEFT / 60))
    MINS=$((MINUTES_LEFT % 60))

    if [ $HOURS -gt 0 ]; then
        echo "  Estimated time:   ~${HOURS}h ${MINS}m remaining"
    else
        echo "  Estimated time:   ~${MINS}m remaining"
    fi
else
    echo -e "  ${GREEN}✓ No lag - all messages consumed${NC}"
fi
echo ""

# 4. DLQ Status
echo -e "${BOLD}4. Dead Letter Queue (DLQ)${NC}"
DLQ_EXISTS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "clickhouse-dlq" || echo "0")

if [ "$DLQ_EXISTS" -eq 0 ]; then
    echo -e "  ${GREEN}✓ DLQ topic does not exist (no errors)${NC}"
else
    DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>/dev/null)
    DLQ_MESSAGES=$(echo "$DLQ_INFO" | grep -E "^[0-9]+" | awk 'NR==2 {print $5}' || echo "0")

    if ! [[ "$DLQ_MESSAGES" =~ ^[0-9]+$ ]]; then
        DLQ_MESSAGES=0
    fi

    if [ "$DLQ_MESSAGES" -eq 0 ]; then
        echo -e "  ${GREEN}✓ DLQ exists but has 0 messages${NC}"
    else
        DLQ_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($DLQ_MESSAGES / 46502780) * 100}")
        echo -e "  ${YELLOW}⚠ DLQ has $(printf "%'d" $DLQ_MESSAGES) messages ($DLQ_PERCENT% of total)${NC}"
    fi
fi
echo ""

# 5. Largest Table Progress
echo -e "${BOLD}5. Largest Table Progress (flatodd_flatodd)${NC}"
FLATODD_COUNT=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM analytics.flatodd_flatodd" 2>/dev/null || echo "0")
FLATODD_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($FLATODD_COUNT / 31878936) * 100}")
echo "  Rows synced:      $(printf "%'d" $FLATODD_COUNT) / 31,878,936 ($FLATODD_PERCENT%)"
echo ""

# 6. Summary
echo -e "${BOLD}6. Summary${NC}"
if [ "$CONSUMER_LAG" -gt 0 ]; then
    echo -e "  ${BLUE}ℹ Snapshot still running - wait for completion${NC}"
    echo "  Run this script again in 30 minutes to check progress"
elif [ "$DLQ_MESSAGES" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Snapshot complete but DLQ has errors${NC}"
    echo "  Run: ./validate_mysql_to_clickhouse.sh for detailed analysis"
else
    echo -e "  ${GREEN}✓ Pipeline healthy - all data synced successfully${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "For detailed analysis, run:"
echo "  ./validate_mysql_to_clickhouse.sh"
echo ""
echo "For DLQ error details, run:"
echo "  ./get_raw_dlq_error.sh"
echo ""
