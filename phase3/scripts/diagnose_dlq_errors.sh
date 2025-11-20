#!/bin/bash
# Diagnose DLQ Errors - Find Root Cause
# Purpose: Identify why records are going to DLQ despite RegexRouter working

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  DLQ Root Cause Analysis                                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

echo "═══════════════════════════════════════════════════════════"
echo "STEP 1: Check DLQ Message Count"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Get DLQ partition info
DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep "clickhouse-dlq" || echo "")

if [ -z "$DLQ_INFO" ]; then
    echo "✓ DLQ topic does not exist (no errors)"
    exit 0
fi

echo "DLQ topic exists. Getting message count..."
docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>/dev/null | grep -E "PARTITION|high water"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 2: Sample DLQ Messages (First 5)"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Reading DLQ messages to find error pattern..."
docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
    --brokers localhost:9092 \
    --num 5 \
    --offset start 2>/dev/null | python3 << 'PYTHON_SCRIPT'
import sys
import json

errors = {}
topics = {}

for line in sys.stdin:
    try:
        msg = json.loads(line)
        headers = {h['key']: h['value'] for h in msg.get('headers', [])}

        # Extract error info
        topic = headers.get('__connect.errors.topic', 'unknown')
        error_class = headers.get('__connect.errors.exception.class.name', 'unknown')
        error_msg = headers.get('__connect.errors.exception.message', 'unknown')

        # Count errors by type
        if error_class not in errors:
            errors[error_class] = {'count': 0, 'topics': set(), 'sample_msg': error_msg}
        errors[error_class]['count'] += 1
        errors[error_class]['topics'].add(topic)

        # Count by topic
        if topic not in topics:
            topics[topic] = 0
        topics[topic] += 1

    except Exception as e:
        continue

print("\n" + "="*60)
print("ERROR SUMMARY")
print("="*60)

if errors:
    for error_class, info in errors.items():
        print(f"\nError Type: {error_class}")
        print(f"  Count: {info['count']}")
        print(f"  Affected Topics: {', '.join(list(info['topics'])[:3])}")
        print(f"  Sample Message: {info['sample_msg'][:200]}")
else:
    print("No error information found in DLQ headers")

print("\n" + "="*60)
print("TOPICS AFFECTED")
print("="*60)
for topic, count in sorted(topics.items(), key=lambda x: x[1], reverse=True):
    table_name = topic.replace('mysql.mulazamflatoddbet.', '')
    print(f"  {table_name}: {count} errors")

PYTHON_SCRIPT

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 3: Check ClickHouse Tables for Problematic Table"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if flatodd_betgroup table has data
echo "Checking flatodd_betgroup table..."
BETGROUP_COUNT=$(docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT count() FROM analytics.flatodd_betgroup" 2>/dev/null || echo "0")

echo "  Table: flatodd_betgroup"
echo "  Rows:  $BETGROUP_COUNT"

if [ "$BETGROUP_COUNT" -gt 0 ]; then
    echo "  Status: ✓ Table receiving SOME data (errors are partial)"
else
    echo "  Status: ✗ Table receiving NO data (all records going to DLQ)"
fi

echo ""
echo "Checking table structure..."
docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "DESCRIBE TABLE analytics.flatodd_betgroup FORMAT Pretty" 2>/dev/null | head -30

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 4: Check Kafka Connect Logs for Detailed Error"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Searching Kafka Connect logs for ClickHouse errors..."
docker logs kafka-connect-clickhouse --tail 500 2>&1 | \
    grep -i "clickhouse\|sql\|insert" | \
    grep -i "error\|exception\|failed" | \
    grep -v "log4j:ERROR\|errors.tolerance" | \
    tail -20

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 5: Current Pipeline Status"
echo "═══════════════════════════════════════════════════════════"
echo ""

TABLES_WITH_DATA=$(docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT count() FROM system.tables WHERE database = 'analytics' AND total_rows > 0" 2>/dev/null)

TOTAL_ROWS=$(docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT sum(total_rows) FROM system.tables WHERE database = 'analytics'" 2>/dev/null)

TOTAL_TOPICS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "mysql\\." || echo "0")

CONSUMER_LAG=$(docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092 2>/dev/null | grep "TOTAL-LAG" | awk '{print $2}')

echo "Current Status:"
echo "  MySQL Topics:        $TOTAL_TOPICS"
echo "  Tables with Data:    $TABLES_WITH_DATA"
echo "  Total Rows:          $TOTAL_ROWS"
echo "  Consumer Lag:        $CONSUMER_LAG"
echo ""

if [ "$TABLES_WITH_DATA" -gt 0 ]; then
    echo "✓ Pipeline IS working for $TABLES_WITH_DATA tables"
    echo "✗ But SOME records going to DLQ (see error summary above)"
else
    echo "✗ Pipeline NOT working - all data going to DLQ"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "RECOMMENDATIONS"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Based on the error analysis above:"
echo ""
echo "1. Check error type from STEP 2"
echo "   - Schema mismatch: ClickHouse table schema doesn't match data"
echo "   - Data type error: Type conversion failing"
echo "   - Null constraint: Required field is null"
echo ""
echo "2. Common fixes:"
echo "   - Add 'ignoreUnknownColumns': 'true' (already set)"
echo "   - Change ClickHouse column types to Nullable()"
echo "   - Adjust decimal/bigint handling in MySQL connector"
echo ""
echo "3. To see full error details, run:"
echo "   docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \\"
echo "     --brokers localhost:9092 --num 1 | python3 -m json.tool"
echo ""
echo "═══════════════════════════════════════════════════════════"
