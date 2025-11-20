#!/bin/bash
# Investigate DLQ Root Cause - Check Schema Mismatch
# Purpose: Verify if DLQ errors are due to existing table schema mismatch

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  DLQ Root Cause Investigation - Schema Mismatch?         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo "STEP 1: Extract ACTUAL error from DLQ headers"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Get DLQ message with full headers
docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
    --brokers localhost:9092 \
    --num 1 \
    --offset start 2>/dev/null | python3 << 'PYTHON_END'
import sys, json

for line in sys.stdin:
    try:
        msg = json.loads(line)
        headers = {h['key']: h['value'] for h in msg.get('headers', [])}

        print("="*60)
        print("DLQ MESSAGE HEADERS")
        print("="*60)

        # Extract key headers
        topic = headers.get('__connect.errors.topic', 'unknown')
        table = topic.replace('mysql.mulazamflatoddbet.', '')

        print(f"\nAffected Topic: {topic}")
        print(f"Table Name: {table}")
        print(f"\nError Class: {headers.get('__connect.errors.exception.class.name', 'NOT FOUND')}")
        print(f"\nError Message:")
        print("-" * 60)
        error_msg = headers.get('__connect.errors.exception.message', 'NOT FOUND')
        print(error_msg)
        print("-" * 60)

        # Check for specific error patterns
        print(f"\nError Analysis:")
        if 'Code: 16' in error_msg or 'TOO_MANY_COLUMNS' in error_msg:
            print("  Type: Column count mismatch")
            print("  Cause: ClickHouse table has different number of columns than data")
        elif 'Code: 47' in error_msg or 'UNKNOWN_IDENTIFIER' in error_msg:
            print("  Type: Unknown column")
            print("  Cause: Data has columns that don't exist in ClickHouse table")
        elif 'Code: 53' in error_msg or 'TYPE_MISMATCH' in error_msg:
            print("  Type: Data type mismatch")
            print("  Cause: Column types don't match between data and table")
        elif 'does not exist' in error_msg.lower():
            print("  Type: Table not found")
            print("  Cause: RegexRouter not working OR table wasn't created")
        elif 'nullable' in error_msg.lower() or 'null' in error_msg.lower():
            print("  Type: Null constraint violation")
            print("  Cause: Non-nullable column received null value")
        else:
            print("  Type: Unknown - see error message above")

        # Save table name for next step
        with open('/tmp/dlq_table_name.txt', 'w') as f:
            f.write(table)

        break
    except Exception as e:
        print(f"Error parsing: {e}")
        continue
PYTHON_END

echo ""
echo "STEP 2: Check ClickHouse table schema"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -f /tmp/dlq_table_name.txt ]; then
    TABLE_NAME=$(cat /tmp/dlq_table_name.txt)

    echo "Table: $TABLE_NAME"
    echo ""

    # Check if table exists
    TABLE_EXISTS=$(docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "SELECT count() FROM system.tables WHERE database = 'analytics' AND name = '$TABLE_NAME'" 2>/dev/null)

    if [ "$TABLE_EXISTS" -eq 1 ]; then
        echo "✓ Table exists in ClickHouse"
        echo ""
        echo "Table Schema:"
        docker exec clickhouse-server clickhouse-client \
            --password "$CLICKHOUSE_PASSWORD" \
            --query "DESCRIBE TABLE analytics.$TABLE_NAME FORMAT Pretty" 2>/dev/null

        echo ""
        echo "Row Count:"
        ROW_COUNT=$(docker exec clickhouse-server clickhouse-client \
            --password "$CLICKHOUSE_PASSWORD" \
            --query "SELECT count() FROM analytics.$TABLE_NAME" 2>/dev/null)
        echo "  $ROW_COUNT rows"

        if [ "$ROW_COUNT" -gt 0 ]; then
            echo "  ✓ Table HAS data (so SOME records succeed, SOME fail)"
            echo "  → This means: Schema is mostly compatible but some fields cause errors"
        else
            echo "  ✗ Table has NO data (ALL records for this table going to DLQ)"
            echo "  → This means: Complete schema mismatch OR table mapping issue"
        fi
    else
        echo "✗ Table does NOT exist in ClickHouse!"
        echo "  → This is the problem: RegexRouter working but table not created"
    fi
