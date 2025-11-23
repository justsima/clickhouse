#!/bin/bash
# Comprehensive DLQ Diagnostics and Fix Script
# This will identify WHY data is going to DLQ and provide fixes

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header "DLQ DIAGNOSTICS & STORAGE ANALYSIS"

# ============================================
# PART 1: CHECK CONNECTOR STATUS
# ============================================
print_header "1. Connector Status Check"

CONNECT_URL="http://localhost:8085"

echo "Checking ClickHouse Sink Connector..."
SINK_STATUS=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector/status" 2>/dev/null || echo '{"error":"not found"}')

if echo "$SINK_STATUS" | grep -q '"state":"RUNNING"'; then
    print_status 0 "Connector is RUNNING"
elif echo "$SINK_STATUS" | grep -q '"state":"FAILED"'; then
    print_status 1 "Connector is FAILED"
    echo "$SINK_STATUS" | python3 -m json.tool 2>/dev/null || echo "$SINK_STATUS"
else
    print_warning "Connector status unclear"
fi

# Check for task failures
FAILED_TASKS=$(echo "$SINK_STATUS" | grep -c '"state":"FAILED"' || echo 0)
if [ "$FAILED_TASKS" -gt 0 ]; then
    print_warning "$FAILED_TASKS task(s) have FAILED"
    echo ""
    echo "Task errors:"
    echo "$SINK_STATUS" | python3 -c "
import sys, json
try:
    status = json.load(sys.stdin)
    for i, task in enumerate(status.get('tasks', [])):
        if task.get('state') == 'FAILED':
            print(f\"  Task {i}: {task.get('trace', 'No trace available')[:200]}...\")
except: pass
" 2>/dev/null || echo "  Could not parse task errors"
fi

# ============================================
# PART 2: KAFKA/REDPANDA STORAGE ANALYSIS
# ============================================
print_header "2. Kafka/Redpanda Storage Analysis"

echo "Checking Redpanda topics and sizes..."
echo ""

# Get topic list and info
docker exec redpanda-clickhouse rpk topic list 2>/dev/null | while read -r line; do
    echo "  $line"
done

echo ""
echo "Detailed DLQ topic information:"
DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq 2>/dev/null || echo "DLQ topic not found")
echo "$DLQ_INFO"

echo ""
echo "DLQ message count estimate:"
docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq --num 1 --offset start 2>/dev/null | head -5 || echo "  Could not read DLQ"

# ============================================
# PART 3: SAMPLE DLQ MESSAGES
# ============================================
print_header "3. Analyzing DLQ Messages (First 5 Errors)"

echo "Fetching sample DLQ messages to identify failure patterns..."
echo ""

docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq --num 5 --format json 2>/dev/null | \
python3 -c "
import sys, json

print('Sample DLQ Errors:')
print('-' * 80)

for i, line in enumerate(sys.stdin, 1):
    try:
        msg = json.loads(line)
        value = msg.get('value', {})

        # Try to parse value if it's a string
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except: pass

        # Look for error information in headers or value
        headers = msg.get('headers', {})

        print(f'\\nError #{i}:')
        print(f'  Topic: {msg.get(\"topic\", \"unknown\")}')
        print(f'  Partition: {msg.get(\"partition\", \"?\")}')

        # Check headers for error info
        if '__connect.errors.topic' in headers:
            print(f'  Original Topic: {headers[\"__connect.errors.topic\"]}')
        if '__connect.errors.exception.message' in headers:
            print(f'  Error: {headers[\"__connect.errors.exception.message\"][:200]}')
        if '__connect.errors.exception.class.name' in headers:
            print(f'  Exception: {headers[\"__connect.errors.exception.class.name\"]}')

        # Show snippet of data
        print(f'  Data sample: {str(value)[:150]}...')

        if i >= 5:
            break

    except Exception as e:
        print(f'  Could not parse message {i}: {e}')
        continue

print()
print('-' * 80)
" 2>/dev/null || echo "  Could not parse DLQ messages"

# ============================================
# PART 4: STORAGE BREAKDOWN
# ============================================
print_header "4. Docker Storage Breakdown"

echo "Docker volumes storage usage:"
docker system df -v | grep -A 20 "Local Volumes" || docker system df

