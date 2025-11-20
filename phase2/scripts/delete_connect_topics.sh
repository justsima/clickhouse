#!/bin/bash
# Delete Kafka Connect internal topics
# These may have been created with wrong replication factor (3 instead of 1)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "Delete Kafka Connect Internal Topics"

echo -e "${YELLOW}This will delete the following topics:${NC}"
echo "  - clickhouse_connect_configs"
echo "  - clickhouse_connect_offsets"
echo "  - clickhouse_connect_status"
echo ""
echo -e "${RED}WARNING: This will reset all Kafka Connect configuration and offset tracking!${NC}"
echo "Only do this if the container is failing to start due to replication factor mismatch."
echo ""
read -p "Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelled."
    exit 0
fi

print_section "Deleting Topics"

TOPICS="clickhouse_connect_configs clickhouse_connect_offsets clickhouse_connect_status"

for topic in $TOPICS; do
    echo "Checking: $topic"

    if docker exec redpanda-clickhouse rpk topic describe $topic 2>/dev/null >/dev/null; then
        echo "  Deleting..."
        docker exec redpanda-clickhouse rpk topic delete $topic

        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Deleted $topic${NC}"
        else
            echo -e "  ${RED}✗ Failed to delete $topic${NC}"
        fi
    else
        echo -e "  ${YELLOW}Topic doesn't exist (skipping)${NC}"
    fi
    echo ""
done

print_section "Verification"

echo "Remaining topics:"
docker exec redpanda-clickhouse rpk topic list

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Now recreate Kafka Connect:"
echo "  docker stop kafka-connect-clickhouse"
echo "  docker rm kafka-connect-clickhouse"
echo "  cd /home/centos/clickhouse/phase2"
echo "  docker-compose up -d kafka-connect"
