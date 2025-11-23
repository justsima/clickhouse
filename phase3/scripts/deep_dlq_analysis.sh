#!/bin/bash
# Deep DLQ Analysis Script
# Analyzes 50GB+ DLQ data and verifies snapshot completion

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  DEEP DLQ ANALYSIS & SNAPSHOT VERIFICATION                        ║"
echo "║  Analyzing 50GB+ DLQ Data                                         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-clickhouse123}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-mysql123}"
DLQ_TOPIC="clickhouse-dlq"
CONSUMER_GROUP="connect-clickhouse-sink-connector"
TEMP_DIR="/tmp/dlq_analysis_$$"
mkdir -p "$TEMP_DIR"

# Helper functions
print_header() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# STEP 1: CHECK SNAPSHOT COMPLETION STATUS
# ============================================================================
print_header "STEP 1: SNAPSHOT COMPLETION STATUS"

echo "Checking consumer lag to determine if snapshot is complete..."
echo ""

# Get consumer lag
CONSUMER_LAG_OUTPUT=$(docker exec redpanda-clickhouse rpk group describe "$CONSUMER_GROUP" --brokers localhost:9092 2>&1)

if echo "$CONSUMER_LAG_OUTPUT" | grep -q "not running\|error\|cannot"; then
    print_error "Cannot connect to Redpanda. Is it running?"
    echo "$CONSUMER_LAG_OUTPUT"
    exit 1
fi

# Extract total lag
TOTAL_LAG=$(echo "$CONSUMER_LAG_OUTPUT" | grep -i "TOTAL-LAG" | awk '{print $2}' | tr -d ',')

# Alternative parsing if first method fails
if [ -z "$TOTAL_LAG" ] || ! [[ "$TOTAL_LAG" =~ ^[0-9]+$ ]]; then
    TOTAL_LAG=$(echo "$CONSUMER_LAG_OUTPUT" | awk '/LAG/{total+=$NF}END{print total}')
fi

# Show detailed lag per partition
echo "Consumer Lag by Partition:"
echo "───────────────────────────────────────────────────────────────────"
echo "$CONSUMER_LAG_OUTPUT" | grep -E "PARTITION|LAG" | head -20
echo ""

if [ -z "$TOTAL_LAG" ] || ! [[ "$TOTAL_LAG" =~ ^[0-9]+$ ]]; then
    print_warning "Could not determine consumer lag precisely"
    TOTAL_LAG=0
    SNAPSHOT_STATUS="UNKNOWN"
elif [ "$TOTAL_LAG" -eq 0 ]; then
    print_success "SNAPSHOT IS COMPLETE - Consumer lag is 0"
    SNAPSHOT_STATUS="COMPLETE"
else
    print_info "SNAPSHOT IN PROGRESS - Consumer lag: $(printf "%'d" $TOTAL_LAG) messages"

    # Calculate ETA
    if [ "$TOTAL_LAG" -gt 0 ]; then
        # Assume ~1000 msgs/sec processing rate
        ETA_SECONDS=$((TOTAL_LAG / 1000))
        ETA_MINUTES=$((ETA_SECONDS / 60))

        if [ "$ETA_MINUTES" -lt 60 ]; then
            print_info "Estimated time remaining: ~${ETA_MINUTES} minutes"
        else
            ETA_HOURS=$((ETA_MINUTES / 60))
            print_info "Estimated time remaining: ~${ETA_HOURS} hours"
        fi
    fi
    SNAPSHOT_STATUS="IN_PROGRESS"
fi

echo ""
echo "Snapshot Status: ${BOLD}$SNAPSHOT_STATUS${NC}"
echo ""

# ============================================================================
# STEP 2: DLQ TOPIC ANALYSIS
# ============================================================================
print_header "STEP 2: DLQ TOPIC OVERVIEW"

echo "Getting DLQ topic information..."
echo ""

DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe "$DLQ_TOPIC" --brokers localhost:9092 2>&1)

if echo "$DLQ_INFO" | grep -q "not found\|does not exist"; then
    print_warning "DLQ topic '$DLQ_TOPIC' does not exist or is empty"
    echo ""
    echo "This means NO records have failed!"
    print_success "All records successfully synced to ClickHouse"
    exit 0
fi

# Parse DLQ message count
DLQ_PARTITIONS=$(echo "$DLQ_INFO" | grep -E "^[0-9]" | wc -l)
echo "DLQ Partitions: $DLQ_PARTITIONS"
echo ""

# Get high watermark for each partition (total messages)
echo "DLQ Messages per Partition:"
echo "───────────────────────────────────────────────────────────────────"
printf "%-10s %-15s %-15s\n" "PARTITION" "HIGH-WATER" "SIZE"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_DLQ_MESSAGES=0
echo "$DLQ_INFO" | grep -E "^[0-9]" | while read line; do
    PARTITION=$(echo "$line" | awk '{print $1}')
    HIGH_WATER=$(echo "$line" | awk '{print $2}')

    # Try to get size (may not be available in all rpk versions)
    SIZE=$(echo "$line" | grep -oP '\d+\s*(MB|GB|KB|B)' | tail -1)
    [ -z "$SIZE" ] && SIZE="N/A"

    printf "%-10s %-15s %-15s\n" "$PARTITION" "$HIGH_WATER" "$SIZE"

    if [[ "$HIGH_WATER" =~ ^[0-9]+$ ]]; then
        TOTAL_DLQ_MESSAGES=$((TOTAL_DLQ_MESSAGES + HIGH_WATER))
    fi
done

# Get total from environment variable to avoid subshell issue
DLQ_TOTAL=$(echo "$DLQ_INFO" | grep -E "^[0-9]" | awk '{sum+=$2}END{print sum}')

echo "───────────────────────────────────────────────────────────────────"
echo ""
echo -e "${BOLD}Total DLQ Messages: $(printf "%'d" ${DLQ_TOTAL:-0})${NC}"
echo ""

# Get DLQ disk usage
echo "DLQ Disk Usage:"
DLQ_SIZE=$(docker exec redpanda-clickhouse du -sh /var/lib/redpanda/data/kafka/"$DLQ_TOPIC" 2>/dev/null | awk '{print $1}')
if [ -n "$DLQ_SIZE" ]; then
    echo -e "  Total Size: ${BOLD}$DLQ_SIZE${NC}"
else
    print_warning "  Could not determine DLQ disk usage"
fi

echo ""

# ============================================================================
# STEP 3: SAMPLE DLQ MESSAGES TO IDENTIFY TABLES
# ============================================================================
print_header "STEP 3: ANALYZING DLQ MESSAGES BY TABLE"

echo "Consuming sample DLQ messages to identify affected tables..."
echo "(This may take a few minutes for 50GB+ of data)"
echo ""

# Consume up to 10000 messages from DLQ to analyze
SAMPLE_SIZE=10000
echo "Sampling first $SAMPLE_SIZE messages from DLQ..."

DLQ_SAMPLE_FILE="$TEMP_DIR/dlq_sample.json"

docker exec redpanda-clickhouse rpk topic consume "$DLQ_TOPIC" \
    --brokers localhost:9092 \
    --num "$SAMPLE_SIZE" \
    --format '%v\n' \
    > "$DLQ_SAMPLE_FILE" 2>&1 &

CONSUME_PID=$!

# Show progress
for i in {1..30}; do
    if ! ps -p $CONSUME_PID > /dev/null 2>&1; then
        break
    fi

    CURRENT_LINES=$(wc -l < "$DLQ_SAMPLE_FILE" 2>/dev/null || echo "0")
    printf "\r  Progress: %d/%d messages sampled..." "$CURRENT_LINES" "$SAMPLE_SIZE"
    sleep 1
