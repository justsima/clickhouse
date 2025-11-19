#!/bin/bash
# Clean up duplicate/old Phase 2 containers

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "   Identifying Phase 2 Containers"
echo "========================================"
echo ""

# List of Phase 2 container names
PHASE2_CONTAINERS=(
    "clickhouse-server"
    "redpanda-clickhouse"
    "redpanda-console-clickhouse"
    "kafka-connect-clickhouse"
)

echo "Phase 2 containers we need:"
for container in "${PHASE2_CONTAINERS[@]}"; do
    echo "  - $container"
done
echo ""

echo "Current running containers with similar names:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "clickhouse|redpanda|kafka-connect" || echo "None found"
echo ""

read -p "Do you want to stop and remove old Phase 2 containers? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Stopping and removing old containers..."
echo ""

for container in "${PHASE2_CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${BLUE}ℹ${NC} Found container: $container"

        # Stop if running
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${YELLOW}  Stopping...${NC}"
            docker stop "$container" 2>/dev/null || true
        fi

        # Remove
        echo -e "${YELLOW}  Removing...${NC}"
        docker rm "$container" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Removed: $container"
    else
        echo -e "${BLUE}ℹ${NC} Not found: $container (will be created fresh)"
    fi
done

echo ""
echo -e "${GREEN}✓${NC} Cleanup complete!"
echo ""
echo "Next step: Start fresh Phase 2 services"
echo "  cd /home/centos/clickhouse/phase2"
echo "  docker-compose up -d"
