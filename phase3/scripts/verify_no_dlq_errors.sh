#!/bin/bash
# Comprehensive Verification - Ensure No DLQ Errors
# Purpose: Verify data is flowing correctly and not going to DLQ

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
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Verify No DLQ Errors - Data Flow Validation             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# ============================================================
# CHECK 1: DEAD LETTER QUEUE
# ============================================================

print_section "CHECK 1: DEAD LETTER QUEUE (DLQ)"

echo ""
print_info "Checking if DLQ topic exists and has errors..."

DLQ_EXISTS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "clickhouse-dlq" || echo "0")

if [ "$DLQ_EXISTS" -eq 0 ]; then
    print_status 0 "DLQ topic does not exist (GOOD - no errors)"
    DLQ_MESSAGES=0
else
    echo ""
    print_info "DLQ topic exists, checking for messages..."

    DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>/dev/null)
    DLQ_MESSAGES=$(echo "$DLQ_INFO" | grep -E "^[0-9]+" | awk 'NR==2 {print $5}' || echo "0")

    # Ensure it's a valid number
    if ! [[ "$DLQ_MESSAGES" =~ ^[0-9]+$ ]]; then
        DLQ_MESSAGES=0
    fi

    if [ "$DLQ_MESSAGES" -eq 0 ]; then
        print_status 0 "DLQ exists but has 0 messages (GOOD)"
    else
        print_status 1 "DLQ has $DLQ_MESSAGES messages (ERROR - data going to DLQ!)"
        echo ""
        echo -e "${RED}${BOLD}⚠️  WARNING: Records are going to Dead Letter Queue!${NC}"
        echo ""
        echo "Reading first DLQ message to see error..."
        docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq --brokers localhost:9092 --num 1 2>/dev/null | head -20
        echo ""
        echo "This means the RegexRouter fix is NOT working or there's another issue!"
    fi
fi

# ============================================================
# CHECK 2: TOPICS WITH DATA
# ============================================================

print_section "CHECK 2: TOPICS WITH DATA"

echo ""
print_info "Checking if Kafka topics have actual data..."

# Sample 5 topics and check their message counts
SAMPLE_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\\.${MYSQL_DATABASE}\\." | head -5 | awk '{print $1}')

echo ""
echo "Sample topics and their message counts:"
echo "----------------------------------------"

TOTAL_MESSAGES=0
TOPICS_WITH_DATA=0

for topic in $SAMPLE_TOPICS; do
    HIGH_WATER=$(docker exec redpanda-clickhouse rpk topic describe "$topic" --brokers localhost:9092 2>/dev/null | grep "high water mark" | awk '{print $4}')

    if [ -n "$HIGH_WATER" ] && [ "$HIGH_WATER" -gt 0 ]; then
        echo "  ✓ $topic: $HIGH_WATER messages"
        TOTAL_MESSAGES=$((TOTAL_MESSAGES + HIGH_WATER))
        TOPICS_WITH_DATA=$((TOPICS_WITH_DATA + 1))
    else
        echo "  ○ $topic: 0 messages (snapshot not reached yet)"
    fi
done

echo ""
if [ "$TOPICS_WITH_DATA" -gt 0 ]; then
    print_status 0 "$TOPICS_WITH_DATA topics have data ($TOTAL_MESSAGES messages sampled)"
else
    print_warning "No topics have data yet (snapshot still starting)"
fi

# ============================================================
# CHECK 3: CONSUMER GROUP PROGRESS
# ============================================================

print_section "CHECK 3: CONSUMER GROUP PROGRESS"

echo ""
print_info "Checking if ClickHouse sink is consuming data..."

CONSUMER_INFO=$(docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092 2>/dev/null)

if echo "$CONSUMER_INFO" | grep -q "MEMBER"; then
    print_status 0 "Consumer group is active"

    echo ""
    echo "Consumer Group Details:"
    echo "$CONSUMER_INFO" | head -10

    # Check lag
    TOTAL_LAG=$(echo "$CONSUMER_INFO" | grep "TOTAL-LAG" | awk '{print $2}')

    echo ""
    if [ "$TOTAL_LAG" = "0" ]; then
        print_info "Lag: 0 (consumer is caught up or waiting for data)"
    else
        print_info "Lag: $TOTAL_LAG records (consumer is processing)"
    fi
else
    print_warning "Consumer group not active yet"
fi

# ============================================================
# CHECK 4: CLICKHOUSE TABLES
# ============================================================

print_section "CHECK 4: CLICKHOUSE DATA VERIFICATION"

echo ""
print_info "Checking which tables have data..."

TABLES_WITH_DATA=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND total_rows > 0" 2>/dev/null || echo "0")

echo ""
if [ "$TABLES_WITH_DATA" -gt 0 ]; then
    print_status 0 "ClickHouse has data in $TABLES_WITH_DATA tables!"

    echo ""
    echo "Top 10 tables by row count:"
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
    FORMAT Pretty
    " 2>/dev/null
else
    print_warning "No data in ClickHouse yet"

    echo ""
    echo "Possible reasons:"
    echo "  1. Data is being buffered (bufferCount: 10000, flushInterval: 10s)"
    echo "  2. Snapshot just started, data not consumed yet"
    echo "  3. Data is going to DLQ (check above)"
