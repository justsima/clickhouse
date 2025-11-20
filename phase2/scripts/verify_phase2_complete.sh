#!/bin/bash
# Comprehensive Phase 2 Verification
# Ensures all services are properly configured and running

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

cd /home/centos/clickhouse/phase2

print_section "Phase 2 Complete Verification"

echo "Checking if all required services are properly set up..."
echo ""

print_section "Step 1: Expected Services from docker-compose.yml"

echo "According to docker-compose.yml, we should have 4 services:"
echo ""
echo "  1. redpanda (container: redpanda-clickhouse)"
echo "  2. redpanda-console (container: redpanda-console-clickhouse)"
echo "  3. kafka-connect (container: kafka-connect-clickhouse)"
echo "  4. clickhouse (container: clickhouse-server)"
echo ""

print_section "Step 2: Current docker-compose Status"

echo "Checking what docker-compose shows:"
echo ""
docker-compose ps

echo ""

SERVICES_COUNT=$(docker-compose ps --services 2>/dev/null | wc -l)
RUNNING_COUNT=$(docker-compose ps | grep -c "Up" || echo "0")

echo "Services defined: 4 (expected)"
echo "Services created: $SERVICES_COUNT"
echo "Services running: $RUNNING_COUNT"
echo ""

if [ "$SERVICES_COUNT" -eq 4 ] && [ "$RUNNING_COUNT" -eq 4 ]; then
    print_status 0 "All services are running"
elif [ "$SERVICES_COUNT" -lt 4 ]; then
    print_status 1 "Some services were never created"
    echo ""
    echo -e "${RED}PROBLEM: Not all services from docker-compose.yml were created${NC}"
else
    print_status 1 "Some services are not running"
fi

print_section "Step 3: Individual Service Verification"

# Check each service
echo "Checking each required service..."
echo ""