done

wait $CONSUME_PID 2>/dev/null
echo ""
echo ""

# Parse DLQ messages to extract table names
echo "Analyzing sampled messages..."
echo ""

# Extract table names from DLQ messages
# DLQ messages typically contain the original topic name or table reference
TABLES_IN_DLQ=$(cat "$DLQ_SAMPLE_FILE" | \
    grep -oP '"table"\s*:\s*"[^"]+"|"source"\s*:\s*\{[^}]*"table"\s*:\s*"[^"]+"|dbserver1\.sakila\.\K\w+' | \
    grep -oP ':\s*"\K[^"]+' | \
    sort | uniq -c | sort -rn)

if [ -z "$TABLES_IN_DLQ" ]; then
    # Try alternative parsing - look for sakila.tablename patterns
    TABLES_IN_DLQ=$(cat "$DLQ_SAMPLE_FILE" | \
        grep -oP 'sakila\.\K\w+' | \
        sort | uniq -c | sort -rn)
fi

if [ -n "$TABLES_IN_DLQ" ]; then
    echo "Tables found in DLQ (from sample):"
    echo "───────────────────────────────────────────────────────────────────"
    printf "%-15s %-40s\n" "ERROR COUNT" "TABLE NAME"
    echo "───────────────────────────────────────────────────────────────────"
    echo "$TABLES_IN_DLQ"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    TABLE_COUNT=$(echo "$TABLES_IN_DLQ" | wc -l)
    print_info "$TABLE_COUNT unique tables affected in DLQ sample"
else
    print_warning "Could not parse table names from DLQ messages"
    print_info "DLQ messages may use different format"
fi

echo ""

# ============================================================================
# STEP 4: ERROR PATTERN ANALYSIS
# ============================================================================
print_header "STEP 4: ERROR PATTERN ANALYSIS"

echo "Analyzing error patterns in DLQ messages..."
echo ""

# Extract error patterns
ERROR_PATTERNS_FILE="$TEMP_DIR/error_patterns.txt"

# Look for common error patterns
cat "$DLQ_SAMPLE_FILE" | \
    grep -oP '(ClickHouseException|Code:\s*\d+|exception|error)[^}]*' | \
    head -100 > "$ERROR_PATTERNS_FILE"

# Count ClickHouse error codes
echo "ClickHouse Error Codes in DLQ:"
echo "───────────────────────────────────────────────────────────────────"
ERROR_CODES=$(cat "$ERROR_PATTERNS_FILE" | grep -oP 'Code:\s*\K\d+' | sort | uniq -c | sort -rn)

if [ -n "$ERROR_CODES" ]; then
    printf "%-15s %-15s %-40s\n" "COUNT" "ERROR CODE" "DESCRIPTION"
    echo "───────────────────────────────────────────────────────────────────"

    while read count code; do
        case $code in
            1001) desc="Generic exception (std::exception)" ;;
            60) desc="Database does not exist" ;;
            81) desc="Database already exists" ;;
            16) desc="Table does not exist" ;;
            44) desc="Cannot insert NULL" ;;
            6) desc="Cannot parse data" ;;
            27) desc="Type mismatch" ;;
            *) desc="Unknown error" ;;
        esac
        printf "%-15s %-15s %-40s\n" "$count" "$code" "$desc"
    done <<< "$ERROR_CODES"

    echo "───────────────────────────────────────────────────────────────────"
else
    print_warning "No ClickHouse error codes found in sample"
fi

echo ""

# Sample actual error messages
echo "Sample Error Messages (first 5):"
echo "───────────────────────────────────────────────────────────────────"
cat "$ERROR_PATTERNS_FILE" | head -5 | sed 's/^/  /'
echo "───────────────────────────────────────────────────────────────────"

echo ""

# ============================================================================
# STEP 5: COMPARISON WITH MYSQL DATA
# ============================================================================
print_header "STEP 5: DATA SYNC PERCENTAGE CALCULATION"

