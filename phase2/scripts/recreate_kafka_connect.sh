#!/bin/bash
# Recreate kafka-connect-clickhouse properly using docker-compose
# This fixes the crash loop caused by manually created container

set -e

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

cd /home/centos/clickhouse/phase2

print_section "Recreate Kafka Connect Container"

echo -e "${BOLD}Problem:${NC}"
echo "  Current kafka-connect-clickhouse was created manually"
echo "  It has no IP address and crashes in a loop"
echo ""
echo -e "${BOLD}Solution:${NC}"
echo "  1. Remove the broken container"
echo "  2. Recreate it properly using docker-compose"
echo ""

print_section "Step 1: Remove Broken Container"

echo "Stopping and removing manually-created kafka-connect-clickhouse..."

if docker ps -a --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    docker stop kafka-connect-clickhouse 2>/dev/null || true
    docker rm -f kafka-connect-clickhouse 2>/dev/null || true
    print_status 0 "Removed broken container"
else
    echo "Container already removed"
fi

sleep 2

print_section "Step 2: Recreate with Docker Compose"

echo "Creating kafka-connect-clickhouse using docker-compose..."
echo ""

docker-compose up -d kafka-connect

if [ $? -eq 0 ]; then
    print_status 0 "Container created successfully"
else
    print_status 1 "Failed to create container"
    exit 1
fi

print_section "Step 3: Wait for Kafka Connect to Initialize"

echo "Waiting for Kafka Connect to start (this takes 1-2 minutes)..."
echo ""

# Wait up to 3 minutes for the API to be ready
for i in {1..36}; do
    # Check if container is still running
    if ! docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
        echo ""
        print_status 1 "Container crashed during startup"
        echo ""
        echo "Check logs: docker logs kafka-connect-clickhouse --tail 50"
        exit 1
    fi

    # Try to access API on port 8085 (host port from docker-compose)
    if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
        echo ""
        print_status 0 "Kafka Connect API is responding on port 8085"
        break
    fi

    echo -n "."
    sleep 5
done

echo ""

# Final check
if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
    VERSION=$(curl -s http://localhost:8085/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    print_status 0 "Kafka Connect API is ready"
    echo ""
    echo "  Version: $VERSION"
    echo "  API URL: http://localhost:8085/"
else
    print_status 1 "API still not responding after 3 minutes"
    echo ""
    echo "Container may still be initializing. Check logs:"
    echo "  docker logs -f kafka-connect-clickhouse"
    exit 1
fi

print_section "Step 4: Verify Network Configuration"

echo "Checking network setup..."
echo ""

NETWORK=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null)
IP=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}' 2>/dev/null)

echo "  Network: $NETWORK"
echo "  IP Address: $IP"

if [ -n "$IP" ]; then
    print_status 0 "Container has valid IP address"
else
    print_status 1 "Container has no IP address"
fi

echo ""

# Test connectivity to Redpanda
echo "Testing connectivity to Redpanda..."
PING_TEST=$(docker exec kafka-connect-clickhouse sh -c "ping -c 1 redpanda" 2>&1)

if echo "$PING_TEST" | grep -q "1 packets transmitted, 1 received"; then
    print_status 0 "Can reach Redpanda broker"
else
    print_status 1 "Cannot reach Redpanda broker"
    echo "$PING_TEST"
fi

print_section "Step 5: Check docker-compose Status"

echo "All Phase 2 containers:"
echo ""
docker-compose ps

print_section "SUCCESS!"

echo -e "${GREEN}${BOLD}✓ Kafka Connect recreated successfully${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Kafka Connect is exposed on port 8085 (not 8083!)${NC}"
echo ""
echo "Access the API at:"
echo "  http://localhost:8085/"
echo ""
echo "Test it:"
echo "  curl -s http://localhost:8085/ | grep version"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo "  1. Update Phase 3 scripts to use port 8085"
echo "  2. Deploy connectors: cd ../phase3/scripts && ./03_deploy_connectors.sh"
echo ""
