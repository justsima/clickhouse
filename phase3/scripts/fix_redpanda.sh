#!/bin/bash
# Fix Redpanda Container

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  REDPANDA FIX SCRIPT                                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check Redpanda status
echo "Checking Redpanda container status..."
REDPANDA_STATUS=$(docker ps -a | grep redpanda-clickhouse)

if [ -z "$REDPANDA_STATUS" ]; then
    echo -e "${RED}✗${NC} Redpanda container not found"
    echo ""
    echo "Container may have been removed. List all containers:"
    docker ps -a
    exit 1
fi

echo "$REDPANDA_STATUS"
echo ""

# Check if running
if echo "$REDPANDA_STATUS" | grep -q "Up"; then
    echo -e "${BLUE}ℹ${NC} Redpanda is running"

    # Check if healthy
    if echo "$REDPANDA_STATUS" | grep -q "healthy"; then
        echo -e "${GREEN}✓${NC} Redpanda is healthy!"
        echo ""
        echo "Testing connection..."
        docker exec redpanda-clickhouse rpk cluster health --brokers localhost:9092
        exit 0
    else
        echo -e "${YELLOW}⚠${NC} Redpanda is starting (not healthy yet)"
        echo ""
        echo "Waiting for health check..."
        sleep 10

        HEALTH=$(docker ps | grep redpanda-clickhouse | grep -o "healthy\|unhealthy\|starting")
        echo "Status: $HEALTH"

        if [ "$HEALTH" = "healthy" ]; then
            echo -e "${GREEN}✓${NC} Redpanda is now healthy!"
            exit 0
        fi
    fi
else
    echo -e "${RED}✗${NC} Redpanda is NOT running"

    # Check exit code
    EXIT_CODE=$(echo "$REDPANDA_STATUS" | grep -oP "Exited \(\K\d+")
    if [ -n "$EXIT_CODE" ]; then
        echo "  Exit code: $EXIT_CODE"

        case $EXIT_CODE in
            132) echo "  Reason: Killed/Crashed (SIGILL)" ;;
            137) echo "  Reason: Killed (OOM or SIGKILL)" ;;
            1) echo "  Reason: Application error" ;;
            *) echo "  Reason: Unknown" ;;
        esac
    fi
    echo ""
fi

# Check logs for errors
echo "═══════════════════════════════════════════════════════════"
echo "Recent Redpanda Logs (last 20 lines):"
echo "═══════════════════════════════════════════════════════════"
docker logs redpanda-clickhouse --tail 20 2>&1
echo ""

# Try to restart
echo "═══════════════════════════════════════════════════════════"
echo "Attempting to restart Redpanda..."
echo "═══════════════════════════════════════════════════════════"
echo ""

docker start redpanda-clickhouse

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Redpanda start command successful"
    echo ""
    echo "Waiting for Redpanda to become healthy (30 seconds)..."

    for i in {1..30}; do
        sleep 1
        STATUS=$(docker ps | grep redpanda-clickhouse | grep -o "healthy\|unhealthy\|starting" | head -1)

        if [ "$STATUS" = "healthy" ]; then
            echo ""
            echo -e "${GREEN}✓${NC} Redpanda is now HEALTHY!"
            echo ""

            # Test connection
            echo "Testing Redpanda connection..."
            docker exec redpanda-clickhouse rpk cluster health --brokers localhost:9092

            if [ $? -eq 0 ]; then
                echo ""
                echo -e "${GREEN}✓${NC} Redpanda is working correctly!"
                echo ""
                echo "You can now run your DLQ analysis scripts:"
                echo "  ./snapshot_status.sh"
                echo "  ./deep_dlq_analysis.sh"
                exit 0
            fi
        fi

        printf "\r  Status: %s (waiting %d/30s)" "$STATUS" "$i"
    done

    echo ""
    echo ""
    echo -e "${YELLOW}⚠${NC} Redpanda started but not healthy yet"
    echo ""
    echo "Check status with:"
    echo "  docker ps | grep redpanda"
    echo "  docker logs redpanda-clickhouse --tail 50"
else
    echo -e "${RED}✗${NC} Failed to start Redpanda"
    echo ""
    echo "Try manual restart:"
    echo "  docker stop redpanda-clickhouse"
    echo "  docker start redpanda-clickhouse"
    echo ""
    echo "Or check for port conflicts:"
    echo "  netstat -tuln | grep -E '9092|8081|8082'"
fi

echo ""
echo "If issues persist, check:"
echo "  1. Docker logs: docker logs redpanda-clickhouse"
echo "  2. Container inspect: docker inspect redpanda-clickhouse"
echo "  3. Available memory: free -h"
echo "  4. Port conflicts: netstat -tuln | grep 9092"
echo ""