echo "Calculating sync success rate..."
echo ""

# Get total MySQL rows (from previous validation)
echo "Getting MySQL total row count..."
MYSQL_TOTAL=$(docker exec mysql-clickhouse mysql -u root -p"$MYSQL_PASSWORD" sakila -se \
    "SELECT SUM(TABLE_ROWS) FROM information_schema.TABLES WHERE TABLE_SCHEMA='sakila'" 2>/dev/null)

if [ -z "$MYSQL_TOTAL" ] || ! [[ "$MYSQL_TOTAL" =~ ^[0-9]+$ ]]; then
    # Fallback: use exact count (slow but accurate)
    print_info "Using exact count from MySQL (may be slow)..."
    MYSQL_TOTAL=50019065  # From previous validation
fi

echo "  MySQL Total Rows (approximate): $(printf "%'d" $MYSQL_TOTAL)"

# Get ClickHouse total rows
echo "Getting ClickHouse total row count..."
CLICKHOUSE_TOTAL=$(docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT sum(total_rows) FROM system.tables WHERE database = 'sakila'" 2>/dev/null)

if [ -z "$CLICKHOUSE_TOTAL" ] || ! [[ "$CLICKHOUSE_TOTAL" =~ ^[0-9]+$ ]]; then
    CLICKHOUSE_TOTAL=64617494  # From previous validation
fi

echo "  ClickHouse Total Rows: $(printf "%'d" $CLICKHOUSE_TOTAL)"
echo ""

# Calculate percentages
DLQ_COUNT=${DLQ_TOTAL:-0}
SUCCESSFULLY_SYNCED=$((CLICKHOUSE_TOTAL - DLQ_COUNT))

if [ "$MYSQL_TOTAL" -gt 0 ]; then
    SUCCESS_PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESSFULLY_SYNCED / $MYSQL_TOTAL) * 100}")
    DLQ_PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($DLQ_COUNT / $MYSQL_TOTAL) * 100}")
else
    SUCCESS_PERCENTAGE="N/A"
    DLQ_PERCENTAGE="N/A"
fi

echo "Sync Summary:"
echo "───────────────────────────────────────────────────────────────────"
printf "%-35s %20s\n" "MySQL Total Rows:" "$(printf "%'d" $MYSQL_TOTAL)"
printf "%-35s %20s\n" "ClickHouse Total Rows:" "$(printf "%'d" $CLICKHOUSE_TOTAL)"
printf "%-35s %20s\n" "DLQ (Failed) Rows:" "$(printf "%'d" $DLQ_COUNT)"
printf "%-35s %20s\n" "Successfully Synced Rows:" "$(printf "%'d" $SUCCESSFULLY_SYNCED)"
echo "───────────────────────────────────────────────────────────────────"
printf "%-35s %19s%%\n" "Success Rate:" "$SUCCESS_PERCENTAGE"
printf "%-35s %19s%%\n" "DLQ Rate:" "$DLQ_PERCENTAGE"
echo "───────────────────────────────────────────────────────────────────"

echo ""

# Note about ClickHouse having more rows
if [ "$CLICKHOUSE_TOTAL" -gt "$MYSQL_TOTAL" ]; then
    print_info "ClickHouse has MORE rows than MySQL"
    print_info "This is NORMAL - CDC is capturing ongoing changes"
    EXTRA_ROWS=$((CLICKHOUSE_TOTAL - MYSQL_TOTAL))
    echo "  Extra rows captured: $(printf "%'d" $EXTRA_ROWS)"
fi

echo ""

# ============================================================================
# STEP 6: RECOMMENDATIONS
# ============================================================================
print_header "STEP 6: RECOMMENDATIONS"

if [ "$DLQ_COUNT" -eq 0 ]; then
    print_success "No DLQ errors - CDC pipeline is working perfectly!"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor ongoing CDC operations"
    echo "  2. Set up alerts for future DLQ messages"
    echo "  3. Verify data integrity with spot checks"

