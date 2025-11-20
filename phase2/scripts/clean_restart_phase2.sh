#!/bin/bash
# Complete Phase 2 Clean Restart
# Removes ALL Phase 2 containers and recreates them properly from scratch

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

print_section "Phase 2 - Complete Clean Restart"

echo -e "${BOLD}This will completely remove and recreate Phase 2 infrastructure:${NC}"
echo ""
echo "Will DELETE:"
echo "  • kafka-connect-clickhouse container"
echo "  • redpanda-clickhouse container"
echo "  • redpanda-console-clickhouse container"
echo "  • clickhouse-server container"
echo ""
echo "Will KEEP:"
echo "  ✓ ClickHouse data volume (your 450 tables)"
echo "  ✓ mysql-container (source database)"
echo "  ✓ All other non-Phase-2 containers"
echo ""
echo -e "${YELLOW}Note: Redpanda data will be deleted (topics, offsets)${NC}"
echo -e "${YELLOW}Note: Kafka Connect configuration will be deleted${NC}"
echo ""
read -p "Type 'RESTART' to confirm complete Phase 2 restart: " CONFIRM

if [ "$CONFIRM" != "RESTART" ]; then
    echo "Cancelled."
    exit 0
fi

print_section "Step 1: Stop All Phase 2 Containers"

echo "Stopping Phase 2 containers via docker-compose..."
docker-compose down

print_status $? "Stopped all Phase 2 containers"

print_section "Step 2: Remove Containers Completely"

echo "Removing any remaining Phase 2 containers..."

for container in kafka-connect-clickhouse redpanda-clickhouse redpanda-console-clickhouse; do
    if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "  Removing: $container"
        docker rm -f $container 2>/dev/null
        print_status $? "  Removed $container"
    else
        echo "  $container already removed"
    fi
done

# Keep clickhouse-server but stop it
if docker ps --format "{{.Names}}" | grep -q "^clickhouse-server$"; then
    echo "  Stopping clickhouse-server (will recreate)"
    docker stop clickhouse-server 2>/dev/null
    docker rm -f clickhouse-server 2>/dev/null
    print_status $? "  Removed clickhouse-server"
fi

sleep 3

print_section "Step 3: Clean Up Redpanda Data"

echo "Removing Redpanda data volume (will be recreated)..."

if docker volume ls | grep -q "redpanda_data\|phase2_redpanda_data"; then
    docker volume rm redpanda_data 2>/dev/null || docker volume rm phase2_redpanda_data 2>/dev/null
    print_status $? "Removed Redpanda data"
else
    echo "  No Redpanda volume found"
fi

print_section "Step 4: Verify ClickHouse Data Is Safe"

echo "Checking ClickHouse data volume..."

if docker volume ls | grep -q "clickhouse_data\|phase2_clickhouse_data"; then
    print_status 0 "ClickHouse data volume exists (will be preserved)"

    # Show volume size
    SIZE=$(docker run --rm -v clickhouse_data:/data alpine du -sh /data 2>/dev/null || docker run --rm -v phase2_clickhouse_data:/data alpine du -sh /data 2>/dev/null)
    echo "  Volume size: $SIZE"
else
    print_status 1 "ClickHouse data volume not found"
    echo -e "${YELLOW}  Your 450 tables may be missing. Check if tables were created in Phase 1.${NC}"
fi

print_section "Step 5: Network Cleanup"

echo "Removing clickhouse-cdc-network (will be recreated)..."

if docker network ls | grep -q "clickhouse-cdc-network"; then
    docker network rm clickhouse-cdc-network 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status 0 "Removed network"
    else
        echo -e "${YELLOW}⚠ Network removal failed (may still be in use)${NC}"
        echo "  This is OK - docker-compose will handle it"
    fi
else
    echo "  Network already removed"
fi

print_section "Step 6: Recreate ALL Phase 2 Services"

echo "Starting fresh Phase 2 setup with docker-compose..."
echo ""
echo "This will create:"
echo "  1. redpanda-clickhouse"
echo "  2. redpanda-console-clickhouse"
echo "  3. kafka-connect-clickhouse (FRESH, properly configured)"
echo "  4. clickhouse-server (reusing existing data)"
echo ""

docker-compose up -d

if [ $? -eq 0 ]; then
    print_status 0 "All services created"
else
    print_status 1 "Failed to create services"
    echo ""
    echo "Check errors above and try:"
    echo "  docker-compose logs"
    exit 1
fi

print_section "Step 7: Wait for Services to Initialize"

echo "Waiting for services to start (60 seconds)..."
echo ""

for i in {1..12}; do
    echo -n "."
    sleep 5
done

echo ""
echo ""

print_section "Step 8: Verify All Services"

echo "Checking service status..."
echo ""

