#!/bin/bash
# Phase 3 - Comprehensive Snapshot Monitor
# Purpose: Real-time monitoring of MySQL to ClickHouse CDC pipeline

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CONNECT_URL="http://localhost:8083"
MONITOR_INTERVAL=10
EXPECTED_TOTAL_TABLES=450

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR: .env file not found at $PROJECT_ROOT/.env${NC}"
    exit 1
fi

# Helper functions
print_header() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}║ %-58s ║${NC}\n" "$1"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}▶ $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% (%d/%d)\n" "$percentage" "$current" "$total"
}

format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Data collection functions
get_connector_status() {
    local connector="$1"
    curl -s "$CONNECT_URL/connectors/$connector/status" 2>/dev/null
}

get_connector_config() {
    local connector="$1"
    curl -s "$CONNECT_URL/connectors/$connector" 2>/dev/null
}

get_topic_count() {
    docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep "^mysql\." | wc -l
}

get_clickhouse_stats() {
    docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "$1" 2>/dev/null
}

# Initialize tracking
START_TIME=$(date +%s)
PREV_ROWS=0
PREV_TOPICS=0
PREV_TIME=$START_TIME

clear
echo -e "${BOLD}${GREEN}Starting CDC Pipeline Monitor...${NC}"
echo "Press Ctrl+C to stop monitoring"
sleep 2

