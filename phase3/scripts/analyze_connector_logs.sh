#!/bin/bash
# Analyze Kafka Connect Logs for Errors
# Shows specific error patterns and their causes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  KAFKA CONNECT LOG ANALYZER                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get last 1000 log lines
echo "Analyzing last 1000 log lines from Kafka Connect..."
echo ""

LOGS=$(docker logs kafka-connect-clickhouse --tail 1000 2>&1)

# 1. Check for OutOfMemory errors
echo "1. MEMORY ERRORS"
echo "───────────────────────────────────────────────────────────"
OOM_COUNT=$(echo "$LOGS" | grep -c "OutOfMemoryError\|Java heap space" || echo "0")

if [ "$OOM_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $OOM_COUNT OutOfMemory errors${NC}"
    echo ""
    echo "  This causes 500 errors in Redpanda console!"
    echo ""
    echo "  Solution:"
    echo "    Increase Kafka Connect memory in docker-compose.yml:"
    echo "      KAFKA_HEAP_OPTS: '-Xmx4G -Xms2G'  # Increase from default"
    echo ""
    echo "  Recent OOM errors:"
    echo "$LOGS" | grep "OutOfMemoryError\|Java heap space" | tail -3
else
    echo -e "${GREEN}✓ No OutOfMemory errors${NC}"
fi

echo ""

# 2. Check for Connection Refused errors
echo "2. CONNECTION ERRORS"
echo "───────────────────────────────────────────────────────────"
CONN_COUNT=$(echo "$LOGS" | grep -c "Connection refused\|ConnectException" || echo "0")

if [ "$CONN_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $CONN_COUNT connection errors${NC}"
    echo ""
    echo "  This causes connectors to fail!"
    echo ""
    echo "  Check if services are running:"
    echo "    docker ps | grep -E 'mysql|clickhouse|redpanda'"
    echo ""
    echo "  Recent connection errors:"
    echo "$LOGS" | grep "Connection refused\|ConnectException" | tail -3
else
    echo -e "${GREEN}✓ No connection errors${NC}"
fi

echo ""

# 3. Check for ClickHouse errors
echo "3. CLICKHOUSE ERRORS"
echo "───────────────────────────────────────────────────────────"
CH_ERROR_COUNT=$(echo "$LOGS" | grep -c "ClickHouseException\|Code: 1001" || echo "0")

if [ "$CH_ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $CH_ERROR_COUNT ClickHouse errors${NC}"
    echo ""
    echo "  These records go to DLQ (Dead Letter Queue)"
    echo ""
    echo "  Common ClickHouse errors:"
    echo "$LOGS" | grep "ClickHouseException\|Code: 1001" | sed 's/^/    /' | tail -5
else
    echo -e "${GREEN}✓ No ClickHouse errors in recent logs${NC}"
fi

echo ""

# 4. Check for Task failures
echo "4. TASK FAILURES"
echo "───────────────────────────────────────────────────────────"
TASK_FAIL_COUNT=$(echo "$LOGS" | grep -c "Task.*failed\|WorkerSinkTask.*failed" || echo "0")

if [ "$TASK_FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $TASK_FAIL_COUNT task failures${NC}"
    echo ""
    echo "  This causes 500 errors!"
    echo ""
    echo "  Recent task failures:"
    echo "$LOGS" | grep "Task.*failed\|WorkerSinkTask.*failed" | tail -3
else
    echo -e "${GREEN}✓ No task failures${NC}"
fi

echo ""

# 5. Check for Snapshot completion
echo "5. SNAPSHOT STATUS"
echo "───────────────────────────────────────────────────────────"
SNAPSHOT_COMPLETE=$(echo "$LOGS" | grep -i "snapshot.*complet\|snapshot.*finish" | tail -1)

if [ -n "$SNAPSHOT_COMPLETE" ]; then
    echo -e "${GREEN}✓ Snapshot completed${NC}"
    echo "  Message: $SNAPSHOT_COMPLETE"
else
    SNAPSHOT_IN_PROGRESS=$(echo "$LOGS" | grep -i "snapshot" | tail -1)

    if [ -n "$SNAPSHOT_IN_PROGRESS" ]; then
        echo -e "${BLUE}ℹ Snapshot in progress${NC}"
        echo "  Last message: $SNAPSHOT_IN_PROGRESS"
    else
        echo -e "${YELLOW}⚠ No snapshot messages found${NC}"
        echo "  Snapshot may have already completed (check earlier logs)"
    fi
fi

echo ""

# 6. Check for Thread/Deadlock issues
echo "6. THREADING ISSUES"
echo "───────────────────────────────────────────────────────────"
THREAD_COUNT=$(echo "$LOGS" | grep -c "deadlock\|thread.*blocked\|thread.*stuck" || echo "0")

if [ "$THREAD_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $THREAD_COUNT threading issues${NC}"
    echo ""
    echo "  This can cause 500 errors and connector hangs!"
    echo ""
    echo "  Solution: Restart Kafka Connect"
    echo "    docker restart kafka-connect-clickhouse"
else
    echo -e "${GREEN}✓ No threading issues${NC}"
fi

echo ""

# 7. Check for Recent Restarts
echo "7. RECENT RESTARTS/CRASHES"
echo "───────────────────────────────────────────────────────────"
RESTART_COUNT=$(echo "$LOGS" | grep -c "Starting Kafka Connect" || echo "0")

echo "  Kafka Connect started $RESTART_COUNT time(s) in last 1000 log lines"

if [ "$RESTART_COUNT" -gt 2 ]; then
    echo -e "  ${YELLOW}⚠ Multiple restarts detected - investigate root cause${NC}"
elif [ "$RESTART_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ No startup messages - check full logs:${NC}"
    echo "    docker logs kafka-connect-clickhouse | grep 'Starting Kafka Connect'"
else
    echo -e "  ${GREEN}✓ Normal restart count${NC}"
fi

echo ""

# 8. Error Summary
echo "═══════════════════════════════════════════════════════════"
echo "ERROR SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

TOTAL_ERRORS=$((OOM_COUNT + CONN_COUNT + CH_ERROR_COUNT + TASK_FAIL_COUNT + THREAD_COUNT))

if [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ No critical errors found in recent logs${NC}"
    echo ""
    echo "If you're seeing 500 errors in Redpanda:"
    echo "  1. Check if Kafka Connect container is running:"
    echo "     docker ps | grep kafka-connect"
    echo ""
    echo "  2. Check Kafka Connect memory usage:"
    echo "     docker stats kafka-connect-clickhouse --no-stream"
    echo ""
    echo "  3. Try restarting Kafka Connect:"
    echo "     docker restart kafka-connect-clickhouse"
else
    echo -e "${RED}✗ Found $TOTAL_ERRORS error(s) in logs${NC}"
    echo ""
    echo "Breakdown:"
    echo "  OutOfMemory errors:    $OOM_COUNT"
    echo "  Connection errors:     $CONN_COUNT"
    echo "  ClickHouse errors:     $CH_ERROR_COUNT"
    echo "  Task failures:         $TASK_FAIL_COUNT"
    echo "  Threading issues:      $THREAD_COUNT"
    echo ""

    if [ "$OOM_COUNT" -gt 0 ]; then
        echo "Primary Issue: OutOfMemory - Increase Kafka Connect heap size"
    elif [ "$TASK_FAIL_COUNT" -gt 0 ]; then
        echo "Primary Issue: Task failures - Check connector configuration"
    elif [ "$CONN_COUNT" -gt 0 ]; then
        echo "Primary Issue: Connection errors - Check if services are accessible"
    elif [ "$THREAD_COUNT" -gt 0 ]; then
        echo "Primary Issue: Threading - Restart Kafka Connect"
    elif [ "$CH_ERROR_COUNT" -gt 0 ]; then
        echo "Primary Issue: ClickHouse errors - Data going to DLQ (non-critical)"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Full logs available at:"
echo "  docker logs kafka-connect-clickhouse"
echo "  docker logs kafka-connect-clickhouse --tail 200 > /tmp/connect_logs.txt"
echo ""
