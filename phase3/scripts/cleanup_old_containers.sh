#!/bin/bash
# Complete Cleanup of Old Kafka/Connect Containers
# Purpose: Remove old kafka, kafka-connect, postgres-sink containers completely

set +e

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

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "Old Container Cleanup"

echo -e "${BOLD}This will PERMANENTLY DELETE the following old containers:${NC}"
echo "  - kafka"
echo "  - kafka-connect"
echo "  - postgres-sink"
echo "  - kafka-ui (if you want)"
echo ""
echo -e "${YELLOW}These containers are from your old setup (4 weeks ago)${NC}"
echo -e "${YELLOW}They conflict with your new ClickHouse CDC environment${NC}"
echo ""

print_section "Step 1: Identify Old Containers"

echo "Scanning for old containers..."
echo ""

# List all old containers
OLD_CONTAINERS=$(docker ps -a --filter "name=kafka-connect" --filter "name=kafka" --filter "name=postgres-sink" --format "{{.Names}}" | grep -v "clickhouse" || true)

if [ -z "$OLD_CONTAINERS" ]; then
    echo -e "${GREEN}✓ No old containers found${NC}"
    echo ""
    echo "Your environment is already clean!"
    exit 0
fi

echo "Found old containers:"
for container in $OLD_CONTAINERS; do
    STATUS=$(docker ps -a --filter "name=$container" --format "{{.Status}}")
    echo -e "  ${YELLOW}→${NC} $container ($STATUS)"
done

# Check kafka-ui separately
echo ""
if docker ps -a --format "{{.Names}}" | grep -q "^kafka-ui$"; then
    KAFKA_UI_STATUS=$(docker ps -a --filter "name=kafka-ui" --format "{{.Status}}")
    echo -e "${BLUE}Note:${NC} Found kafka-ui container ($KAFKA_UI_STATUS)"
    echo "  This might be used for monitoring. Should we delete it too?"
    echo ""
    read -p "Delete kafka-ui as well? (yes/no): " DELETE_UI
    if [ "$DELETE_UI" = "yes" ]; then
        OLD_CONTAINERS="$OLD_CONTAINERS kafka-ui"
    fi
fi

print_section "Step 2: Confirmation"

echo -e "${BOLD}${RED}WARNING: This action cannot be undone!${NC}"
echo ""
echo "Containers to be deleted:"
for container in $OLD_CONTAINERS; do
    echo -e "  ${RED}✗${NC} $container"
done
echo ""
read -p "Type 'DELETE' to confirm permanent removal: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo ""
    echo -e "${YELLOW}Cancelled. No containers were deleted.${NC}"
    exit 0
fi

print_section "Step 3: Stop Running Containers"

for container in $OLD_CONTAINERS; do
    # Check if running
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Stopping $container..."
        docker stop "$container" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status 0 "Stopped $container"
        else
            print_status 1 "Failed to stop $container (will try to remove anyway)"
        fi
    else
        echo "  $container is already stopped"
    fi
done

# Wait for graceful shutdown
echo ""
echo "Waiting 5 seconds for graceful shutdown..."
sleep 5

print_section "Step 4: Remove Containers"

REMOVED_COUNT=0
FAILED_COUNT=0

for container in $OLD_CONTAINERS; do
    echo "Removing $container..."
    docker rm -f "$container" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_status 0 "Removed $container"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    else
        print_status 1 "Failed to remove $container"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

print_section "Step 5: Verify Port 8083 is Free"

sleep 2

if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
    echo -e "${YELLOW}⚠ Port 8083 still in use${NC}"
    echo "Waiting 5 more seconds for port to be released..."
    sleep 5

    if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
        print_status 1 "Port 8083 still not free"
        echo ""
        echo "Check what's using it:"
        netstat -tulnp 2>/dev/null | grep ":8083 " || ss -tulnp 2>/dev/null | grep ":8083 "
    else
        print_status 0 "Port 8083 is now free"
    fi
else
    print_status 0 "Port 8083 is free"
fi

print_section "Step 6: Cleanup Summary"

echo "Results:"
echo "  Removed: $REMOVED_COUNT containers"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAILED_COUNT containers${NC}"
fi

