#!/bin/bash
# Phase 2 - Health Check Script
# Purpose: Verify all services are running and healthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
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

echo "========================================"
echo "   Service Health Check"
echo "========================================"
echo ""

ALL_HEALTHY=0

# Check Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}ERROR: Docker Compose not found${NC}"
    exit 1
fi

cd "$PHASE2_DIR"

echo "1. Container Status"
echo "-------------------"
CONTAINERS=("redpanda-clickhouse" "kafka-connect-clickhouse" "clickhouse-server" "redpanda-console-clickhouse")

for CONTAINER in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null)
        if [ "$STATUS" = "running" ]; then
            print_status 0 "$CONTAINER is running"
        else
            print_status 1 "$CONTAINER is $STATUS"
            ALL_HEALTHY=1
        fi
    else
        print_status 1 "$CONTAINER is not running"
        ALL_HEALTHY=1
    fi
done

echo ""
echo "2. Service Health Checks"
echo "------------------------"

# Redpanda health
print_info "Checking Redpanda..."
if docker exec redpanda-clickhouse rpk cluster health 2>/dev/null | grep -q "Healthy:.*true"; then
    print_status 0 "Redpanda cluster is healthy"
else
    print_status 1 "Redpanda cluster is unhealthy"
    ALL_HEALTHY=1
fi

# Kafka Connect health
print_info "Checking Kafka Connect..."
if curl -s http://localhost:8085/ | grep -q "version"; then
    print_status 0 "Kafka Connect is responding"

    # Check connectors
    CONNECTOR_COUNT=$(curl -s http://localhost:8085/connectors | jq '. | length' 2>/dev/null || echo "0")
    echo "  Connectors deployed: $CONNECTOR_COUNT"
else
    print_status 1 "Kafka Connect is not responding"
    ALL_HEALTHY=1
fi

# ClickHouse health
print_info "Checking ClickHouse..."
# Read password from .env file or use default
CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}
if [ -f "$PHASE2_DIR/configs/.env" ]; then
    source "$PHASE2_DIR/configs/.env"
fi

if curl -s http://localhost:8123/ping | grep -q "Ok"; then
    print_status 0 "ClickHouse is responding"

    # Get ClickHouse version (with authentication)
    CH_VERSION=$(curl -s -u "default:${CLICKHOUSE_PASSWORD}" 'http://localhost:8123/?query=SELECT%20version()' 2>/dev/null || echo "unknown")
    echo "  ClickHouse version: $CH_VERSION"

    # Check database (with authentication)
    DB_CHECK=$(curl -s -u "default:${CLICKHOUSE_PASSWORD}" 'http://localhost:8123/?query=SHOW%20DATABASES' 2>/dev/null || echo "")
    if echo "$DB_CHECK" | grep -q "analytics"; then
        print_status 0 "Analytics database exists"
    else
        print_status 1 "Analytics database not found"
    fi
else
    print_status 1 "ClickHouse is not responding"
    ALL_HEALTHY=1
fi

# Redpanda Console health
print_info "Checking Redpanda Console..."
if curl -s http://localhost:8086/ &> /dev/null; then
    print_status 0 "Redpanda Console is responding"
else
    print_status 1 "Redpanda Console is not responding"
    ALL_HEALTHY=1
fi

echo ""
echo "3. Network Connectivity"
echo "-----------------------"

# Test inter-service connectivity
print_info "Testing Kafka Connect -> Redpanda..."
if docker exec kafka-connect-clickhouse curl -s http://redpanda:9644/v1/status/ready &> /dev/null; then
    print_status 0 "Kafka Connect can reach Redpanda"
else
    print_status 1 "Kafka Connect cannot reach Redpanda"
    ALL_HEALTHY=1
fi

print_info "Testing Kafka Connect -> ClickHouse..."
if docker exec kafka-connect-clickhouse nc -zv clickhouse 9000 &> /dev/null; then
    print_status 0 "Kafka Connect can reach ClickHouse"
else
    print_status 1 "Kafka Connect cannot reach ClickHouse"
    ALL_HEALTHY=1
fi

echo ""
echo "4. Resource Usage"
echo "-----------------"

echo "Container resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  redpanda-clickhouse kafka-connect-clickhouse clickhouse-server redpanda-console-clickhouse 2>/dev/null || \
  echo "Unable to retrieve stats"

echo ""
echo "5. Disk Usage"
echo "-------------"

docker system df

echo ""
echo "========================================"
echo "   Health Check Summary"
echo "========================================"
echo ""

if [ $ALL_HEALTHY -eq 0 ]; then
    echo -e "${GREEN}✓ All services are healthy!${NC}"
    echo ""
    echo "Service URLs:"
    echo "  Redpanda Console:  http://localhost:8086"
    echo "  Kafka Connect API: http://localhost:8085"
    echo "  ClickHouse HTTP:   http://localhost:8123"
    echo ""
    echo "Ready to proceed to Phase 3!"
else
    echo -e "${YELLOW}⚠ Some services are unhealthy${NC}"
    echo ""
    echo "Check logs for more details:"
    echo "  docker compose logs -f"
    echo ""
    echo "Common issues:"
    echo "  - Services still starting (wait 1-2 minutes)"
    echo "  - Port conflicts (check with: netstat -tuln)"
    echo "  - Resource constraints (check: docker stats)"
fi

echo ""