# Check each service
echo "1. Redpanda:"
if docker ps | grep -q "redpanda-clickhouse.*healthy"; then
    print_status 0 "Running and healthy"
elif docker ps | grep -q "redpanda-clickhouse"; then
    echo -e "${YELLOW}⚠ Running but not healthy yet (may still be starting)${NC}"
else
    print_status 1 "NOT running"
fi

echo ""
echo "2. Redpanda Console:"
if docker ps | grep -q "redpanda-console-clickhouse"; then
    print_status 0 "Running"

    if curl -s http://localhost:8086/ >/dev/null 2>&1; then
        print_status 0 "Web UI accessible at http://localhost:8086"
    else
        echo -e "${YELLOW}⚠ Container running but UI not ready yet${NC}"
    fi
else
    print_status 1 "NOT running"
fi

echo ""
echo "3. Kafka Connect:"
if docker ps | grep -q "kafka-connect-clickhouse"; then
    print_status 0 "Container running"

    # Check if managed by docker-compose
    COMPOSE_PROJECT=$(docker inspect kafka-connect-clickhouse --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)
    if [ -n "$COMPOSE_PROJECT" ]; then
        print_status 0 "Managed by docker-compose: $COMPOSE_PROJECT"
    else
        print_status 1 "NOT managed by docker-compose"
    fi

    # Check IP address
    IP=$(docker inspect kafka-connect-clickhouse --format '{{range $net,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}' 2>/dev/null)
    if [ -n "$IP" ]; then
        print_status 0 "Has IP address: $IP"
    else
        print_status 1 "NO IP address"
    fi

    # Check API (may take time to start)
    if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
        print_status 0 "API responding on port 8085"
        VERSION=$(curl -s http://localhost:8085/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "    Version: $VERSION"
    else
        echo -e "${YELLOW}⚠ API not responding yet (may take 2-3 minutes to initialize)${NC}"
        echo "    Check with: curl -s http://localhost:8085/ | grep version"
    fi
else
    print_status 1 "NOT running"
    echo ""
    echo "Check logs: docker logs kafka-connect-clickhouse --tail 50"
fi

echo ""
echo "4. ClickHouse:"
if docker ps | grep -q "clickhouse-server"; then
    print_status 0 "Running"

    if curl -s http://localhost:8123/ping 2>/dev/null | grep -q "Ok"; then
        print_status 0 "HTTP interface responding on port 8123"

        # Check table count
        TABLE_COUNT=$(curl -s "http://localhost:8123/?query=SELECT count() FROM system.tables WHERE database='mulasport'" 2>/dev/null || echo "0")
        echo "    Tables in mulasport database: $TABLE_COUNT"

        if [ "$TABLE_COUNT" -gt 400 ]; then
            print_status 0 "Your 450 tables are intact"
        elif [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠ Only $TABLE_COUNT tables found (expected ~450)${NC}"
        else
            echo -e "${RED}⚠ No tables found - Phase 1 may need to be re-run${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ HTTP interface not responding${NC}"
    fi
else
    print_status 1 "NOT running"
fi

print_section "Step 9: Final Verification"

echo "Running comprehensive verification..."
echo ""

# Run the verification script
if [ -f "./scripts/verify_phase2_complete.sh" ]; then
    ./scripts/verify_phase2_complete.sh | grep -A 50 "Step 7: Critical Issues Summary"
else
    echo "Verification script not found, checking docker-compose status:"
    docker-compose ps
fi

print_section "Summary"

RUNNING_COUNT=$(docker-compose ps | grep -c "Up" || echo "0")

echo "Services running: $RUNNING_COUNT/4"
echo ""

if [ "$RUNNING_COUNT" -eq 4 ]; then
    echo -e "${GREEN}${BOLD}✓ Phase 2 completely recreated successfully!${NC}"
    echo ""
    echo "All services are running. Wait 2-3 minutes for Kafka Connect API to fully initialize."
    echo ""
    echo "Test Kafka Connect API:"
    echo "  curl -s http://localhost:8085/ | grep version"
    echo ""
    echo "Once API responds, proceed to Phase 3:"
    echo "  cd /home/centos/clickhouse/phase3/scripts"
    echo "  ./03_deploy_connectors.sh"
    echo ""
elif [ "$RUNNING_COUNT" -eq 3 ]; then
    echo -e "${YELLOW}⚠ 3/4 services running${NC}"
    echo ""
    echo "Kafka Connect may still be starting. Wait 2-3 minutes, then check:"
    echo "  docker logs kafka-connect-clickhouse --tail 50"
    echo "  curl -s http://localhost:8085/ | grep version"
    echo ""
else
    echo -e "${RED}✗ Only $RUNNING_COUNT/4 services running${NC}"
    echo ""
    echo "Check what went wrong:"
    echo "  docker-compose logs"
    echo "  docker ps -a"
    echo ""
fi
