#!/bin/bash
# Quick Snapshot Status Check
# Fast check to see if snapshot is complete

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  SNAPSHOT STATUS CHECK                                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check consumer lag
CONSUMER_GROUP="connect-clickhouse-sink-connector"

echo "Checking consumer lag..."
LAG_OUTPUT=$(docker exec redpanda-clickhouse rpk group describe "$CONSUMER_GROUP" --brokers localhost:9092 2>&1)

if echo "$LAG_OUTPUT" | grep -q "not running\|error\|cannot"; then
    echo -e "${RED}✗${NC} Cannot connect to Redpanda"
    echo ""
    echo "Is Redpanda running?"
    docker ps | grep redpanda
    exit 1
fi

# Parse total lag
TOTAL_LAG=$(echo "$LAG_OUTPUT" | grep "TOTAL-LAG" | awk '{print $2}' | tr -d ',')

# Alternative parsing
if [ -z "$TOTAL_LAG" ] || ! [[ "$TOTAL_LAG" =~ ^[0-9]+$ ]]; then
    TOTAL_LAG=$(echo "$LAG_OUTPUT" | awk '/LAG/{sum+=$NF}END{print sum}')
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

if [ -z "$TOTAL_LAG" ] || ! [[ "$TOTAL_LAG" =~ ^[0-9]+$ ]]; then
    echo -e "${YELLOW}⚠ Could not determine consumer lag${NC}"
    echo ""
    echo "Full output:"
    echo "$LAG_OUTPUT"
elif [ "$TOTAL_LAG" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ SNAPSHOT IS COMPLETE!${NC}"
    echo ""
    echo "Consumer lag: 0 messages"
    echo ""
    echo -e "${GREEN}All messages have been consumed and synced to ClickHouse.${NC}"
else
    echo -e "${BLUE}ℹ SNAPSHOT IN PROGRESS${NC}"
    echo ""
    echo "Consumer lag: $(printf "%'d" $TOTAL_LAG) messages remaining"
    echo ""

    # Calculate ETA
    if [ "$TOTAL_LAG" -gt 0 ]; then
        # Assume ~1000-5000 msgs/sec depending on data size
        # Use conservative 1000 msgs/sec
        ETA_SECONDS=$((TOTAL_LAG / 1000))

        if [ "$ETA_SECONDS" -lt 60 ]; then
            echo "Estimated time remaining: ~${ETA_SECONDS} seconds"
        elif [ "$ETA_SECONDS" -lt 3600 ]; then
            ETA_MINUTES=$((ETA_SECONDS / 60))
            echo "Estimated time remaining: ~${ETA_MINUTES} minutes"
        else
            ETA_HOURS=$((ETA_SECONDS / 3600))
            echo "Estimated time remaining: ~${ETA_HOURS} hours"
        fi
    fi

    echo ""
    echo "Wait for lag to reach 0, then snapshot is complete."
fi

echo "═══════════════════════════════════════════════════════════"
echo ""

# Show lag per partition
echo "Consumer Lag Details:"
echo "───────────────────────────────────────────────────────────"
echo "$LAG_OUTPUT" | grep -E "PARTITION|TOPIC" | head -15

echo ""
echo "To run full DLQ analysis:"
echo "  ./deep_dlq_analysis.sh"
echo ""