echo ""
echo "Redpanda data volume size:"
docker exec redpanda-clickhouse du -sh /var/lib/redpanda/data 2>/dev/null || echo "  Could not check"

echo ""
echo "ClickHouse data volume size:"
docker exec clickhouse-server du -sh /var/lib/clickhouse 2>/dev/null || echo "  Could not check"

# ============================================
# PART 5: IDENTIFY ROOT CAUSES
# ============================================
print_header "5. Common Root Causes Analysis"

echo "Checking for common DLQ issues:"
echo ""

# Check 1: Schema mismatches
print_info "Checking for schema/type mismatches..."
CONNECTOR_CONFIG=$(curl -s "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null)

SCHEMA_EVOLUTION=$(echo "$CONNECTOR_CONFIG" | grep -o '"schema.evolution":"[^"]*"' | cut -d'"' -f4)
if [ "$SCHEMA_EVOLUTION" = "none" ]; then
    print_warning "Schema evolution is DISABLED - any schema changes will cause DLQ errors!"
    echo "  Solution: Enable schema.evolution or ensure schemas match exactly"
fi

# Check 2: Error tolerance
ERROR_TOLERANCE=$(echo "$CONNECTOR_CONFIG" | grep -o '"errors.tolerance":"[^"]*"' | cut -d'"' -f4)
if [ "$ERROR_TOLERANCE" = "all" ]; then
    print_warning "Error tolerance is set to 'all' - ALL errors go to DLQ silently!"
    echo "  Solution: Change to 'none' to see real errors, or fix issues causing DLQ"
fi

# Check 3: Primary key issues
PRIMARY_KEY_MODE=$(echo "$CONNECTOR_CONFIG" | grep -o '"primary.key.mode":"[^"]*"' | cut -d'"' -f4)
echo ""
print_info "Primary key mode: $PRIMARY_KEY_MODE"
if [ "$PRIMARY_KEY_MODE" = "record_key" ]; then
    print_warning "Using record_key mode - requires proper keys from Debezium!"
    echo "  Issue: If keys are missing/null, inserts may fail"
fi

# ============================================
# PART 6: RECOMMENDATIONS
# ============================================
print_header "6. Recommended Actions"

echo "Based on the analysis above, here are recommended fixes:"
echo ""

echo "IMMEDIATE ACTIONS:"
echo "  1. Check DLQ sample messages above to identify specific errors"
echo "  2. Common issues and fixes:"
echo ""
echo "     Issue: Data type mismatches"
echo "     Fix: Review ClickHouse table schemas vs. MySQL source schemas"
echo ""
echo "     Issue: Primary key problems"
echo "     Fix: Ensure Debezium is sending proper keys, or use primary.key.mode=record_value"
echo ""
echo "     Issue: Table doesn't exist"
echo "     Fix: Ensure ClickHouse tables are created before data arrives"
echo ""
echo "     Issue: Transform errors"
echo "     Fix: Check RegexRouter transform pattern matches your topic names"
echo ""

echo "STORAGE CLEANUP:"
echo "  1. Delete DLQ topic (after fixing issues):"
echo "     docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq"
echo ""
echo "  2. Reset consumer offsets to reprocess failed messages:"
echo "     (Only after fixing the root cause!)"
echo ""

echo "CONFIGURATION CHANGES:"
echo "  1. Temporarily disable error tolerance to see real errors:"
echo "     Change: \"errors.tolerance\": \"none\""
echo "     This will make connector fail fast and show you the real issue"
echo ""
echo "  2. Enable schema evolution if schemas might change:"
echo "     Change: \"schema.evolution\": \"basic\""
echo ""

print_header "7. Next Steps"

echo "What would you like to do?"
echo ""
echo "Option A: Fix and restart (recommended if you've identified the issue)"
echo "  ./fix_and_restart_pipeline.sh"
echo ""
echo "Option B: Clean slate - delete DLQ and restart"
echo "  ./cleanup_dlq_and_restart.sh"
echo ""
echo "Option C: Change to simpler architecture (no CDC, direct sync)"
echo "  Consider alternative approaches if CDC is too complex"
echo ""

print_info "Save this diagnostic output for reference!"
