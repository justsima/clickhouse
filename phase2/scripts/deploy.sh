#!/bin/bash
# Phase 2 - Deploy Services Script
# Purpose: Deploy Redpanda, Kafka Connect, ClickHouse, and Redpanda Console

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "========================================"
echo "   Phase 2: Service Deployment"
echo "========================================"
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}ERROR: Docker is not running${NC}"
    echo "Please start Docker first: sudo systemctl start docker"
    exit 1
fi
print_status 0 "Docker is running"

# Check if Docker Compose is available
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    print_status 0 "Docker Compose available (plugin)"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    print_status 0 "Docker Compose available (standalone)"
else
    echo -e "${RED}ERROR: Docker Compose not found${NC}"
    exit 1
fi

echo ""
echo "Step 1: Loading Environment Variables"
echo "--------------------------------------"

# Load .env from phase1
ENV_FILE="${PHASE2_DIR}/../phase1/configs/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    print_status 0 "Loaded environment variables from phase1"
else
    print_warning ".env file not found, using defaults"
fi

# Export ClickHouse password
export CLICKHOUSE_USER=${CLICKHOUSE_USER:-default}
export CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}

echo ""
echo "Step 2: Checking Port Availability"
echo "-----------------------------------"

check_port() {
    PORT=$1
    NAME=$2
    if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        print_warning "Port $PORT ($NAME) already in use"
        return 1
    else
        print_status 0 "Port $PORT ($NAME) available"
        return 0
    fi
}

PORTS_OK=1
check_port 9093 "Redpanda Kafka" || PORTS_OK=0
check_port 8081 "Schema Registry" || PORTS_OK=0
check_port 8082 "HTTP Proxy" || PORTS_OK=0
check_port 9644 "Redpanda Admin" || PORTS_OK=0
check_port 8085 "Kafka Connect" || PORTS_OK=0
check_port 8086 "Redpanda Console" || PORTS_OK=0
check_port 9000 "ClickHouse Native" || PORTS_OK=0
check_port 8123 "ClickHouse HTTP" || PORTS_OK=0

if [ $PORTS_OK -eq 0 ]; then
    echo ""
    read -p "Some ports are in use. Continue anyway? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        echo "Deployment cancelled."
        exit 1
    fi
fi

echo ""
echo "Step 3: Stopping Existing Services (if any)"
echo "--------------------------------------------"

cd "$PHASE2_DIR"

if $COMPOSE_CMD ps | grep -q "clickhouse-server\|redpanda-clickhouse\|kafka-connect-clickhouse"; then
    print_info "Stopping existing services..."
    $COMPOSE_CMD down
    print_status 0 "Existing services stopped"
else
    print_info "No existing services to stop"
fi

echo ""
echo "Step 4: Pulling Docker Images"
echo "------------------------------"

print_info "This may take several minutes on first run..."
$COMPOSE_CMD pull

print_status 0 "Docker images pulled"

echo ""
echo "Step 5: Starting Services"
echo "-------------------------"

print_info "Starting services in detached mode..."
$COMPOSE_CMD up -d

echo ""
echo "Step 6: Waiting for Services to be Healthy"
echo "-------------------------------------------"

print_info "Waiting for Redpanda..."
RETRY=0
MAX_RETRIES=30
while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker exec redpanda-clickhouse rpk cluster health 2>/dev/null | grep -q "Healthy:.*true"; then
        print_status 0 "Redpanda is healthy"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    print_warning "Redpanda health check timeout (may still be starting)"
fi

echo ""
print_info "Waiting for Kafka Connect..."
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8085/ &> /dev/null; then
        print_status 0 "Kafka Connect is healthy"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    print_warning "Kafka Connect health check timeout (may still be starting)"
fi

echo ""
print_info "Waiting for ClickHouse..."
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8123/ping &> /dev/null; then
        print_status 0 "ClickHouse is healthy"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    print_warning "ClickHouse health check timeout (may still be starting)"
fi

echo ""
echo "========================================"
echo "   Deployment Summary"
echo "========================================"
echo ""

# Check service status
echo "Service Status:"
$COMPOSE_CMD ps

echo ""
echo "Service URLs:"
echo "  Redpanda Console:  http://localhost:8086"
echo "  Kafka Connect API: http://localhost:8085"
echo "  ClickHouse HTTP:   http://localhost:8123"
echo "  ClickHouse Native: localhost:9000"
echo ""

echo "Access ClickHouse:"
echo "  docker exec -it clickhouse-server clickhouse-client"
echo "  or"
echo "  clickhouse-client --host localhost --port 9000 --user default --password '${CLICKHOUSE_PASSWORD}'"
echo ""

echo "View Logs:"
echo "  All services:  $COMPOSE_CMD logs -f"
echo "  Redpanda:      $COMPOSE_CMD logs -f redpanda"
echo "  Kafka Connect: $COMPOSE_CMD logs -f kafka-connect"
echo "  ClickHouse:    $COMPOSE_CMD logs -f clickhouse"
echo "  Console:       $COMPOSE_CMD logs -f redpanda-console"
echo ""

echo "Next Steps:"
echo "  1. Verify all services are running: ./health_check.sh"
echo "  2. Create ClickHouse tables (Phase 3)"
echo "  3. Configure Debezium connectors (Phase 3)"
echo ""

print_status 0 "Phase 2 deployment complete!"
echo ""
