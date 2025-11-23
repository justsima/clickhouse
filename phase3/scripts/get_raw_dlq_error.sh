#!/bin/bash
# Get Raw DLQ Error - No parsing, just raw output

echo "Getting RAW DLQ message (first one)..."
echo "═══════════════════════════════════════════════════════════"
echo ""

docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
    --brokers localhost:9092 \
    --num 1 \
    --offset start 2>/dev/null | python3 -m json.tool

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "If headers are present, look for keys starting with:"
echo "  __connect.errors.exception.message"
echo "  __connect.errors.exception.class.name"
echo ""
