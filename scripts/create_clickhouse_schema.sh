#!/bin/bash
# Create ClickHouse Schema - Execute all 450 table DDL files

set -e

# Load credentials from .env
source /home/centos/clickhouse/.env

CLICKHOUSE_USER=${CLICKHOUSE_USER:-default}
CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}

echo "Creating ClickHouse schema..."
echo "User: $CLICKHOUSE_USER"
echo ""

# Create mulasport database
echo "Creating mulasport database..."
curl -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
  "http://localhost:8123/" \
  -d "CREATE DATABASE IF NOT EXISTS mulasport"

echo "✓ Database created"
echo ""

# Execute all SQL files
SQL_DIR="/home/centos/clickhouse/schema_output/clickhouse_ddl"
TOTAL=$(ls -1 $SQL_DIR/*.sql | wc -l)
COUNT=0

echo "Creating $TOTAL tables..."

for sql_file in $SQL_DIR/*.sql; do
    COUNT=$((COUNT + 1))
    TABLE_NAME=$(basename "$sql_file" .sql)

    echo -n "[$COUNT/$TOTAL] Creating $TABLE_NAME... "

    curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
      "http://localhost:8123/" \
      --data-binary @"$sql_file"

    echo "✓"
done

echo ""
echo "✓ All $TOTAL tables created successfully!"
echo ""

# Verify
TABLE_COUNT=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
  "http://localhost:8123/?query=SELECT count() FROM system.tables WHERE database='mulasport'")

echo "Verification: $TABLE_COUNT tables in mulasport database"
