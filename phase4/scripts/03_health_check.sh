#!/bin/bash
# Phase 4 - Health Check Script
# Purpose: Quick health check of all system components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(dirname "$SCRIPT_DIR")"
PHASE3_DIR="$(dirname "$PHASE4_DIR")/phase3"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

CONNECT_URL="http://localhost:8085"
CLICKHOUSE_URL="http://localhost:8123"
REDPANDA_URL="http://localhost:8086"

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

echo "========================================"
echo "   System Health Check"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. Docker Containers
echo "1. Docker Containers"
echo "--------------------"

CLICKHOUSE_STATUS=$(docker ps --filter "name=clickhouse" --format "{{.Status}}" 2>/dev/null || echo "Not running")
REDPANDA_STATUS=$(docker ps --filter "name=redpanda" --format "{{.Status}}" 2>/dev/null || echo "Not running")
CONNECT_STATUS=$(docker ps --filter "name=kafka-connect" --format "{{.Status}}" 2>/dev/null || echo "Not running")
CONSOLE_STATUS=$(docker ps --filter "name=redpanda-console" --format "{{.Status}}" 2>/dev/null || echo "Not running")

if echo "$CLICKHOUSE_STATUS" | grep -q "Up"; then
    print_status 0 "ClickHouse: $CLICKHOUSE_STATUS"
else
    print_status 1 "ClickHouse: $CLICKHOUSE_STATUS"
fi

if echo "$REDPANDA_STATUS" | grep -q "Up"; then
    print_status 0 "Redpanda: $REDPANDA_STATUS"
else
    print_status 1 "Redpanda: $REDPANDA_STATUS"
fi

if echo "$CONNECT_STATUS" | grep -q "Up"; then
    print_status 0 "Kafka Connect: $CONNECT_STATUS"
else
    print_status 1 "Kafka Connect: $CONNECT_STATUS"
fi

if echo "$CONSOLE_STATUS" | grep -q "Up"; then
    print_status 0 "Redpanda Console: $CONSOLE_STATUS"
else
    print_status 1 "Redpanda Console: $CONSOLE_STATUS"
fi

echo ""

# 2. Service Endpoints
echo "2. Service Endpoints"
echo "--------------------"

# ClickHouse
if curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT 1" | grep -q "1"; then
    print_status 0 "ClickHouse HTTP ($CLICKHOUSE_URL): Responding"
else
    print_status 1 "ClickHouse HTTP ($CLICKHOUSE_URL): Not responding"
fi

# Kafka Connect
if curl -s "$CONNECT_URL/" | grep -q "version"; then
    print_status 0 "Kafka Connect ($CONNECT_URL): Responding"
else
    print_status 1 "Kafka Connect ($CONNECT_URL): Not responding"
fi

# Redpanda Console
if curl -s "$REDPANDA_URL" -o /dev/null -w "%{http_code}" | grep -q "200"; then
    print_status 0 "Redpanda Console ($REDPANDA_URL): Responding"
else
    print_status 1 "Redpanda Console ($REDPANDA_URL): Not responding"
fi

echo ""

# 3. Kafka Connect Connectors
echo "3. Kafka Connectors"
echo "-------------------"

DEBEZIUM_STATUS=$(curl -s "$CONNECT_URL/connectors/mysql-source-connector/status" 2>/dev/null | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null || echo "UNKNOWN")

SINK_STATUS=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null || echo "UNKNOWN")

if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
    print_status 0 "Debezium MySQL Source: $DEBEZIUM_STATUS"
elif [ "$DEBEZIUM_STATUS" = "UNKNOWN" ]; then
    print_status 1 "Debezium MySQL Source: Not deployed"
else
    print_status 1 "Debezium MySQL Source: $DEBEZIUM_STATUS"
fi

if [ "$SINK_STATUS" = "RUNNING" ]; then
    print_status 0 "ClickHouse Sink: $SINK_STATUS"
elif [ "$SINK_STATUS" = "UNKNOWN" ]; then
    echo -e "${YELLOW}⚠${NC} ClickHouse Sink: Not deployed (using alternative approach)"
else
    print_status 1 "ClickHouse Sink: $SINK_STATUS"
fi

echo ""

# 4. MySQL Connectivity
echo "4. MySQL Connectivity"
echo "---------------------"

if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SELECT 1" &>/dev/null; then
    print_status 0 "MySQL connection: OK"
else
    print_status 1 "MySQL connection: Failed"
fi

echo ""

# 5. Data Pipeline Status
echo "5. Data Pipeline Status"
echo "-----------------------"

# Check if data is flowing
TOTAL_TABLES=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "0")

TOTAL_ROWS=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT sum(total_rows) FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "0")

echo "  Tables in ClickHouse: $TOTAL_TABLES"
echo "  Total rows: $TOTAL_ROWS"

if [ "$TOTAL_ROWS" != "0" ] && [ "$TOTAL_ROWS" != "" ]; then
    print_status 0 "Data present in ClickHouse"
else
    print_status 1 "No data in ClickHouse yet"
fi

echo ""

# 6. System Resources
echo "6. System Resources"
echo "-------------------"

# Disk usage
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

echo "  Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available)"

if [ $DISK_USAGE -gt 90 ]; then
    print_status 1 "Disk usage critical (${DISK_USAGE}%)"
elif [ $DISK_USAGE -gt 80 ]; then
    echo -e "${YELLOW}⚠${NC} Disk usage high (${DISK_USAGE}%)"
else
    print_status 0 "Disk usage healthy (${DISK_USAGE}%)"
fi

# Memory usage
MEM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
echo "  Memory usage: ${MEM_USAGE}%"

if [ $MEM_USAGE -gt 90 ]; then
    print_status 1 "Memory usage critical (${MEM_USAGE}%)"
elif [ $MEM_USAGE -gt 80 ]; then
    echo -e "${YELLOW}⚠${NC} Memory usage high (${MEM_USAGE}%)"
else
    print_status 0 "Memory usage healthy (${MEM_USAGE}%)"
fi

echo ""

# Overall Status
echo "========================================"
echo "Overall Status"
echo "========================================"

# Count issues
ISSUES=0

if ! echo "$CLICKHOUSE_STATUS" | grep -q "Up"; then ISSUES=$((ISSUES + 1)); fi
if ! echo "$REDPANDA_STATUS" | grep -q "Up"; then ISSUES=$((ISSUES + 1)); fi
if ! echo "$CONNECT_STATUS" | grep -q "Up"; then ISSUES=$((ISSUES + 1)); fi
if [ "$DEBEZIUM_STATUS" != "RUNNING" ]; then ISSUES=$((ISSUES + 1)); fi
if [ $DISK_USAGE -gt 90 ]; then ISSUES=$((ISSUES + 1)); fi
if [ $MEM_USAGE -gt 90 ]; then ISSUES=$((ISSUES + 1)); fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ ALL SYSTEMS HEALTHY${NC}"
    exit 0
elif [ $ISSUES -lt 3 ]; then
    echo -e "${YELLOW}⚠ MINOR ISSUES DETECTED${NC} ($ISSUES issues)"
    exit 1
else
    echo -e "${RED}✗ CRITICAL ISSUES DETECTED${NC} ($ISSUES issues)"
    exit 2
fi