# 1. Redpanda
echo -e "${BOLD}1. Redpanda (Message Broker)${NC}"
if docker ps --format "{{.Names}}" | grep -q "^redpanda-clickhouse$"; then
    HEALTH=$(docker inspect redpanda-clickhouse --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
    print_status 0 "Container running (Health: $HEALTH)"

    # Test Redpanda broker
    if docker exec redpanda-clickhouse rpk cluster info &>/dev/null; then
        print_status 0 "Redpanda broker responding"
    else
        print_status 1 "Redpanda broker not responding"
    fi
else
    print_status 1 "Container NOT running"
fi
echo ""

# 2. Redpanda Console
echo -e "${BOLD}2. Redpanda Console (Web UI)${NC}"
if docker ps --format "{{.Names}}" | grep -q "^redpanda-console-clickhouse$"; then
    print_status 0 "Container running"

    # Test web UI
    if curl -s http://localhost:8086/ >/dev/null 2>&1; then
        print_status 0 "Web UI accessible on port 8086"
    else
        print_status 1 "Web UI not accessible on port 8086"
    fi
else
    print_status 1 "Container NOT running"
fi
echo ""

# 3. Kafka Connect - THE CRITICAL ONE
echo -e "${BOLD}3. Kafka Connect (Debezium + Connectors)${NC}"
if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    HEALTH=$(docker inspect kafka-connect-clickhouse --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
    print_status 0 "Container running (Health: $HEALTH)"

    # Check if managed by docker-compose
    COMPOSE_PROJECT=$(docker inspect kafka-connect-clickhouse --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)
    if [ -n "$COMPOSE_PROJECT" ]; then
        print_status 0 "Managed by docker-compose (project: $COMPOSE_PROJECT)"
    else
        print_status 1 "NOT managed by docker-compose (created manually)"
        echo -e "  ${YELLOW}This container needs to be recreated via docker-compose${NC}"
    fi

    # Check network IP
    IP=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}' 2>/dev/null)
    if [ -n "$IP" ]; then
        print_status 0 "Has IP address: $IP"
    else
        print_status 1 "NO IP address (network issue)"
    fi

    # Test API on correct port (8085)
    if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
        print_status 0 "REST API responding on port 8085"
    else
        print_status 1 "REST API NOT responding on port 8085"
    fi
else
    print_status 1 "Container NOT running"
    echo -e "  ${RED}CRITICAL: Kafka Connect is required for CDC pipeline${NC}"
fi
echo ""

# 4. ClickHouse
echo -e "${BOLD}4. ClickHouse (Target Database)${NC}"
if docker ps --format "{{.Names}}" | grep -q "^clickhouse-server$"; then
    HEALTH=$(docker inspect clickhouse-server --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
    print_status 0 "Container running (Health: $HEALTH)"

    # Test HTTP interface
    if curl -s http://localhost:8123/ping 2>/dev/null | grep -q "Ok"; then
        print_status 0 "HTTP interface responding on port 8123"
    else
        print_status 1 "HTTP interface not responding on port 8123"
    fi
else
    print_status 1 "Container NOT running"
fi
echo ""

print_section "Step 4: Network Verification"

NETWORK_NAME="clickhouse-cdc-network"

echo "Checking Docker network: $NETWORK_NAME"
echo ""

if docker network inspect $NETWORK_NAME &>/dev/null; then
    print_status 0 "Network exists"

    # Check which containers are connected
    echo ""
    echo "Containers on this network:"
    docker network inspect $NETWORK_NAME --format '{{range .Containers}}  - {{.Name}} ({{.IPv4Address}}){{println}}{{end}}'

    # Count containers
    NETWORK_CONTAINERS=$(docker network inspect $NETWORK_NAME --format '{{range .Containers}}{{.Name}}{{println}}{{end}}' | wc -l)
    echo ""
    echo "Total containers on network: $NETWORK_CONTAINERS"

    if [ "$NETWORK_CONTAINERS" -eq 4 ]; then
        print_status 0 "All 4 services connected to network"
    else
        print_status 1 "Expected 4 containers, found $NETWORK_CONTAINERS"
    fi
else
    print_status 1 "Network does NOT exist"
fi

print_section "Step 5: Volume Verification"

echo "Checking Docker volumes..."
echo ""

# Check if volumes exist
VOLUMES=("redpanda_data" "clickhouse_data" "clickhouse_logs")

for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "phase2_${vol}" &>/dev/null || docker volume inspect "${vol}" &>/dev/null; then
        print_status 0 "Volume exists: $vol"
    else
        print_status 1 "Volume missing: $vol"
    fi
done

print_section "Step 6: Port Mapping Verification"

echo "Verifying exposed ports are not conflicting..."
echo ""

# Expected ports
declare -A EXPECTED_PORTS=(
    ["8123"]="ClickHouse HTTP"
    ["9000"]="ClickHouse Native"
    ["8085"]="Kafka Connect API"
    ["8086"]="Redpanda Console"
    ["9093"]="Redpanda Kafka (external)"
    ["8081"]="Schema Registry"
    ["8082"]="Redpanda HTTP Proxy"
    ["9644"]="Redpanda Admin"
)

for port in "${!EXPECTED_PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        print_status 0 "Port $port in use (${EXPECTED_PORTS[$port]})"
    else
        print_status 1 "Port $port NOT in use (${EXPECTED_PORTS[$port]}) - service may be down"
    fi
done

print_section "Step 7: Critical Issues Summary"

ISSUES=0

echo "Analyzing critical issues..."
echo ""

# Issue 1: kafka-connect not managed by docker-compose
if ! docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    echo -e "${RED}✗ CRITICAL: kafka-connect-clickhouse is NOT running${NC}"
    ISSUES=$((ISSUES + 1))
else
    COMPOSE_PROJECT=$(docker inspect kafka-connect-clickhouse --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)
    if [ -z "$COMPOSE_PROJECT" ]; then
        echo -e "${RED}✗ CRITICAL: kafka-connect-clickhouse not managed by docker-compose${NC}"
        echo "  This container was created manually and needs to be recreated"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Issue 2: kafka-connect has no IP
IP=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}' 2>/dev/null)
if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$" && [ -z "$IP" ]; then
    echo -e "${RED}✗ CRITICAL: kafka-connect-clickhouse has no IP address${NC}"
    echo "  Cannot communicate with other services"
    ISSUES=$((ISSUES + 1))
fi

# Issue 3: kafka-connect API not responding
if ! curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
    echo -e "${RED}✗ CRITICAL: Kafka Connect API not responding on port 8085${NC}"
    echo "  Cannot deploy connectors without working API"
    ISSUES=$((ISSUES + 1))
fi

# Issue 4: Services count mismatch
RUNNING_COUNT=$(docker-compose ps | grep -c "Up" || echo "0")
if [ "$RUNNING_COUNT" -lt 4 ]; then
    echo -e "${YELLOW}⚠ WARNING: Only $RUNNING_COUNT/4 services are running${NC}"
    ISSUES=$((ISSUES + 1))
fi

echo ""

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ No critical issues found - Phase 2 is complete!${NC}"
else
    echo -e "${RED}${BOLD}Found $ISSUES critical issue(s) that need to be fixed${NC}"
fi

print_section "Step 8: Recommendations"

if [ $ISSUES -gt 0 ]; then
    echo -e "${BOLD}Recommended Actions:${NC}"
    echo ""

    if ! docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$" || [ -z "$IP" ]; then
        echo "1. Recreate kafka-connect-clickhouse properly:"
        echo "   cd /home/centos/clickhouse/phase2/scripts"
        echo "   ./recreate_kafka_connect.sh"
        echo ""
    fi

    if [ "$RUNNING_COUNT" -lt 4 ]; then
        echo "2. Start all Phase 2 services:"
        echo "   cd /home/centos/clickhouse/phase2"
        echo "   docker-compose up -d"
        echo ""
    fi

    echo "3. After fixing, re-run this verification:"
    echo "   ./scripts/verify_phase2_complete.sh"
    echo ""
else
    echo "Phase 2 is properly set up!"
    echo ""
    echo "Next step: Deploy connectors in Phase 3"
    echo "  cd /home/centos/clickhouse/phase3/scripts"
    echo "  ./03_deploy_connectors.sh"
    echo ""
fi
