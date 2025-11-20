#!/bin/bash
# Phase 1 - Network Validation Script
# Purpose: Test network connectivity and throughput between VPS and MySQL

set -e

# Load environment variables from main .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE1_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    echo "Please ensure the main .env file exists with MySQL credentials"
    exit 1
fi

echo "========================================"
echo "   Network Validation & Throughput Test"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 1. Basic connectivity test
echo "1. Testing MySQL Connectivity"
echo "------------------------------"
echo "Target: ${MYSQL_HOST}:${MYSQL_PORT}"
echo ""

# Test TCP connection
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${MYSQL_HOST}/${MYSQL_PORT}" 2>/dev/null; then
    print_status 0 "TCP connection successful"
else
    print_status 1 "Cannot establish TCP connection"
    echo ""
    echo "Possible issues:"
    echo "  - Firewall blocking connection"
    echo "  - MySQL host unreachable"
    echo "  - Incorrect host/port in .env"
    exit 1
fi

# Measure latency
echo ""
echo "Measuring latency..."
if command -v ping &> /dev/null; then
    # Extract hostname from connection string if needed
    MYSQL_IP=$(getent hosts ${MYSQL_HOST} | awk '{ print $1 }' | head -n1)
    if [ -n "$MYSQL_IP" ]; then
        echo "Resolved ${MYSQL_HOST} to ${MYSQL_IP}"

        # Ping test (3 packets)
        PING_RESULT=$(ping -c 3 -q ${MYSQL_IP} 2>/dev/null || echo "FAILED")

        if [ "$PING_RESULT" != "FAILED" ]; then
            AVG_LATENCY=$(echo "$PING_RESULT" | grep "rtt min/avg/max" | cut -d'/' -f5)
            echo "Average latency: ${AVG_LATENCY} ms"

            # Convert to integer for comparison
            AVG_LATENCY_INT=$(echo "$AVG_LATENCY" | cut -d'.' -f1)

            if [ "$AVG_LATENCY_INT" -lt 50 ]; then
                print_status 0 "Latency excellent (<50ms)"
            elif [ "$AVG_LATENCY_INT" -lt 100 ]; then
                print_status 0 "Latency good (<100ms)"
            else
                print_warning "Latency high (>100ms) - may impact initial snapshot time"
            fi
        else
            print_warning "Ping test failed (ICMP may be blocked)"
        fi
    else
        print_warning "Cannot resolve hostname for ping test"
    fi
else
    print_warning "ping command not available"
fi
echo ""

# 2. MySQL connection time test
echo "2. Testing MySQL Connection Performance"
echo "----------------------------------------"
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"

echo "Running 5 connection tests..."
TOTAL_TIME=0
SUCCESS_COUNT=0

for i in {1..5}; do
    START=$(date +%s%3N)
    if $MYSQL_CMD -e "SELECT 1;" &> /dev/null; then
        END=$(date +%s%3N)
        ELAPSED=$((END - START))
        echo "  Test $i: ${ELAPSED}ms"
        TOTAL_TIME=$((TOTAL_TIME + ELAPSED))
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "  Test $i: FAILED"
    fi
done

if [ $SUCCESS_COUNT -eq 5 ]; then
    AVG_CONN_TIME=$((TOTAL_TIME / 5))
    echo ""
    echo "Average connection time: ${AVG_CONN_TIME}ms"

    if [ $AVG_CONN_TIME -lt 100 ]; then
        print_status 0 "Connection time excellent"
    elif [ $AVG_CONN_TIME -lt 500 ]; then
        print_status 0 "Connection time acceptable"
    else
        print_warning "Connection time slow (>500ms)"
    fi
else
    print_warning "Some connection tests failed (${SUCCESS_COUNT}/5)"
fi
echo ""

# 3. Throughput test (query large dataset)
echo "3. Testing Data Transfer Throughput"
echo "------------------------------------"

if [ -n "$MYSQL_DATABASE" ]; then
    echo "Querying sample data from '${MYSQL_DATABASE}'..."
    echo ""

    # Get a table with data
    SAMPLE_TABLE=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DATABASE}' AND TABLE_ROWS > 0 ORDER BY TABLE_ROWS DESC LIMIT 1;" -sN 2>/dev/null || echo "")

    if [ -n "$SAMPLE_TABLE" ]; then
        echo "Using table: ${SAMPLE_TABLE}"

        # Count rows
        ROW_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.${SAMPLE_TABLE};" -sN 2>/dev/null || echo "0")
        echo "Rows in table: ${ROW_COUNT}"

        # Time a SELECT query
        echo ""
        echo "Fetching sample data (limited to 10,000 rows)..."
        START=$(date +%s%3N)
        RESULT=$($MYSQL_CMD -e "SELECT * FROM ${MYSQL_DATABASE}.${SAMPLE_TABLE} LIMIT 10000;" 2>/dev/null || echo "")
        END=$(date +%s%3N)
        ELAPSED=$((END - START))

        if [ -n "$RESULT" ]; then
            RESULT_SIZE=$(echo "$RESULT" | wc -c)
            SIZE_KB=$((RESULT_SIZE / 1024))
            SIZE_MB=$(echo "scale=2; $RESULT_SIZE / 1024 / 1024" | bc)

            echo "Data transferred: ${SIZE_MB} MB"
            echo "Time taken: ${ELAPSED}ms"

            if [ $ELAPSED -gt 0 ]; then
                THROUGHPUT=$(echo "scale=2; $SIZE_MB * 1000 / $ELAPSED" | bc)
                echo "Throughput: ${THROUGHPUT} MB/s"

                # Convert to Mbps
                THROUGHPUT_MBPS=$(echo "scale=2; $THROUGHPUT * 8" | bc)
                echo "Throughput: ${THROUGHPUT_MBPS} Mbps"

                MIN_THROUGHPUT=${EXPECTED_MIN_THROUGHPUT_MBPS:-10}
                THROUGHPUT_INT=$(echo "$THROUGHPUT_MBPS" | cut -d'.' -f1)

                if [ "$THROUGHPUT_INT" -ge "$MIN_THROUGHPUT" ]; then
                    print_status 0 "Throughput sufficient for CDC workload"
                else
                    print_warning "Throughput below expected minimum (${MIN_THROUGHPUT} Mbps)"
                fi
            else
                print_warning "Transfer too fast to measure accurately (< 1ms)"
            fi
        else
            print_warning "No data returned from query"
        fi
    else
        print_warning "No tables with data found in ${MYSQL_DATABASE}"
        echo "Skipping throughput test"
    fi
