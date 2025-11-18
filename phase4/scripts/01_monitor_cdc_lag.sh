#!/bin/bash
# Phase 4 - Monitor CDC Lag Script
# Purpose: Monitor replication lag and pipeline health in real-time

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(dirname "$SCRIPT_DIR")"
PHASE3_DIR="$(dirname "$PHASE4_DIR")/phase3"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Configuration
CONNECT_URL="http://localhost:8085"
CLICKHOUSE_URL="http://localhost:8123"
MONITOR_INTERVAL=${MONITOR_INTERVAL_SECONDS:-30}
LAG_THRESHOLD=${ALERT_LAG_THRESHOLD:-300}  # 5 minutes in seconds

print_header() {
    clear
    echo "========================================"
    echo "   CDC Pipeline Monitoring Dashboard"
    echo "========================================"
    echo "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_connector_status() {
    local connector_name=$1
    local status=$(curl -s "$CONNECT_URL/connectors/$connector_name/status" | \
        python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
    echo "$status"
}

get_connector_tasks_count() {
    local connector_name=$1
    local tasks=$(curl -s "$CONNECT_URL/connectors/$connector_name/tasks" | \
        python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    echo "$tasks"
}

get_table_count_mysql() {
    local table=$1
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -D "$MYSQL_DATABASE" -N -e "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0"
}

get_table_count_clickhouse() {
    local table=$1
    curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "SELECT COUNT(*) FROM $CLICKHOUSE_DATABASE.$table" 2>/dev/null || echo "0"
}

get_latest_timestamp_clickhouse() {
    local table=$1
    curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "SELECT max(_extracted_at) FROM $CLICKHOUSE_DATABASE.$table" 2>/dev/null || echo "0"
}

calculate_lag() {
    local latest_ts=$1
    local current_ts=$(date +%s)
    local lag=$((current_ts - latest_ts))
    echo "$lag"
}

format_duration() {
    local seconds=$1
    if [ $seconds -lt 60 ]; then
        echo "${seconds}s"
    elif [ $seconds -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m"
    fi
}

monitor_loop() {
    while true; do
        print_header

        # 1. Check Connector Health
        echo -e "${CYAN}1. Connector Health${NC}"
        echo "-------------------"

        DEBEZIUM_STATUS=$(check_connector_status "mysql-source-connector")
        DEBEZIUM_TASKS=$(get_connector_tasks_count "mysql-source-connector")

        if [ "$DEBEZIUM_STATUS" = "RUNNING" ]; then
            print_status 0 "Debezium MySQL Source: $DEBEZIUM_STATUS ($DEBEZIUM_TASKS tasks)"
        else
            print_status 1 "Debezium MySQL Source: $DEBEZIUM_STATUS"
        fi

        SINK_STATUS=$(check_connector_status "clickhouse-sink-connector")
        SINK_TASKS=$(get_connector_tasks_count "clickhouse-sink-connector")

        if [ "$SINK_STATUS" = "RUNNING" ]; then
            print_status 0 "ClickHouse Sink: $SINK_STATUS ($SINK_TASKS tasks)"
        elif [ "$SINK_STATUS" = "UNKNOWN" ]; then
            print_warning "ClickHouse Sink: Not deployed (using alternative approach)"
        else
            print_status 1 "ClickHouse Sink: $SINK_STATUS"
        fi

        echo ""

        # 2. Replication Lag
        echo -e "${CYAN}2. Replication Lag${NC}"
        echo "-------------------"

        # Get sample tables to check lag
        SAMPLE_TABLES=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
            --data-binary "SELECT name FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' LIMIT 5" 2>/dev/null)

        TOTAL_LAG=0
        TABLE_COUNT=0
        MAX_LAG=0

        for table in $SAMPLE_TABLES; do
            LATEST_TS=$(get_latest_timestamp_clickhouse "$table")
            if [ "$LATEST_TS" != "0" ] && [ ! -z "$LATEST_TS" ]; then
                LAG=$(calculate_lag "$LATEST_TS")
                TOTAL_LAG=$((TOTAL_LAG + LAG))
                TABLE_COUNT=$((TABLE_COUNT + 1))

                if [ $LAG -gt $MAX_LAG ]; then
                    MAX_LAG=$LAG
                fi

                LAG_FORMATTED=$(format_duration $LAG)

                if [ $LAG -gt $LAG_THRESHOLD ]; then
                    echo -e "  ${RED}✗${NC} $table: ${RED}$LAG_FORMATTED lag${NC}"
                elif [ $LAG -gt 60 ]; then
                    echo -e "  ${YELLOW}⚠${NC} $table: ${YELLOW}$LAG_FORMATTED lag${NC}"
                else
                    echo -e "  ${GREEN}✓${NC} $table: ${GREEN}$LAG_FORMATTED lag${NC}"
                fi
            fi
        done

        if [ $TABLE_COUNT -gt 0 ]; then
            AVG_LAG=$((TOTAL_LAG / TABLE_COUNT))
            AVG_LAG_FORMATTED=$(format_duration $AVG_LAG)
            MAX_LAG_FORMATTED=$(format_duration $MAX_LAG)

            echo ""
            echo "  Average lag: $AVG_LAG_FORMATTED"
            echo "  Maximum lag: $MAX_LAG_FORMATTED"

            if [ $MAX_LAG -gt $LAG_THRESHOLD ]; then
                print_warning "Replication lag exceeds threshold (${LAG_THRESHOLD}s)!"
            fi
        else
            print_info "No data in ClickHouse yet"
        fi

        echo ""

        # 3. Data Statistics
        echo -e "${CYAN}3. Data Statistics${NC}"
        echo "-------------------"

        # Total tables
        TOTAL_TABLES=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
            --data-binary "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "0")

        echo "  Total tables: $TOTAL_TABLES"

        # Total rows
        TOTAL_ROWS=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
            --data-binary "SELECT formatReadableQuantity(sum(total_rows)) FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "0")

        echo "  Total rows: $TOTAL_ROWS"

        # Total size
        TOTAL_SIZE=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
            --data-binary "SELECT formatReadableSize(sum(total_bytes)) FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE'" 2>/dev/null || echo "0")

        echo "  Total size: $TOTAL_SIZE"

        echo ""

        # 4. Kafka Topics
        echo -e "${CYAN}4. Kafka Topics${NC}"
        echo "----------------"

        # Get topic list from Redpanda
        TOPICS=$(curl -s http://localhost:9644/v1/topics 2>/dev/null | \
            python3 -c "import sys, json; data=json.load(sys.stdin); print('\n'.join([t for t in data if t.startswith('mysql')]))" 2>/dev/null || echo "")

        if [ ! -z "$TOPICS" ]; then
            TOPIC_COUNT=$(echo "$TOPICS" | wc -l)
            echo "  Active topics: $TOPIC_COUNT"
            echo "  Sample topics:"
            echo "$TOPICS" | head -3 | sed 's/^/    - /'
        else
            print_warning "No Kafka topics found"
        fi

        echo ""

        # 5. System Resources
        echo -e "${CYAN}5. System Resources${NC}"
        echo "--------------------"

        # Docker container status
        CLICKHOUSE_RUNNING=$(docker ps --filter "name=clickhouse" --format "{{.Status}}" | grep -q "Up" && echo "1" || echo "0")
        REDPANDA_RUNNING=$(docker ps --filter "name=redpanda" --format "{{.Status}}" | grep -q "Up" && echo "1" || echo "0")
        CONNECT_RUNNING=$(docker ps --filter "name=kafka-connect" --format "{{.Status}}" | grep -q "Up" && echo "1" || echo "0")

        if [ $CLICKHOUSE_RUNNING -eq 1 ]; then
            print_status 0 "ClickHouse container: Running"
        else
            print_status 1 "ClickHouse container: Stopped"
        fi

        if [ $REDPANDA_RUNNING -eq 1 ]; then
            print_status 0 "Redpanda container: Running"
        else
            print_status 1 "Redpanda container: Stopped"
        fi

        if [ $CONNECT_RUNNING -eq 1 ]; then
            print_status 0 "Kafka Connect container: Running"
        else
            print_status 1 "Kafka Connect container: Stopped"
        fi

        # Disk usage
        DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        echo ""
        echo "  Disk usage: ${DISK_USAGE}%"

        if [ $DISK_USAGE -gt 90 ]; then
            print_warning "Disk usage critical (${DISK_USAGE}%)!"
        elif [ $DISK_USAGE -gt 80 ]; then
            print_warning "Disk usage high (${DISK_USAGE}%)"
        fi

        echo ""
        echo "========================================"
        echo "Next update in ${MONITOR_INTERVAL}s (Ctrl+C to exit)"
        echo ""

        sleep $MONITOR_INTERVAL
    done
}

# Main execution
echo "Starting CDC monitoring..."
echo "Press Ctrl+C to stop"
echo ""
sleep 2

monitor_loop
