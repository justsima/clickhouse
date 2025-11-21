#!/bin/bash
# Quick Connector Health Check
# Checks if connectors are running and if snapshot is complete

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  CONNECTOR HEALTH CHECK - $(date +'%H:%M:%S')                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if Kafka Connect is responding
echo "1. KAFKA CONNECT STATUS"
echo "───────────────────────────────────────────────────────────"
CONNECT_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8085/ -o /tmp/connect_test.txt 2>/dev/null)

if [ "$CONNECT_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Kafka Connect is responding (HTTP 200)"
else
    echo -e "${RED}✗${NC} Kafka Connect is NOT responding (HTTP $CONNECT_RESPONSE)"
    echo "  This explains the 500 errors in Redpanda console!"
    echo ""
    echo "  To restart Kafka Connect:"
    echo "    docker restart kafka-connect-clickhouse"
    exit 1
fi

echo ""

# Check MySQL Source Connector
echo "2. MYSQL SOURCE CONNECTOR"
echo "───────────────────────────────────────────────────────────"
MYSQL_STATUS=$(curl -s http://localhost:8085/connectors/mysql-source-connector/status 2>/dev/null)

if [ -z "$MYSQL_STATUS" ]; then
    echo -e "${RED}✗${NC} Cannot reach connector status endpoint"
    exit 1
fi

MYSQL_CONNECTOR_STATE=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null)
MYSQL_TASK_STATE=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['state'])" 2>/dev/null)
MYSQL_TASK_ID=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['id'])" 2>/dev/null)

echo "  Connector State: $MYSQL_CONNECTOR_STATE"
echo "  Task $MYSQL_TASK_ID State: $MYSQL_TASK_STATE"

if [ "$MYSQL_TASK_STATE" = "RUNNING" ]; then
    echo -e "  ${GREEN}✓ MySQL connector is RUNNING${NC}"
elif [ "$MYSQL_TASK_STATE" = "FAILED" ]; then
    echo -e "  ${RED}✗ MySQL connector task is FAILED${NC}"
    echo ""
    echo "  Error details:"
    echo "$MYSQL_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0].get('trace', 'No trace available'))" 2>/dev/null | head -10

    echo ""
    echo "  To check full logs:"
    echo "    docker logs kafka-connect-clickhouse --tail 100 | grep -i error"
else
    echo -e "  ${YELLOW}⚠ MySQL connector task state: $MYSQL_TASK_STATE${NC}"
fi

# Check if snapshot is complete
echo ""
echo "  Checking if snapshot is complete..."
SNAPSHOT_STATUS=$(docker logs kafka-connect-clickhouse 2>&1 | grep -i "snapshot.*complete\|snapshot.*finished" | tail -1)

if [ -n "$SNAPSHOT_STATUS" ]; then
    echo -e "  ${GREEN}✓ Snapshot appears complete${NC}"
    echo "    Last message: $SNAPSHOT_STATUS"
else
    echo -e "  ${YELLOW}⚠ Snapshot status unclear (check logs)${NC}"
fi

echo ""

# Check ClickHouse Sink Connector
echo "3. CLICKHOUSE SINK CONNECTOR"
echo "───────────────────────────────────────────────────────────"
SINK_STATUS=$(curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status 2>/dev/null)

if [ -z "$SINK_STATUS" ]; then
    echo -e "${RED}✗${NC} Cannot reach connector status endpoint"
    exit 1
fi