else
    print_warning "MYSQL_DATABASE not set - skipping throughput test"
fi
echo ""

# 4. Test binlog position read
echo "4. Testing Binlog Access"
echo "------------------------"
BINLOG_STATUS=$($MYSQL_CMD -e "SHOW MASTER STATUS;" 2>/dev/null || echo "")

if [ -n "$BINLOG_STATUS" ]; then
    echo "Current binlog position:"
    echo "$BINLOG_STATUS"
    echo ""
    print_status 0 "Can read binlog position (required for Debezium)"
else
    print_status 1 "Cannot read binlog position"
    echo "This may indicate:"
    echo "  - Binary logging not enabled"
    echo "  - Insufficient privileges"
fi
echo ""

# 5. Concurrent connection test
echo "5. Testing Concurrent Connections"
echo "----------------------------------"
echo "Debezium will maintain multiple connections during CDC"
echo "Testing 5 concurrent connections..."
echo ""

CONCURRENT_SUCCESS=0
for i in {1..5}; do
    ($MYSQL_CMD -e "SELECT SLEEP(1), CONNECTION_ID();" &> /dev/null) &
done

# Wait for all background jobs
wait

CONCURRENT_SUCCESS=$?
if [ $CONCURRENT_SUCCESS -eq 0 ]; then
    print_status 0 "Concurrent connections successful"
else
    print_warning "Some concurrent connections failed"
fi
echo ""

# 6. Estimate snapshot time
echo "6. Initial Snapshot Time Estimate"
echo "----------------------------------"

if [ -n "$MYSQL_DATABASE" ] && [ -n "$SIZE_MB" ] && [ -n "$THROUGHPUT" ]; then
    # Get total database size
    TOTAL_DB_SIZE=$($MYSQL_CMD -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DATABASE}';" -sN)

    echo "Total database size: ${TOTAL_DB_SIZE} MB"

    if [ -n "$TOTAL_DB_SIZE" ] && [ "$THROUGHPUT" != "0" ]; then
        ESTIMATED_TIME=$(echo "scale=2; $TOTAL_DB_SIZE / $THROUGHPUT / 60" | bc)
        echo "Estimated snapshot time: ${ESTIMATED_TIME} minutes"
        echo ""

        ESTIMATED_TIME_INT=$(echo "$ESTIMATED_TIME" | cut -d'.' -f1)

        if [ "$ESTIMATED_TIME_INT" -lt 30 ]; then
            print_status 0 "Snapshot time should be acceptable (<30 min)"
        elif [ "$ESTIMATED_TIME_INT" -lt 120 ]; then
            print_warning "Snapshot may take 30min-2hrs. Consider bulk backfill for faster initial load."
        else
            print_warning "Snapshot will take >2hrs. Strongly recommend bulk backfill approach."
        fi
    fi
fi
echo ""

# Save report
echo "7. Saving Network Validation Report"
echo "------------------------------------"
REPORT_FILE="/home/user/clickhouse/phase1/network_validation_report.txt"
{
    echo "=== Network Validation Report ==="
    echo "Date: $(date)"
    echo ""
    echo "MySQL Host: ${MYSQL_HOST}:${MYSQL_PORT}"
    echo ""
    echo "Latency: ${AVG_LATENCY:-N/A} ms"
    echo "Average Connection Time: ${AVG_CONN_TIME:-N/A} ms"
    echo "Throughput: ${THROUGHPUT_MBPS:-N/A} Mbps"
    echo ""
    echo "Database Size: ${TOTAL_DB_SIZE:-N/A} MB"
    echo "Estimated Snapshot Time: ${ESTIMATED_TIME:-N/A} minutes"
    echo ""
    echo "Status:"
    if [ $SUCCESS_COUNT -eq 5 ] && [ -n "$BINLOG_STATUS" ]; then
        echo "  ✓ Network ready for CDC"
    else
        echo "  ⚠ Review issues above"
    fi
} > "$REPORT_FILE"

print_status 0 "Report saved to $REPORT_FILE"
echo ""

# Final summary
echo "========================================"
echo "   Network Validation Summary"
echo "========================================"
echo ""

if [ $SUCCESS_COUNT -eq 5 ] && [ -n "$BINLOG_STATUS" ]; then
    echo -e "${GREEN}✓ Network validation passed${NC}"
    echo ""
    echo "Your VPS can reliably connect to MySQL for CDC operations."
    echo ""
    echo "Next steps:"
    echo "  - Review the full Phase 1 documentation"
    echo "  - Proceed to Phase 2: Service Deployment"
else
    echo -e "${YELLOW}⚠ Network validation completed with warnings${NC}"
    echo ""
    echo "Review the issues above before proceeding."
    echo "Most warnings won't block CDC, but may impact performance."
fi
echo ""
