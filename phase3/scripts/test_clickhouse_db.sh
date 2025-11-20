#!/bin/bash
# Simple test to check if analytics database exists

# Use docker exec instead of curl to avoid password issues
echo "Checking if analytics database exists..."

RESULT=$(docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query "SHOW DATABASES" 2>/dev/null | grep -c "analytics")

if [ "$RESULT" -gt 0 ]; then
    echo "✓ analytics database exists"

    # Count tables
    TABLE_COUNT=$(docker exec clickhouse-server clickhouse-client \
      --password 'ClickHouse_Secure_Pass_2024!' \
      --query "SELECT count() FROM system.tables WHERE database='analytics'" 2>/dev/null)

    echo "✓ Tables in analytics: $TABLE_COUNT"

    if [ "$TABLE_COUNT" -ge 450 ]; then
        echo "✓ Ready for Phase 3!"
        exit 0
    else
        echo "✗ Not enough tables (expected 450, got $TABLE_COUNT)"
        exit 1
    fi
else
    echo "✗ analytics database does NOT exist"
    exit 1
fi