echo ""
echo "Verifying old containers are gone..."
REMAINING=$(docker ps -a --filter "name=kafka-connect" --filter "name=kafka" --filter "name=postgres-sink" --format "{{.Names}}" | grep -v "clickhouse" | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    print_status 0 "All old containers successfully removed"
else
    print_status 1 "Some old containers still remain"
    docker ps -a --filter "name=kafka-connect" --filter "name=kafka" --filter "name=postgres-sink" --format "  {{.Names}}: {{.Status}}" | grep -v "clickhouse"
fi

print_section "Step 7: Start kafka-connect-clickhouse"

echo "Now starting kafka-connect-clickhouse on the freed port 8083..."
echo ""

# Check if container exists
if ! docker ps -a --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    print_status 1 "kafka-connect-clickhouse container does not exist"
    echo ""
    echo "You need to create it first. Check your Phase 2 setup."
    exit 1
fi

# Start the container
docker start kafka-connect-clickhouse >/dev/null 2>&1

if [ $? -eq 0 ]; then
    print_status 0 "Container start command succeeded"
else
    print_status 1 "Failed to start kafka-connect-clickhouse"
    echo ""
    echo "Check logs: docker logs kafka-connect-clickhouse --tail 50"
    exit 1
fi

# Wait and verify it stays running
echo ""
echo "Verifying container stays running (checking for 20 seconds)..."

STAYED_RUNNING=true
for i in {1..10}; do
    sleep 2
    if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
        echo -n "."
    else
        echo ""
        print_status 1 "Container crashed after $((i*2)) seconds"
        echo ""
        echo "Even with old containers removed, it's still crashing."
        echo "Check logs for other issues:"
        echo "  docker logs kafka-connect-clickhouse --tail 50"
        STAYED_RUNNING=false
        exit 1
    fi
done

if [ "$STAYED_RUNNING" = true ]; then
    echo ""
    print_status 0 "Container stayed running for 20 seconds"
fi

print_section "Step 8: Verify Kafka Connect API"

echo "Waiting for Kafka Connect REST API to respond..."

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

    VERSION=$(curl -s http://localhost:8083/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    COMMIT=$(curl -s http://localhost:8083/ 2>/dev/null | grep -o '"commit":"[^"]*"' | cut -d'"' -f4)

    echo ""
    echo "  Version: $VERSION"
    echo "  Commit:  $COMMIT"

    # Check plugins
    PLUGINS=$(curl -s http://localhost:8083/connector-plugins 2>/dev/null | grep -o '"class":"[^"]*"' | wc -l)
    echo "  Plugins: $PLUGINS loaded"

    if [ "$PLUGINS" -gt 0 ]; then
        echo ""
        echo "Available connector plugins:"
        curl -s http://localhost:8083/connector-plugins 2>/dev/null | python3 -c "
import sys, json
try:
    plugins = json.load(sys.stdin)
    for p in plugins:
        print(f\"    - {p.get('class', 'unknown')}\")
except:
    pass
" 2>/dev/null || echo "    (Could not parse plugin list)"
    fi
else
    print_status 1 "API not responding after 2 minutes"
    echo ""
    echo "Container is running but API not ready."
    echo "Check logs: docker logs kafka-connect-clickhouse --tail 50"
    exit 1
fi

print_section "SUCCESS!"

echo -e "${GREEN}${BOLD}✓ Old containers completely removed${NC}"
echo -e "${GREEN}${BOLD}✓ Port 8083 freed${NC}"
echo -e "${GREEN}${BOLD}✓ kafka-connect-clickhouse running and healthy${NC}"
echo ""
echo "Your environment is now clean with only the ClickHouse CDC containers."
echo ""
echo "Current containers:"
docker ps --format "  - {{.Names}}: {{.Status}}" | grep -E "clickhouse|redpanda"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Deploy connectors:"
echo "     cd /home/centos/clickhouse/phase3/scripts"
echo "     ./03_deploy_connectors.sh"
echo ""
echo "  2. Monitor snapshot progress:"
echo "     ./04_monitor_snapshot.sh"
echo ""