fi

# ============================================================
# CHECK 5: SAMPLE TOPIC TO TABLE MAPPING
# ============================================================

print_section "CHECK 5: TOPIC → TABLE MAPPING VERIFICATION"

echo ""
print_info "Verifying RegexRouter is correctly stripping prefixes..."

# Pick a sample topic
SAMPLE_TOPIC=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "mysql\\.${MYSQL_DATABASE}\\." | head -1 | awk '{print $1}')

if [ -n "$SAMPLE_TOPIC" ]; then
    # Extract table name using same regex as connector
    TABLE_NAME=$(echo "$SAMPLE_TOPIC" | sed "s/mysql\\.${MYSQL_DATABASE}\\.//")

    echo ""
    echo "Sample Mapping Test:"
    echo "  Kafka Topic:     $SAMPLE_TOPIC"
    echo "  Expected Table:  $TABLE_NAME"

    # Check if table exists in ClickHouse
    TABLE_EXISTS=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND name = '$TABLE_NAME'" 2>/dev/null)

    if [ "$TABLE_EXISTS" -eq 1 ]; then
        print_status 0 "Table exists in ClickHouse"

        # Check if it has data
        ROW_COUNT=$(docker exec clickhouse-server clickhouse-client --password "$CLICKHOUSE_PASSWORD" --query "SELECT total_rows FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND name = '$TABLE_NAME'" 2>/dev/null)

        if [ "$ROW_COUNT" -gt 0 ]; then
            print_status 0 "Table has $ROW_COUNT rows (RegexRouter working!)"
        else
            print_info "Table exists but has 0 rows (data not consumed yet)"
        fi
    else
        print_status 1 "Table does NOT exist in ClickHouse"
        echo ""
        echo "This could mean:"
        echo "  - Schema for this table hasn't been created yet"
        echo "  - Topic name mapping issue"
    fi
fi

# ============================================================
# CHECK 6: KAFKA CONNECT LOGS
# ============================================================

print_section "CHECK 6: KAFKA CONNECT ERROR LOGS"

echo ""
print_info "Checking recent Kafka Connect logs for errors..."

RECENT_ERRORS=$(docker logs kafka-connect-clickhouse --tail 100 2>&1 | grep -i "error\|exception\|failed" | grep -v "errors.tolerance" | tail -10)

if [ -z "$RECENT_ERRORS" ]; then
    print_status 0 "No recent errors in Kafka Connect logs"
else
    print_warning "Found recent errors/exceptions:"
    echo ""
    echo "$RECENT_ERRORS"
fi

# ============================================================
# SUMMARY
# ============================================================

print_section "SUMMARY"

# Ensure all variables are valid numbers
if ! [[ "$DLQ_MESSAGES" =~ ^[0-9]+$ ]]; then DLQ_MESSAGES=0; fi
if ! [[ "$TOPICS_WITH_DATA" =~ ^[0-9]+$ ]]; then TOPICS_WITH_DATA=0; fi
if ! [[ "$TABLES_WITH_DATA" =~ ^[0-9]+$ ]]; then TABLES_WITH_DATA=0; fi

echo ""
echo "Status Check:"
echo "  DLQ Messages:        $DLQ_MESSAGES"
echo "  Topics with Data:    $TOPICS_WITH_DATA (sampled)"
echo "  ClickHouse Tables:   $TABLES_WITH_DATA tables with data"
echo "  Consumer Lag:        $TOTAL_LAG"
echo ""

if [ "$DLQ_MESSAGES" -eq 0 ] && [ "$TABLES_WITH_DATA" -gt 0 ]; then
    echo -e "${GREEN}${BOLD}✓ SUCCESS! No DLQ errors, data flowing to ClickHouse!${NC}"
    echo ""
    echo "The pipeline is working correctly:"
    echo "  MySQL → Debezium → Redpanda → ClickHouse ✓"
elif [ "$DLQ_MESSAGES" -gt 0 ]; then
    echo -e "${RED}${BOLD}✗ ERROR! Data going to DLQ - RegexRouter not working${NC}"
    echo ""
    echo "Action Required:"
    echo "  1. Check DLQ messages above for error details"
    echo "  2. Verify connector configuration"
    echo "  3. Check ClickHouse table schemas match topic data"
elif [ "$TABLES_WITH_DATA" -eq 0 ] && [ "$TOPICS_WITH_DATA" -eq 0 ]; then
    echo -e "${YELLOW}⚠ WAITING: Snapshot just started, no data yet${NC}"
    echo ""
    echo "This is normal if you just restarted the pipeline."
    echo "Wait 2-5 minutes and run this script again."
elif [ "$TABLES_WITH_DATA" -eq 0 ] && [ "$TOPICS_WITH_DATA" -gt 0 ]; then
    echo -e "${YELLOW}⚠ DATA IN KAFKA BUT NOT IN CLICKHOUSE${NC}"
    echo ""
    echo "Possible causes:"
    echo "  1. Data is buffered (wait 10-30 seconds)"
    echo "  2. Consumer lag > 0 (data being processed)"
    echo "  3. Silent errors (check Kafka Connect logs)"
    echo ""
    echo "Wait 1-2 minutes and run this script again."
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