SINK_CONNECTOR_STATE=$(echo "$SINK_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null)
SINK_TASKS=$(echo "$SINK_STATUS" | python3 -c "import sys,json; tasks=json.load(sys.stdin)['tasks']; print(len([t for t in tasks if t['state']=='RUNNING']), '/', len(tasks))" 2>/dev/null)

echo "  Connector State: $SINK_CONNECTOR_STATE"
echo "  Running Tasks: $SINK_TASKS"

if [ "$SINK_CONNECTOR_STATE" = "RUNNING" ]; then
    echo -e "  ${GREEN}✓ ClickHouse sink is RUNNING${NC}"

    # Check for any failed tasks
    FAILED_TASKS=$(echo "$SINK_STATUS" | python3 -c "import sys,json; tasks=json.load(sys.stdin)['tasks']; print([t['id'] for t in tasks if t['state']=='FAILED'])" 2>/dev/null)

    if [ "$FAILED_TASKS" != "[]" ]; then
        echo -e "  ${RED}✗ Some tasks are FAILED: $FAILED_TASKS${NC}"
        echo ""
        echo "  Failed task details:"
        echo "$SINK_STATUS" | python3 -c "import sys,json; tasks=json.load(sys.stdin)['tasks']; [print(f\"Task {t['id']}: {t.get('trace', 'No trace')[:200]}\") for t in tasks if t['state']=='FAILED']" 2>/dev/null
    fi
elif [ "$SINK_CONNECTOR_STATE" = "FAILED" ]; then
    echo -e "  ${RED}✗ ClickHouse sink connector is FAILED${NC}"
else
    echo -e "  ${YELLOW}⚠ ClickHouse sink state: $SINK_CONNECTOR_STATE${NC}"
fi

echo ""

# Check Consumer Lag
echo "4. CONSUMER LAG (Are messages being processed?)"
echo "───────────────────────────────────────────────────────────"
CONSUMER_LAG=$(docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092 2>/dev/null | grep "TOTAL-LAG" | awk '{print $2}')

if [ -z "$CONSUMER_LAG" ]; then
    echo -e "${YELLOW}⚠${NC} Could not determine consumer lag"
elif [ "$CONSUMER_LAG" = "0" ]; then
    echo -e "${GREEN}✓${NC} Consumer lag: 0 (all messages consumed)"
else
    echo -e "${BLUE}ℹ${NC} Consumer lag: $(printf "%'d" $CONSUMER_LAG) messages waiting"

    # Calculate ETA
    if [ "$CONSUMER_LAG" -gt 100000 ]; then
        ETA_MINS=$((CONSUMER_LAG / 100000))
        echo "  Estimated time to process: ~${ETA_MINS} minutes"
    fi
fi

echo ""

# Check Recent Kafka Connect Errors
echo "5. RECENT KAFKA CONNECT ERRORS (Last 5 errors)"
echo "───────────────────────────────────────────────────────────"
RECENT_ERRORS=$(docker logs kafka-connect-clickhouse --tail 500 2>&1 | grep -i "ERROR\|Exception" | grep -v "errors.tolerance" | tail -5)

if [ -z "$RECENT_ERRORS" ]; then
    echo -e "${GREEN}✓${NC} No recent errors in Kafka Connect logs"
else
    echo -e "${YELLOW}⚠${NC} Found recent errors:"
    echo ""
    echo "$RECENT_ERRORS"
fi

echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ "$MYSQL_TASK_STATE" = "RUNNING" ] && [ "$SINK_CONNECTOR_STATE" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Both connectors are RUNNING${NC}"

    if [ "$CONSUMER_LAG" = "0" ]; then
        echo -e "${GREEN}✓ Snapshot is COMPLETE${NC}"
        echo ""
        echo "Your CDC pipeline is healthy!"
    else
        echo -e "${BLUE}ℹ Snapshot is IN PROGRESS${NC}"
        echo ""
        echo "Wait for consumer lag to reach 0, then snapshot is complete."
    fi
else
    echo -e "${RED}✗ One or more connectors have issues${NC}"
    echo ""
    echo "Action Required:"
    echo "  1. Check detailed logs:"
    echo "     docker logs kafka-connect-clickhouse --tail 200"
    echo ""
    echo "  2. Check ClickHouse logs:"
    echo "     docker logs clickhouse-server --tail 100"
    echo ""
    echo "  3. Restart connectors if needed:"
    echo "     docker restart kafka-connect-clickhouse"
fi

echo ""
