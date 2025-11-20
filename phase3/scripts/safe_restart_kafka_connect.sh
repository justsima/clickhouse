#!/bin/bash
# Safe Kafka Connect Container Restart
# Purpose: Restart kafka-connect-clickhouse with proper dependency checks and verification

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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "Safe Kafka Connect Restart"

echo "Step 1: Pre-restart Dependency Checks"
echo "--------------------------------------"

# Check if Redpanda is running (critical dependency)
if ! docker ps | grep -q "redpanda-clickhouse"; then
    print_status 1 "Redpanda is NOT running"
    echo ""
    echo -e "${RED}ABORT: Kafka Connect requires Redpanda to be running${NC}"
    echo ""
    echo "Start Redpanda first:"
    echo "  docker start redpanda-clickhouse"
    echo "  # Wait for it to be healthy"
    echo "  docker exec redpanda-clickhouse rpk cluster info"
    echo ""
    echo "Then re-run this script."
    exit 1
else
    print_status 0 "Redpanda container is running"

    # Verify Redpanda is actually healthy
    if docker exec redpanda-clickhouse rpk cluster info &>/dev/null; then
        print_status 0 "Redpanda broker is responsive"
    else
        print_status 1 "Redpanda broker not responding"
        echo ""
        echo -e "${YELLOW}WARNING: Redpanda may not be fully initialized${NC}"
        echo "Waiting 10 seconds for Redpanda to become ready..."
        sleep 10

        if docker exec redpanda-clickhouse rpk cluster info &>/dev/null; then
            print_status 0 "Redpanda now responsive"
        else
            echo ""
            echo -e "${RED}ABORT: Redpanda still not responding${NC}"
            echo "Check Redpanda logs: docker logs redpanda-clickhouse --tail 50"
            exit 1
        fi
    fi
fi

# Check port 8083 availability
echo ""
if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
    echo -e "${YELLOW}⚠ Port 8083 is currently in use${NC}"
    echo "This could be:"
    echo "  1. Kafka Connect already running (OK)"
    echo "  2. Another process blocking the port (PROBLEM)"
    echo ""

    # Check if it's Kafka Connect using it
    if curl -s http://localhost:8083/ 2>/dev/null | grep -q "version"; then
        echo -e "${GREEN}✓ Port 8083 is Kafka Connect (already running)${NC}"
        echo ""
        echo "Container is already healthy. No restart needed."
        echo "Connector API is responding correctly."
        exit 0
    else
        echo -e "${RED}✗ Port 8083 in use by unknown process${NC}"
        echo ""
        echo "Find the process:"
        netstat -tulnp 2>/dev/null | grep ":8083 " || ss -tulnp 2>/dev/null | grep ":8083 " || echo "  Could not determine process"
        echo ""
        read -p "Force kill and proceed? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Restart cancelled."
            exit 0
        fi
    fi
else
    print_status 0 "Port 8083 is available"
fi

echo ""
print_section "Step 2: Stopping Kafka Connect"

CONTAINER_STATUS=$(docker ps -a --filter "name=kafka-connect-clickhouse" --format "{{.Status}}")

if echo "$CONTAINER_STATUS" | grep -q "Up"; then
    print_info "Stopping running container..."
    docker stop kafka-connect-clickhouse
    sleep 3
    print_status 0 "Container stopped"
else
    print_info "Container already stopped"
fi

print_section "Step 3: Starting Kafka Connect"

print_info "Starting kafka-connect-clickhouse container..."
START_OUTPUT=$(docker start kafka-connect-clickhouse 2>&1)

if [ $? -eq 0 ]; then
    print_status 0 "Container start command succeeded"
else
    print_status 1 "Container start command failed"
    echo "Error: $START_OUTPUT"
    exit 1
fi

echo ""
print_section "Step 4: Startup Verification"

print_info "Waiting for container to stay running (checking every 2s for 20s)..."

for i in {1..10}; do
    sleep 2

    if docker ps | grep -q "kafka-connect-clickhouse"; then
        echo -n "."
    else
        echo ""
        print_status 1 "Container stopped unexpectedly after $((i*2)) seconds"
        echo ""
        echo -e "${RED}Container crashed during startup!${NC}"
        echo ""
        echo "Last 30 lines of logs:"
        docker logs kafka-connect-clickhouse --tail 30
        echo ""
        echo -e "${YELLOW}The container is crashing. This indicates a configuration or dependency issue.${NC}"
        echo ""
        echo "Run the diagnostic script to identify the problem:"
        echo "  ./diagnose_kafka_connect_crash.sh"
        exit 1
    fi
done

echo ""
print_status 0 "Container has stayed running for 20 seconds"

echo ""
print_section "Step 5: API Responsiveness Check"

print_info "Waiting for Kafka Connect REST API to be ready..."

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
    print_status 0 "Kafka Connect API is responding"

    # Get version info
    VERSION_INFO=$(curl -s http://localhost:8083/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    echo "  Version: $VERSION_INFO"

    # Check connector plugins loaded
    PLUGIN_COUNT=$(curl -s http://localhost:8083/connector-plugins 2>/dev/null | grep -o '"class"' | wc -l)
    echo "  Connector plugins loaded: $PLUGIN_COUNT"

    if [ "$PLUGIN_COUNT" -gt 0 ]; then
        print_status 0 "Connector plugins are loaded"
    else
        echo -e "${YELLOW}⚠ Warning: No connector plugins loaded yet${NC}"
        echo "  They may still be initializing..."
    fi
else
    print_status 1 "Kafka Connect API not responding after 2 minutes"
    echo ""
    echo "Container is running but API is not ready."
    echo ""
    echo "Check logs for initialization errors:"
    echo "  docker logs kafka-connect-clickhouse --tail 50"
    exit 1
fi

print_section "Step 6: Health Summary"

echo "Container Status:"
docker ps --filter "name=kafka-connect-clickhouse" --format "  {{.Names}}: {{.Status}}"

echo ""
echo "API Endpoint:"
echo "  http://localhost:8083/"
echo "  $(curl -s http://localhost:8083/ 2>/dev/null | head -1 || echo 'Not responding')"

echo ""
print_section "Restart Complete!"

echo -e "${GREEN}✓ Kafka Connect successfully restarted and verified${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy connectors: ./03_deploy_connectors.sh"
echo "  2. Monitor progress: ./04_monitor_snapshot.sh"
echo ""