while true; do
    clear

    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    print_header "MySQL → ClickHouse CDC Pipeline Monitor"

    echo ""
    echo -e "  ${CYAN}Started:${NC} $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')"
    echo -e "  ${CYAN}Elapsed:${NC} $(format_duration $ELAPSED)"
    echo -e "  ${CYAN}Current:${NC} $(date '+%Y-%m-%d %H:%M:%S')"

    # ============================================================
    # CONNECTOR STATUS
    # ============================================================
    print_section "Connector Status"

    # MySQL Source Connector
    MYSQL_STATUS=$(get_connector_status "mysql-source-connector")
    MYSQL_STATE=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('connector',{}).get('state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    MYSQL_WORKER=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('connector',{}).get('worker_id','N/A'))" 2>/dev/null || echo "N/A")

    echo -n "  MySQL Source Connector: "
    if [ "$MYSQL_STATE" = "RUNNING" ]; then
        echo -e "${GREEN}${BOLD}RUNNING${NC}"
    elif [ "$MYSQL_STATE" = "FAILED" ]; then
        echo -e "${RED}${BOLD}FAILED${NC}"
    else
        echo -e "${YELLOW}${BOLD}$MYSQL_STATE${NC}"
    fi
    echo -e "    Worker: $MYSQL_WORKER"

    # MySQL Source Tasks
    MYSQL_TASKS=$(echo "$MYSQL_STATUS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tasks = data.get('tasks', [])
print(len(tasks))
for task in tasks:
    print(f\"{task.get('id','?')}|{task.get('state','?')}|{task.get('worker_id','?')}\")
" 2>/dev/null)

    MYSQL_TASK_COUNT=$(echo "$MYSQL_TASKS" | head -1)
    MYSQL_RUNNING_TASKS=$(echo "$MYSQL_TASKS" | tail -n +2 | grep -c "RUNNING" || echo "0")
    MYSQL_EXPECTED_TASKS=$(get_connector_config "mysql-source-connector" | python3 -c "import sys,json; print(json.load(sys.stdin).get('config',{}).get('tasks.max','1'))" 2>/dev/null || echo "1")

    echo -n "    Tasks: "
    if [ "$MYSQL_RUNNING_TASKS" -eq "$MYSQL_EXPECTED_TASKS" ] && [ "$MYSQL_RUNNING_TASKS" -gt 0 ]; then
        echo -e "${GREEN}${MYSQL_RUNNING_TASKS}/${MYSQL_EXPECTED_TASKS} RUNNING${NC}"
    elif [ "$MYSQL_TASK_COUNT" -eq 0 ]; then
        echo -e "${RED}${BOLD}0/${MYSQL_EXPECTED_TASKS} (NO TASKS CREATED!)${NC}"
        echo -e "    ${RED}⚠ WARNING: Source connector has no tasks!${NC}"
        echo -e "    ${YELLOW}Snapshot cannot proceed without tasks.${NC}"
    else
        echo -e "${YELLOW}${MYSQL_RUNNING_TASKS}/${MYSQL_EXPECTED_TASKS}${NC}"
    fi

    # Show individual task details
    if [ "$MYSQL_TASK_COUNT" -gt 0 ]; then
        echo "$MYSQL_TASKS" | tail -n +2 | while IFS='|' read -r task_id task_state task_worker; do
            echo -n "      Task $task_id: "
            if [ "$task_state" = "RUNNING" ]; then
                echo -e "${GREEN}$task_state${NC} (worker: $task_worker)"
            elif [ "$task_state" = "FAILED" ]; then
                echo -e "${RED}$task_state${NC} (worker: $task_worker)"
            else
                echo -e "${YELLOW}$task_state${NC} (worker: $task_worker)"
            fi
        done
    fi

    echo ""

    # ClickHouse Sink Connector
    SINK_STATUS=$(get_connector_status "clickhouse-sink-connector")
    SINK_STATE=$(echo "$SINK_STATUS" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('connector',{}).get('state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    SINK_WORKER=$(echo "$SINK_STATUS" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('connector',{}).get('worker_id','N/A'))" 2>/dev/null || echo "N/A")

    echo -n "  ClickHouse Sink Connector: "
    if [ "$SINK_STATE" = "RUNNING" ]; then
        echo -e "${GREEN}${BOLD}RUNNING${NC}"
    elif [ "$SINK_STATE" = "FAILED" ]; then
        echo -e "${RED}${BOLD}FAILED${NC}"
    else
        echo -e "${YELLOW}${BOLD}$SINK_STATE${NC}"
    fi
    echo -e "    Worker: $SINK_WORKER"

    # ClickHouse Sink Tasks
    SINK_TASKS=$(echo "$SINK_STATUS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tasks = data.get('tasks', [])
print(len(tasks))
for task in tasks:
    print(f\"{task.get('id','?')}|{task.get('state','?')}|{task.get('worker_id','?')}\")
" 2>/dev/null)

    SINK_TASK_COUNT=$(echo "$SINK_TASKS" | head -1)
    SINK_RUNNING_TASKS=$(echo "$SINK_TASKS" | tail -n +2 | grep -c "RUNNING" || echo "0")
    SINK_FAILED_TASKS=$(echo "$SINK_TASKS" | tail -n +2 | grep -c "FAILED" || echo "0")
    SINK_EXPECTED_TASKS=$(get_connector_config "clickhouse-sink-connector" | python3 -c "import sys,json; print(json.load(sys.stdin).get('config',{}).get('tasks.max','4'))" 2>/dev/null || echo "4")

    echo -n "    Tasks: "
    if [ "$SINK_RUNNING_TASKS" -eq "$SINK_EXPECTED_TASKS" ] && [ "$SINK_RUNNING_TASKS" -gt 0 ]; then
        echo -e "${GREEN}${SINK_RUNNING_TASKS}/${SINK_EXPECTED_TASKS} RUNNING${NC}"
    elif [ "$SINK_FAILED_TASKS" -gt 0 ]; then
        echo -e "${RED}${SINK_RUNNING_TASKS}/${SINK_EXPECTED_TASKS} (${SINK_FAILED_TASKS} FAILED)${NC}"
    else
        echo -e "${YELLOW}${SINK_RUNNING_TASKS}/${SINK_EXPECTED_TASKS}${NC}"
    fi

    # Show individual task details
    if [ "$SINK_TASK_COUNT" -gt 0 ]; then
        echo "$SINK_TASKS" | tail -n +2 | while IFS='|' read -r task_id task_state task_worker; do
            echo -n "      Task $task_id: "
            if [ "$task_state" = "RUNNING" ]; then
                echo -e "${GREEN}$task_state${NC} (worker: $task_worker)"
            elif [ "$task_state" = "FAILED" ]; then
                echo -e "${RED}$task_state${NC} (worker: $task_worker)"
            else
                echo -e "${YELLOW}$task_state${NC} (worker: $task_worker)"
            fi
        done
    fi

    # ============================================================
    # KAFKA TOPICS
    # ============================================================
    print_section "Kafka Topics (Redpanda)"

    TOPIC_COUNT=$(get_topic_count)
    TOPIC_PERCENTAGE=$((TOPIC_COUNT * 100 / EXPECTED_TOTAL_TABLES))

    echo -e "  Topics Created: ${BOLD}$TOPIC_COUNT${NC} / $EXPECTED_TOTAL_TABLES"
    print_progress_bar "$TOPIC_COUNT" "$EXPECTED_TOTAL_TABLES"

    # Calculate topic creation rate
    TIME_DELTA=$((CURRENT_TIME - PREV_TIME))
    if [ "$TIME_DELTA" -gt 0 ]; then
        TOPIC_DELTA=$((TOPIC_COUNT - PREV_TOPICS))
        TOPICS_PER_MIN=$(echo "scale=1; $TOPIC_DELTA * 60 / $TIME_DELTA" | bc 2>/dev/null || echo "0")

        if [ "$TOPIC_COUNT" -gt 0 ] && [ "$TOPIC_COUNT" -lt "$EXPECTED_TOTAL_TABLES" ]; then
            REMAINING_TOPICS=$((EXPECTED_TOTAL_TABLES - TOPIC_COUNT))
            if [ $(echo "$TOPICS_PER_MIN > 0" | bc 2>/dev/null) -eq 1 ]; then
                ETA_MINUTES=$(echo "scale=0; $REMAINING_TOPICS / $TOPICS_PER_MIN" | bc 2>/dev/null || echo "?")
                echo -e "  Rate: ${CYAN}${TOPICS_PER_MIN} topics/min${NC}"
                echo -e "  ETA: ${CYAN}~${ETA_MINUTES} minutes${NC} remaining"
            fi
        elif [ "$TOPIC_COUNT" -gt 0 ]; then
            echo -e "  Rate: ${CYAN}${TOPICS_PER_MIN} topics/min${NC}"
        fi
    fi

    # Show sample topics
    if [ "$TOPIC_COUNT" -gt 0 ]; then
        echo ""
        echo "  Sample topics:"
        docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep "^mysql\." | head -5 | while read -r topic rest; do
            echo "    • $topic"
        done
        if [ "$TOPIC_COUNT" -gt 5 ]; then
            echo "    ... and $((TOPIC_COUNT - 5)) more"
        fi
    fi

    # ============================================================
    # CLICKHOUSE DATA
    # ============================================================
    print_section "ClickHouse Analytics Database"

    # Get ClickHouse statistics
    CH_STATS=$(get_clickhouse_stats "
        SELECT
            COUNT(*) as total_tables,
            SUM(CASE WHEN total_rows > 0 THEN 1 ELSE 0 END) as populated_tables,
            SUM(CASE WHEN total_rows = 0 THEN 1 ELSE 0 END) as empty_tables,
            SUM(total_rows) as total_rows,
            SUM(total_bytes) as total_bytes
        FROM system.tables
        WHERE database = 'analytics'
        FORMAT TabSeparated
    ")

    if [ -n "$CH_STATS" ]; then
        CH_TOTAL_TABLES=$(echo "$CH_STATS" | cut -f1)
        CH_POPULATED=$(echo "$CH_STATS" | cut -f2)
        CH_EMPTY=$(echo "$CH_STATS" | cut -f3)
        CH_TOTAL_ROWS=$(echo "$CH_STATS" | cut -f4)
        CH_TOTAL_BYTES=$(echo "$CH_STATS" | cut -f5)

        echo -e "  Total Tables: ${BOLD}$CH_TOTAL_TABLES${NC}"
        echo -e "  Tables with Data: ${GREEN}$CH_POPULATED${NC}"
        echo -e "  Empty Tables: ${YELLOW}$CH_EMPTY${NC}"

        echo ""
        print_progress_bar "$CH_POPULATED" "$CH_TOTAL_TABLES"

        echo ""
        echo -e "  Total Rows: ${BOLD}$(format_number $CH_TOTAL_ROWS)${NC}"

        # Format bytes to human readable
        if [ "$CH_TOTAL_BYTES" -gt 0 ]; then
            CH_SIZE_MB=$((CH_TOTAL_BYTES / 1024 / 1024))
            CH_SIZE_GB=$(echo "scale=2; $CH_TOTAL_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
            if [ "$CH_SIZE_MB" -gt 1024 ]; then
                echo -e "  Total Size: ${BOLD}${CH_SIZE_GB} GB${NC}"
            else
                echo -e "  Total Size: ${BOLD}${CH_SIZE_MB} MB${NC}"
            fi
        fi

        # Calculate insertion rate
        if [ "$PREV_ROWS" -gt 0 ] && [ "$TIME_DELTA" -gt 0 ]; then
            ROWS_DELTA=$((CH_TOTAL_ROWS - PREV_ROWS))
            ROWS_PER_SEC=$((ROWS_DELTA / TIME_DELTA))

            if [ "$ROWS_PER_SEC" -gt 0 ]; then
                echo -e "  Insertion Rate: ${GREEN}$(format_number $ROWS_PER_SEC) rows/sec${NC}"
            else
                echo -e "  Insertion Rate: ${YELLOW}0 rows/sec${NC} (may be between batches)"
            fi
        fi

        # Top 10 tables by row count
        if [ "$CH_POPULATED" -gt 0 ]; then
            echo ""
            echo "  Top 10 Tables by Row Count:"
            get_clickhouse_stats "
                SELECT
                    name,
                    formatReadableQuantity(total_rows) as rows,
                    formatReadableSize(total_bytes) as size
                FROM system.tables
                WHERE database = 'analytics' AND total_rows > 0
                ORDER BY total_rows DESC
                LIMIT 10
                FORMAT PrettyCompact
            " | sed 's/^/    /'
        fi

        # Update previous values
        PREV_ROWS=$CH_TOTAL_ROWS
    else
        echo -e "  ${YELLOW}⚠ Unable to fetch ClickHouse statistics${NC}"
        echo "  Ensure ClickHouse is running and accessible"
    fi

    # ============================================================
    # ERRORS & WARNINGS
    # ============================================================
    HAS_ISSUES=0

    # Check for errors in connectors
    MYSQL_ERRORS=$(echo "$MYSQL_STATUS" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='FAILED'))" 2>/dev/null || echo "0")
    SINK_ERRORS=$(echo "$SINK_STATUS" | python3 -c "import sys,json; tasks=json.load(sys.stdin).get('tasks',[]); print(sum(1 for t in tasks if t.get('state')=='FAILED'))" 2>/dev/null || echo "0")

    if [ "$MYSQL_TASK_COUNT" -eq 0 ] || [ "$MYSQL_ERRORS" -gt 0 ] || [ "$SINK_ERRORS" -gt 0 ]; then
        HAS_ISSUES=1
        print_section "⚠ Issues Detected"

        if [ "$MYSQL_TASK_COUNT" -eq 0 ]; then
            echo -e "  ${RED}✗ MySQL source connector has NO TASKS${NC}"
            echo "    This means the snapshot cannot start."
            echo "    Possible causes:"
            echo "      • MySQL binlog not enabled"
            echo "      • Missing MySQL user permissions (REPLICATION SLAVE/CLIENT)"
            echo "      • MySQL connectivity issues"
            echo ""
            echo "    ${YELLOW}Run: ./diagnose_mysql_connector.sh to identify the issue${NC}"
        fi

        if [ "$MYSQL_ERRORS" -gt 0 ]; then
            echo -e "  ${RED}✗ MySQL connector has $MYSQL_ERRORS failed task(s)${NC}"
            echo "    Check error trace:"
            echo "    curl -s http://localhost:8083/connectors/mysql-source-connector/status | python3 -m json.tool"
        fi

        if [ "$SINK_ERRORS" -gt 0 ]; then
            echo -e "  ${RED}✗ ClickHouse sink has $SINK_ERRORS failed task(s)${NC}"
            echo "    Check error trace:"
            echo "    curl -s http://localhost:8083/connectors/clickhouse-sink-connector/status | python3 -m json.tool"
        fi

        echo ""
        echo "  Recent errors from Kafka Connect logs:"
        docker logs kafka-connect-clickhouse 2>&1 | grep -i "error\|exception" | tail -5 | sed 's/^/    /' || echo "    (no recent errors in logs)"
    fi

    # ============================================================
    # COMPLETION CHECK
    # ============================================================
    if [ "$TOPIC_COUNT" -ge "$EXPECTED_TOTAL_TABLES" ] && [ "$CH_POPULATED" -ge "$((EXPECTED_TOTAL_TABLES - 10))" ]; then
        print_section "✓ Snapshot Complete!"

        echo -e "  ${GREEN}${BOLD}All tables have been snapshotted successfully!${NC}"
        echo ""
        echo "  Final Statistics:"
        echo "    • Topics created: $TOPIC_COUNT"
        echo "    • Tables populated: $CH_POPULATED"
        echo "    • Total rows: $(format_number $CH_TOTAL_ROWS)"
        echo "    • Total time: $(format_duration $ELAPSED)"
        echo ""
        echo "  ${CYAN}The pipeline is now in CDC mode (real-time replication).${NC}"
        echo ""
        echo "  Next steps:"
        echo "    1. Verify data accuracy with sample queries"
        echo "    2. Test CDC by making changes in MySQL"
        echo "    3. Monitor for ongoing errors"
        echo ""

        read -t 30 -p "Press Enter to exit or wait 30 seconds..." || true
        exit 0
    fi

    # ============================================================
    # SUMMARY
    # ============================================================
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ "$HAS_ISSUES" -eq 1 ]; then
        echo -e "  ${RED}Status: ISSUES DETECTED - Review warnings above${NC}"
    elif [ "$MYSQL_RUNNING_TASKS" -gt 0 ] && [ "$TOPIC_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}Status: Snapshot in progress ($(format_duration $ELAPSED) elapsed)${NC}"
    elif [ "$MYSQL_RUNNING_TASKS" -gt 0 ]; then
        echo -e "  ${YELLOW}Status: Connector running, waiting for first topic...${NC}"
    else
        echo -e "  ${YELLOW}Status: Waiting for connectors to start...${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Update tracking variables
    PREV_TOPICS=$TOPIC_COUNT
    PREV_TIME=$CURRENT_TIME

    echo ""
    echo "Next update in $MONITOR_INTERVAL seconds... (Ctrl+C to stop)"
    sleep $MONITOR_INTERVAL
done