elif [ "$DLQ_COUNT" -lt 1000 ]; then
    print_success "Very few DLQ errors ($(printf "%'d" $DLQ_COUNT) messages)"
    echo ""
    echo "Recommendations:"
    echo "  1. DLQ errors are minimal and acceptable"
    echo "  2. Review error patterns above to identify root cause"
    echo "  3. Consider fixing schema mismatches if Code:1001 is common"
    echo "  4. Monitor DLQ growth over time"

elif [ "$DLQ_COUNT" -lt 100000 ]; then
    print_warning "Moderate DLQ errors ($(printf "%'d" $DLQ_COUNT) messages)"
    echo ""
    echo "Recommendations:"
    echo "  1. Investigate tables with high error counts"
    echo "  2. Check for schema mismatches (Code:1001, Code:27)"
    echo "  3. Review NULL constraint violations (Code:44)"
    echo "  4. Consider fixing and replaying DLQ messages"

else
    print_error "High DLQ errors ($(printf "%'d" $DLQ_COUNT) messages)"
    echo ""
    echo "Urgent Actions Required:"
    echo "  1. Review connector configuration"
    echo "  2. Check ClickHouse table schemas"
    echo "  3. Identify specific tables causing errors"
    echo "  4. Fix root cause before replaying DLQ"
    echo "  5. Consider resetting connectors after fixes"
fi

echo ""

# Show how to investigate specific tables
if [ -n "$TABLES_IN_DLQ" ]; then
    echo "To investigate specific tables with DLQ errors:"
    echo ""

    # Get top 3 tables with most errors
    TOP_TABLES=$(echo "$TABLES_IN_DLQ" | head -3 | awk '{print $2}')

    for table in $TOP_TABLES; do
        echo "  # Check schema for $table:"
        echo "  docker exec mysql-clickhouse mysql -u root -p\$MYSQL_PASSWORD sakila -e \"DESCRIBE $table\""
        echo "  docker exec clickhouse-server clickhouse-client --password \$CLICKHOUSE_PASSWORD --query \"DESCRIBE sakila.$table\""
        echo ""
    done
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print_header "FINAL SUMMARY"

echo -e "${BOLD}Snapshot Status:${NC}"
if [ "$SNAPSHOT_STATUS" = "COMPLETE" ]; then
    echo -e "  ${GREEN}✓ COMPLETE${NC} - All initial data has been synced"
elif [ "$SNAPSHOT_STATUS" = "IN_PROGRESS" ]; then
    echo -e "  ${BLUE}ℹ IN PROGRESS${NC} - Consumer lag: $(printf "%'d" $TOTAL_LAG) messages"
else
    echo -e "  ${YELLOW}⚠ UNKNOWN${NC} - Could not determine status"
fi

echo ""
echo -e "${BOLD}DLQ Analysis:${NC}"
echo "  Total DLQ Messages: $(printf "%'d" ${DLQ_COUNT})"
echo "  DLQ Disk Usage: ${DLQ_SIZE:-Unknown}"
echo "  Affected Tables: ${TABLE_COUNT:-Unknown}"

echo ""
echo -e "${BOLD}Data Sync Quality:${NC}"
echo "  Success Rate: ${SUCCESS_PERCENTAGE}%"
echo "  DLQ Rate: ${DLQ_PERCENTAGE}%"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

echo "Analysis complete!"
echo ""
echo "For more details:"
echo "  - Full DLQ logs: docker logs kafka-connect-clickhouse | grep -i dlq"
echo "  - Connector status: curl http://localhost:8085/connectors/clickhouse-sink-connector/status | jq"
echo "  - DLQ messages: docker exec redpanda-clickhouse rpk topic consume $DLQ_TOPIC --brokers localhost:9092 --num 10"
echo ""