else
    echo "Could not extract table name from DLQ message"
    TABLE_NAME="flatodd_betgroup"
    echo "Using fallback: $TABLE_NAME"
fi

echo ""
echo "STEP 3: Check Kafka topic data sample"
echo "═══════════════════════════════════════════════════════════"
echo ""

TOPIC="mysql.${MYSQL_DATABASE}.${TABLE_NAME}"
echo "Topic: $TOPIC"
echo ""

# Check if topic exists
TOPIC_EXISTS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "$TOPIC" || echo "0")

if [ "$TOPIC_EXISTS" -gt 0 ]; then
    echo "✓ Topic exists"
    echo ""
    echo "Sample record (first message):"
    docker exec redpanda-clickhouse rpk topic consume "$TOPIC" \
        --brokers localhost:9092 \
        --num 1 \
        --offset start 2>/dev/null | python3 << 'PYTHON_END'
import sys, json

for line in sys.stdin:
    try:
        msg = json.loads(line)
        value = json.loads(msg.get('value', '{}'))

        print("Data fields in Kafka:")
        print("-" * 60)
        for key in sorted(value.keys()):
            val = value[key]
            val_type = type(val).__name__
            val_str = str(val)[:50] if val is not None else 'null'
            print(f"  {key:30s} {val_type:10s} {val_str}")
        print("-" * 60)

        break
    except Exception as e:
        print(f"Error: {e}")
PYTHON_END
else
    echo "✗ Topic does not exist"
fi

echo ""
echo "STEP 4: Compare schemas"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ "$TABLE_EXISTS" -eq 1 ] && [ "$TOPIC_EXISTS" -gt 0 ]; then
    echo "Getting ClickHouse columns..."
    CH_COLUMNS=$(docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "SELECT name FROM system.columns WHERE database = 'analytics' AND table = '$TABLE_NAME' ORDER BY name" 2>/dev/null)

    echo "Getting Kafka data columns..."
    KAFKA_COLUMNS=$(docker exec redpanda-clickhouse rpk topic consume "$TOPIC" \
        --brokers localhost:9092 \
        --num 1 \
        --offset start 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        msg = json.loads(line)
        value = json.loads(msg.get('value', '{}'))
        for key in sorted(value.keys()):
            print(key)
        break
    except: pass
" 2>/dev/null)

    echo ""
    echo "Column Comparison:"
    echo ""

    # Find columns in Kafka but not in ClickHouse
    echo "Columns in KAFKA DATA but NOT in CLICKHOUSE TABLE:"
    comm -13 <(echo "$CH_COLUMNS" | sort) <(echo "$KAFKA_COLUMNS" | sort) | while read col; do
        if [ -n "$col" ]; then
            echo "  - $col (extra column in data)"
        fi
    done

    echo ""
    echo "Columns in CLICKHOUSE TABLE but NOT in KAFKA DATA:"
    comm -23 <(echo "$CH_COLUMNS" | sort) <(echo "$KAFKA_COLUMNS" | sort) | while read col; do
        if [ -n "$col" ]; then
            echo "  - $col (missing in data)"
        fi
    done
fi

echo ""
echo "STEP 5: Check connector configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "ClickHouse sink connector settings:"
curl -s http://localhost:8085/connectors/clickhouse-sink-connector | python3 -m json.tool | grep -A 1 -E "ignoreUnknownColumns|tableMapping|transforms"

echo ""
echo ""
echo "CONCLUSION"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Based on the investigation above:"
echo ""
echo "1. Check the ERROR MESSAGE in STEP 1 for exact cause"
echo "2. Check ROW COUNT in STEP 2:"
echo "   - If > 0: Partial schema mismatch (some fields fail)"
echo "   - If = 0: Complete mismatch or table mapping issue"
echo "3. Check COLUMN COMPARISON in STEP 4 for schema differences"
echo ""
echo "Common fixes:"
echo "  - If 'ignoreUnknownColumns' is false, set to true"
echo "  - If columns missing, add them to ClickHouse table"
echo "  - If type mismatch, adjust ClickHouse column types"
echo "  - If Debezium metadata fields (__op, __deleted), exclude them"
echo ""
