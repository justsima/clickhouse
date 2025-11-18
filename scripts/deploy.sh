#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "========================================="
echo "  MySQL to ClickHouse CDC Deployment"
echo "========================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo ""
echo "Step 1: Deploying infrastructure..."
echo "-----------------------------------"
docker-compose up -d

echo ""
echo "Waiting for services to be healthy (60 seconds)..."
sleep 60

echo ""
echo "Step 2: Checking service health..."
echo "-----------------------------------"
docker-compose ps

echo ""
echo "Step 3: Verifying Kafka Connect..."
echo "-----------------------------------"
curl -s http://localhost:8085/ | head -3

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Service URLs:"
echo "  - Redpanda Console:  http://localhost:8086"
echo "  - Kafka Connect API: http://localhost:8085"
echo "  - ClickHouse HTTP:   http://localhost:8123"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/analyze_schema.sh"
echo "  2. Run: ./scripts/create_tables.sh"
echo "  3. Run: ./scripts/deploy_connectors.sh"
echo ""
