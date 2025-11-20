#!/bin/bash
# Diagnose kafka-connect-clickhouse crash loop
# Root cause: Container cannot connect to Redpanda

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

print_section "Kafka Connect Crash Loop Diagnosis"

echo -e "${BOLD}Problem: kafka-connect-clickhouse is in a crash loop${NC}"
echo "It restarts every ~2 minutes before REST API starts."
echo ""

print_section "Step 1: Check Container Networks"

echo "Checking what networks each container is on..."
echo ""

# Check redpanda network
REDPANDA_NETWORK=$(docker inspect redpanda-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
echo "Redpanda network(s): $REDPANDA_NETWORK"

# Check kafka-connect network
KC_NETWORK=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
echo "Kafka Connect network(s): $KC_NETWORK"

echo ""

if [ "$REDPANDA_NETWORK" = "$KC_NETWORK" ] && [ -n "$REDPANDA_NETWORK" ]; then
    print_status 0 "Both containers on same network: $REDPANDA_NETWORK"
else
    print_status 1 "Containers on DIFFERENT networks!"
    echo ""
    echo -e "${RED}This is the problem!${NC}"
    echo "Kafka Connect cannot reach Redpanda because they're isolated."
    echo ""
fi

print_section "Step 2: Test Network Connectivity"

echo "Testing if kafka-connect can resolve 'redpanda' hostname..."
echo ""

# Try to ping from kafka-connect to redpanda
PING_TEST=$(docker exec kafka-connect-clickhouse sh -c "ping -c 1 redpanda 2>&1" 2>&1 || true)

if echo "$PING_TEST" | grep -q "1 packets transmitted, 1 received"; then
    print_status 0 "Can reach redpanda via hostname"
elif echo "$PING_TEST" | grep -q "bad address\|unknown host\|Name or service not known"; then
    print_status 1 "Cannot resolve 'redpanda' hostname"
    echo ""
    echo -e "${RED}NETWORK ISOLATION CONFIRMED${NC}"
    echo "The kafka-connect container cannot even find the redpanda container."
else
    echo -e "${YELLOW}⚠${NC} Ping test inconclusive: ${PING_TEST:0:100}"
fi

print_section "Step 3: Check How Containers Were Created"

echo "Checking Phase 2 setup..."
echo ""

# Check if docker-compose file exists
if [ -f "/home/centos/clickhouse/phase2/docker-compose.yml" ]; then
    print_status 0 "Phase 2 docker-compose.yml exists"
    echo ""
    echo "Contents:"
    head -50 /home/centos/clickhouse/phase2/docker-compose.yml
elif [ -f "/home/centos/clickhouse/phase2/docker-compose.yaml" ]; then
    print_status 0 "Phase 2 docker-compose.yaml exists"
    echo ""
    echo "Contents:"
    head -50 /home/centos/clickhouse/phase2/docker-compose.yaml
else
    print_status 1 "No Phase 2 docker-compose file found"
    echo ""
    echo "Expected location: /home/centos/clickhouse/phase2/docker-compose.yml"
fi

print_section "Step 4: List All Docker Networks"

echo "All Docker networks on this system:"
echo ""
docker network ls

echo ""
echo "Detailed network info for containers:"
echo ""

# Show redpanda network details
echo -e "${BLUE}Redpanda network details:${NC}"
docker inspect redpanda-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}Network: {{$net}}, IP: {{$v.IPAddress}}{{end}}' 2>/dev/null

# Show kafka-connect network details
echo -e "${BLUE}Kafka Connect network details:${NC}"
docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}Network: {{$net}}, IP: {{$v.IPAddress}}{{end}}' 2>/dev/null

print_section "Step 5: Root Cause Analysis"

echo -e "${BOLD}Analysis:${NC}"
echo ""

if [ "$REDPANDA_NETWORK" != "$KC_NETWORK" ] || [ -z "$KC_NETWORK" ]; then
    echo -e "${RED}ROOT CAUSE: Network Isolation${NC}"
    echo ""
    echo "kafka-connect-clickhouse cannot reach redpanda:9092 because:"
    echo "  • Redpanda is on: $REDPANDA_NETWORK"
    echo "  • Kafka Connect is on: ${KC_NETWORK:-<none>}"
    echo ""
    echo "Kafka Connect in distributed mode MUST connect to Kafka/Redpanda to:"
    echo "  1. Store connector configurations"
    echo "  2. Coordinate with other workers"
    echo "  3. Store offset data"
    echo ""
    echo "Without this connection, it crashes before REST API starts."
else
    echo -e "${YELLOW}Containers are on same network but still can't connect.${NC}"
    echo "Possible causes:"
    echo "  • Redpanda not fully initialized"
    echo "  • Firewall rules blocking communication"
    echo "  • Redpanda listener configuration issue"
fi

print_section "Step 6: Solution"

echo "Option 1: Connect kafka-connect to correct network (QUICK FIX)"
echo "───────────────────────────────────────────────────────────"
echo ""
echo "  docker network connect $REDPANDA_NETWORK kafka-connect-clickhouse"
echo "  docker restart kafka-connect-clickhouse"
echo ""

echo "Option 2: Recreate container with Phase 2 (PROPER FIX)"
echo "───────────────────────────────────────────────────────────"
echo ""
echo "  cd /home/centos/clickhouse/phase2"
echo "  docker-compose down kafka-connect-clickhouse"
echo "  docker-compose up -d kafka-connect-clickhouse"
echo ""

echo "Option 3: Check if Phase 2 was run at all"
echo "───────────────────────────────────────────────────────────"
echo ""
echo "  cd /home/centos/clickhouse/phase2"
echo "  docker-compose ps"
echo ""
echo "  If containers not shown, Phase 2 was never run properly."
echo "  Solution: docker-compose up -d"
echo ""

print_section "Recommended Action"

echo "Run this command to see if Phase 2 is managing these containers:"
echo ""
echo "  cd /home/centos/clickhouse/phase2"
echo "  docker-compose ps"
echo ""
echo "Then share the output so we can determine the correct fix."
echo ""
