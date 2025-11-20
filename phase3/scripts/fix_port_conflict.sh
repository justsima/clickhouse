#!/bin/bash
# Fix Port 8083 Conflict Between Old and New Kafka Connect
# Issue: Old kafka-connect container is blocking port 8083 needed by kafka-connect-clickhouse

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "Port 8083 Conflict Resolution"

echo "PROBLEM IDENTIFIED:"
echo "  Old 'kafka-connect' container is using port 8083"
echo "  New 'kafka-connect-clickhouse' needs port 8083"
echo "  Result: kafka-connect-clickhouse crashes on startup"
echo ""

print_section "Step 1: Verify Port Conflict"

echo "Checking which containers are using port 8083..."
echo ""

# Check old kafka-connect
if docker ps | grep -q "kafka-connect" | grep -v "kafka-connect-clickhouse"; then
    echo -e "${RED}✗ Old 'kafka-connect' container IS RUNNING on port 8083${NC}"
    OLD_CONTAINER_RUNNING=true
else
    echo -e "${GREEN}✓ Old 'kafka-connect' container not running${NC}"
    OLD_CONTAINER_RUNNING=false
fi

# Check if port is actually in use
if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
    echo -e "${YELLOW}⚠ Port 8083 is currently in use${NC}"
    netstat -tulnp 2>/dev/null | grep ":8083 " || ss -tulnp 2>/dev/null | grep ":8083 "
    PORT_IN_USE=true
else
    echo -e "${GREEN}✓ Port 8083 is available${NC}"
    PORT_IN_USE=false
fi

echo ""

if [ "$OLD_CONTAINER_RUNNING" = false ] && [ "$PORT_IN_USE" = false ]; then
    echo -e "${GREEN}✓ No port conflict detected. kafka-connect-clickhouse should start successfully.${NC}"
    exit 0
fi

print_section "Step 2: Check Old Environment Usage"

echo "You have TWO separate Kafka/Connect environments:"
echo ""
echo "1. OLD ENVIRONMENT (4 weeks old):"
docker ps --filter "name=kafka-connect" --filter "name=kafka" --filter "name=postgres-sink" --format "   - {{.Names}}: {{.Status}} (port {{.Ports}})" | grep -v "clickhouse"
echo ""
echo "2. NEW ENVIRONMENT (for ClickHouse CDC):"
docker ps -a --filter "name=redpanda-clickhouse" --filter "name=kafka-connect-clickhouse" --format "   - {{.Names}}: {{.Status}} (port {{.Ports}})"
echo ""

echo -e "${YELLOW}Question: Do you still need the OLD environment?${NC}"
echo ""
read -p "Stop the old 'kafka-connect' container to free port 8083? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Cancelled. Port conflict not resolved."
    echo ""
    echo "Alternative solutions:"
    echo "  1. Manually stop old container: docker stop kafka-connect"
    echo "  2. Change kafka-connect-clickhouse to use different port (requires docker-compose changes)"
    echo ""
    exit 0
fi

print_section "Step 3: Stop Old kafka-connect Container"

echo "Stopping old 'kafka-connect' container..."
docker stop kafka-connect

if [ $? -eq 0 ]; then
    print_status 0 "Old kafka-connect container stopped"
else
    print_status 1 "Failed to stop old kafka-connect container"
    exit 1
fi

# Wait for port to be released
sleep 3

# Verify port is now free
if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
    echo -e "${YELLOW}⚠ Port 8083 still in use (may take a moment to release)${NC}"
    sleep 5

    if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
        print_status 1 "Port 8083 still not released"
        echo ""
        echo "Check what's using it:"
        netstat -tulnp 2>/dev/null | grep ":8083 " || ss -tulnp 2>/dev/null | grep ":8083 "
        exit 1
    fi
fi

print_status 0 "Port 8083 is now available"

print_section "Step 4: Start kafka-connect-clickhouse"

echo "Starting kafka-connect-clickhouse container..."
docker start kafka-connect-clickhouse

if [ $? -eq 0 ]; then
    print_status 0 "Container start command succeeded"
else
    print_status 1 "Container start command failed"
    exit 1
fi

# Wait and verify it stays running
echo ""
echo "Waiting 20 seconds to verify container stays running..."

for i in {1..10}; do
    sleep 2
    if docker ps | grep -q "kafka-connect-clickhouse"; then
        echo -n "."
    else
        echo ""
        print_status 1 "Container crashed again after $((i*2)) seconds"
        echo ""
        echo "Check logs: docker logs kafka-connect-clickhouse --tail 50"
        exit 1
    fi
done

echo ""
print_status 0 "Container has stayed running for 20 seconds"

print_section "Step 5: Verify API Responsiveness"

echo "Checking if Kafka Connect REST API is responding..."

API_READY=false
for attempt in {1..24}; do
    if curl -s http://localhost:8083/ 2>/dev/null | grep -q "version"; then
        API_READY=true
        break
    fi
    echo -n "."
    sleep 5
done

echo ""

if [ "$API_READY" = true ]; then
    print_status 0 "Kafka Connect API is responding on port 8083"

    VERSION=$(curl -s http://localhost:8083/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    echo "  Version: $VERSION"

    PLUGINS=$(curl -s http://localhost:8083/connector-plugins 2>/dev/null | grep -o '"class"' | wc -l)
    echo "  Plugins loaded: $PLUGINS"
else
    print_status 1 "API not responding after 2 minutes"
    echo ""
    echo "Container is running but API not ready. Check logs:"
    echo "  docker logs kafka-connect-clickhouse --tail 50"
    exit 1
fi

print_section "SUCCESS!"

echo -e "${GREEN}✓ Port conflict resolved${NC}"
echo -e "${GREEN}✓ kafka-connect-clickhouse is running and healthy${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy connectors: ./03_deploy_connectors.sh"
echo "  2. Monitor progress: ./04_monitor_snapshot.sh"
echo ""
echo "NOTE: If you need the old kafka-connect container again:"
echo "  docker start kafka-connect"
echo "  (But you'll need to stop kafka-connect-clickhouse first)"
echo ""
