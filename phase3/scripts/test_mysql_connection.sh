#!/bin/bash
# Test MySQL Connection for Validation Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

echo "Testing MySQL connection..."
echo ""

# Test connection
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --ssl-mode=REQUIRED \
    -N -e "SELECT 'Connection successful!' as status, COUNT(*) as table_count FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$MYSQL_DATABASE' AND TABLE_TYPE = 'BASE TABLE'" 2>&1

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ MySQL connection works correctly"
else
    echo "✗ MySQL connection failed"
    echo ""
    echo "If you see 'Using a password on the command line interface can be insecure.'"
    echo "that's just a warning - it still works."
fi

exit $EXIT_CODE
