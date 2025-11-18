#!/bin/bash
# Phase 3 - MySQL Schema Analysis Script
# Purpose: Analyze MySQL database and generate ClickHouse DDL

# Don't exit on error - we'll handle errors explicitly
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT"
OUTPUT_DIR="$PROJECT_ROOT/schema_output"

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

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

echo "========================================"
echo "   MySQL Schema Analysis"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    print_error ".env file not found at $CONFIG_DIR/.env"
    echo "Run: cp $CONFIG_DIR/.env.example $CONFIG_DIR/.env"
    exit 1
fi

# Check for Python
echo "0. Checking Prerequisites"
echo "-------------------------"

if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    print_status 0 "Python 3 found: $(python3 --version)"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    PYTHON_VERSION=$(python --version 2>&1)
    if echo "$PYTHON_VERSION" | grep -q "Python 3"; then
        print_status 0 "Python found: $PYTHON_VERSION"
    else
        print_error "Python 3 is required but found: $PYTHON_VERSION"
        echo "Install: sudo yum install -y python3"
        exit 1
    fi
else
    print_error "Python 3 is not installed"
    echo "Install: sudo yum install -y python3"
    exit 1
fi

echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/mysql_ddl"
mkdir -p "$OUTPUT_DIR/clickhouse_ddl"

# MySQL connection command
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}"

echo "1. Testing MySQL Connection"
echo "----------------------------"
if $MYSQL_CMD -e "SELECT 1;" 2>/dev/null 1>/dev/null; then
    print_status 0 "MySQL connection successful"
else
    print_status 1 "MySQL connection failed"
    echo "Check credentials in $CONFIG_DIR/.env"
    exit 1
fi

echo ""
echo "2. Fetching Table List"
echo "----------------------"

# Get list of all tables
TABLES=$($MYSQL_CMD -N -e "SHOW TABLES;" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$TABLES" ]; then
    print_error "Failed to fetch table list from MySQL"
    exit 1
fi

TABLE_COUNT=$(echo "$TABLES" | wc -l)

print_info "Found $TABLE_COUNT tables in database: $MYSQL_DATABASE"
echo ""

# Save table list
echo "$TABLES" > "$OUTPUT_DIR/table_list.txt"
print_status 0 "Table list saved to: $OUTPUT_DIR/table_list.txt"

echo ""
echo "3. Analyzing Table Structures"
echo "------------------------------"

# Create summary file
SUMMARY_FILE="$OUTPUT_DIR/schema_summary.txt"
echo "MySQL to ClickHouse Schema Analysis" > "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "Database: $MYSQL_DATABASE" >> "$SUMMARY_FILE"
echo "Total Tables: $TABLE_COUNT" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "Table Details:" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"

ANALYZED=0
FAILED_TABLES=0

for TABLE in $TABLES; do
    ((ANALYZED++))
    echo -ne "\rAnalyzing table $ANALYZED/$TABLE_COUNT: $TABLE                    "

    # Get MySQL CREATE TABLE statement with better error handling
    DDL_OUTPUT=$($MYSQL_CMD -e "SHOW CREATE TABLE \`$TABLE\`;" 2>&1)
    if [ $? -eq 0 ]; then
        echo "$DDL_OUTPUT" > "$OUTPUT_DIR/mysql_ddl/${TABLE}.sql"
    else
        echo -e "\n${YELLOW}Warning: Could not get DDL for table: $TABLE${NC}"
        echo "Error: $DDL_OUTPUT" >> "$OUTPUT_DIR/failed_tables.log"
        ((FAILED_TABLES++))
        continue
    fi

    # Get row count (with timeout to avoid hanging)
    ROW_COUNT=$(timeout 10 $MYSQL_CMD -N -e "SELECT COUNT(*) FROM \`$TABLE\`;" 2>/dev/null || echo "unknown")

    # Get table size
    TABLE_SIZE=$($MYSQL_CMD -N -e "
        SELECT COALESCE(ROUND(((data_length + index_length) / 1024 / 1024), 2), 0)
        FROM information_schema.TABLES
        WHERE table_schema = '$MYSQL_DATABASE'
        AND table_name = '$TABLE';" 2>/dev/null || echo "0")

    # Get primary key
    PRIMARY_KEY=$($MYSQL_CMD -N -e "
        SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION)
        FROM information_schema.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
        AND TABLE_NAME = '$TABLE'
        AND CONSTRAINT_NAME = 'PRIMARY';" 2>/dev/null || echo "none")

    # Add to summary
    echo "Table: $TABLE" >> "$SUMMARY_FILE"
    echo "  Rows: $ROW_COUNT" >> "$SUMMARY_FILE"
    echo "  Size: ${TABLE_SIZE} MB" >> "$SUMMARY_FILE"
    echo "  Primary Key: $PRIMARY_KEY" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
done

echo ""
echo ""

if [ "$FAILED_TABLES" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warning: Failed to analyze $FAILED_TABLES tables${NC}"
    echo "  See: $OUTPUT_DIR/failed_tables.log"
fi

print_status 0 "Analyzed $((ANALYZED - FAILED_TABLES)) tables successfully"

# Verify DDL files were created
DDL_COUNT=$(ls -1 "$OUTPUT_DIR/mysql_ddl"/*.sql 2>/dev/null | wc -l)
if [ "$DDL_COUNT" -eq 0 ]; then
    print_error "No DDL files were created!"
    echo "This usually means:"
    echo "  1. MySQL SHOW CREATE TABLE command failed"
    echo "  2. Permissions issue writing to $OUTPUT_DIR/mysql_ddl/"
    echo "  3. All tables failed to export"
    exit 1
fi

print_info "Created $DDL_COUNT DDL files in mysql_ddl/"

echo ""
echo "4. Creating DDL Conversion Script"
echo "----------------------------------"

# Create the Python conversion script
cat > "$OUTPUT_DIR/convert_ddl.py" << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
import re
import sys
import os

# MySQL to ClickHouse type mapping
TYPE_MAPPING = {
    # Integer types
    'TINYINT': 'Int8',
    'TINYINT UNSIGNED': 'UInt8',
    'SMALLINT': 'Int16',
    'SMALLINT UNSIGNED': 'UInt16',
    'MEDIUMINT': 'Int32',
    'MEDIUMINT UNSIGNED': 'UInt32',
    'INT': 'Int32',
    'INT UNSIGNED': 'UInt32',
    'INTEGER': 'Int32',
    'INTEGER UNSIGNED': 'UInt32',
    'BIGINT': 'Int64',
    'BIGINT UNSIGNED': 'UInt64',

    # Floating point
    'FLOAT': 'Float32',
    'DOUBLE': 'Float64',
    'DECIMAL': 'Decimal',

    # String types
    'CHAR': 'String',
    'VARCHAR': 'String',
    'TEXT': 'String',
    'TINYTEXT': 'String',
    'MEDIUMTEXT': 'String',
    'LONGTEXT': 'String',

    # Binary types
    'BLOB': 'String',
    'TINYBLOB': 'String',
    'MEDIUMBLOB': 'String',
    'LONGBLOB': 'String',
    'BINARY': 'String',
    'VARBINARY': 'String',

    # Date/Time types
    'DATE': 'Date',
    'DATETIME': 'DateTime',
    'TIMESTAMP': 'DateTime',
    'TIME': 'String',
    'YEAR': 'UInt16',

    # Other types
    'ENUM': 'String',
    'SET': 'String',
    'JSON': 'String',
    'BOOL': 'UInt8',
    'BOOLEAN': 'UInt8',
}

def convert_mysql_type_to_clickhouse(mysql_type):
    """Convert MySQL column type to ClickHouse type"""
    # Remove size specifications and extract base type
    base_type = re.sub(r'\([^)]*\)', '', mysql_type).strip().upper()

    # Handle UNSIGNED
    if 'UNSIGNED' in base_type:
        base_type_clean = base_type.replace('UNSIGNED', '').strip()
        lookup_key = f"{base_type_clean} UNSIGNED"
        if lookup_key in TYPE_MAPPING:
            return TYPE_MAPPING[lookup_key]

    # Direct mapping
    for mysql, clickhouse in TYPE_MAPPING.items():
        if base_type.startswith(mysql):
            # Handle DECIMAL with precision
            if mysql == 'DECIMAL' and '(' in mysql_type:
                precision = re.search(r'\((\d+,\d+)\)', mysql_type)
                if precision:
                    return f"Decimal({precision.group(1)})"
            return clickhouse

    # Default fallback
    return 'String'

def parse_mysql_ddl(mysql_ddl, table_name):
    """Parse MySQL CREATE TABLE and convert to ClickHouse"""

    # Extract the CREATE TABLE statement from SHOW CREATE TABLE output
    # Format: Table | Create Table
    lines = mysql_ddl.split('\n')
    create_statement = ""
    for i, line in enumerate(lines):
        if 'CREATE TABLE' in line.upper():
            # Join all lines from this point
            create_statement = '\n'.join(lines[i:])
            break

    if not create_statement:
        raise Exception(f"Could not find CREATE TABLE statement in DDL for {table_name}")

    # Extract column definitions
    column_pattern = r'`(\w+)`\s+([^,\n]+?)(?:,|\n)'
    columns = re.findall(column_pattern, create_statement, re.MULTILINE)

    clickhouse_columns = []
    primary_keys = []

    # Extract PRIMARY KEY
    pk_pattern = r'PRIMARY KEY \(`([^`]+)`\)'
    pk_match = re.search(pk_pattern, create_statement)
    if pk_match:
        primary_keys = [pk.strip() for pk in pk_match.group(1).split(',')]

    for col_name, col_def in columns:
        # Skip if this is a constraint line
        if col_name.upper() in ['PRIMARY', 'KEY', 'INDEX', 'UNIQUE', 'CONSTRAINT']:
            continue

        # Parse column definition
        parts = col_def.strip().split()
        if not parts:
            continue

        mysql_type = parts[0]

        # Convert type
        ch_type = convert_mysql_type_to_clickhouse(mysql_type)

        # Check for NOT NULL / NULL
        nullable = 'NULL' in col_def.upper() and 'NOT NULL' not in col_def.upper()

        if nullable:
            ch_type = f"Nullable({ch_type})"

        # Check for DEFAULT
        default_match = re.search(r"DEFAULT\s+('([^']*)'|([^\s,]+))", col_def, re.IGNORECASE)
        default_clause = ""
        if default_match:
            default_val = default_match.group(2) if default_match.group(2) else default_match.group(3)
            if default_val.upper() == 'NULL':
                default_clause = " DEFAULT NULL"
            elif default_val.upper() in ['CURRENT_TIMESTAMP', 'NOW()']:
                default_clause = " DEFAULT now()"
            else:
                default_clause = f" DEFAULT '{default_val}'" if default_match.group(2) else f" DEFAULT {default_val}"

        clickhouse_columns.append(f"    `{col_name}` {ch_type}{default_clause}")

    # Add CDC metadata columns
    clickhouse_columns.append("    `_version` UInt64 DEFAULT 0")
    clickhouse_columns.append("    `_is_deleted` UInt8 DEFAULT 0")
    clickhouse_columns.append("    `_extracted_at` DateTime DEFAULT now()")

    # Build ClickHouse CREATE TABLE
    ch_ddl = f"CREATE TABLE IF NOT EXISTS analytics.`{table_name}`\n(\n"
    ch_ddl += ",\n".join(clickhouse_columns)
    ch_ddl += "\n)\n"

    # Choose engine and ORDER BY
    if primary_keys:
        order_by = ", ".join([f"`{pk}`" for pk in primary_keys])
        ch_ddl += f"ENGINE = ReplacingMergeTree(_version)\n"
        ch_ddl += f"ORDER BY ({order_by})\n"
    else:
        # No primary key, use tuple()
        ch_ddl += f"ENGINE = ReplacingMergeTree(_version)\n"
        ch_ddl += f"ORDER BY tuple()\n"

    ch_ddl += "SETTINGS index_granularity = 8192;"

    return ch_ddl

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: convert_ddl.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]

    converted = 0
    failed = 0

    # Process all SQL files in input directory
    for filename in os.listdir(input_dir):
        if filename.endswith('.sql'):
            table_name = filename[:-4]
            input_file = os.path.join(input_dir, filename)
            output_file = os.path.join(output_dir, filename)

            try:
                with open(input_file, 'r') as f:
                    mysql_ddl = f.read()

                clickhouse_ddl = parse_mysql_ddl(mysql_ddl, table_name)

                with open(output_file, 'w') as f:
                    f.write(clickhouse_ddl)
                    f.write("\n")

                converted += 1
                print(f"✓ Converted: {table_name}")
            except Exception as e:
                failed += 1
                print(f"✗ Error converting {table_name}: {e}", file=sys.stderr)

    print(f"\nConversion Summary:")
    print(f"  Converted: {converted}")
    print(f"  Failed: {failed}")
    print(f"  Output: {output_dir}/")

    sys.exit(0 if failed == 0 else 1)
PYTHON_SCRIPT

chmod +x "$OUTPUT_DIR/convert_ddl.py"
print_status 0 "Conversion script created"

echo ""
echo "5. Generating ClickHouse DDL"
echo "-----------------------------"

# Run the conversion
$PYTHON_CMD "$OUTPUT_DIR/convert_ddl.py" "$OUTPUT_DIR/mysql_ddl" "$OUTPUT_DIR/clickhouse_ddl"
CONVERT_EXIT=$?

if [ $CONVERT_EXIT -eq 0 ]; then
    # Verify ClickHouse DDL files were created
    CH_DDL_COUNT=$(ls -1 "$OUTPUT_DIR/clickhouse_ddl"/*.sql 2>/dev/null | wc -l)

    if [ "$CH_DDL_COUNT" -gt 0 ]; then
        print_status 0 "Generated $CH_DDL_COUNT ClickHouse DDL files"
    else
        print_error "Conversion script ran but no DDL files were created!"
        exit 1
    fi
else
    print_error "DDL conversion failed"
    echo "Check errors above for details"
    exit 1
fi

echo ""
echo "========================================"
echo "   Analysis Complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  Tables analyzed: $((ANALYZED - FAILED_TABLES))/$TABLE_COUNT"
echo "  MySQL DDL files: $DDL_COUNT"
echo "  ClickHouse DDL files: $CH_DDL_COUNT"

if [ "$FAILED_TABLES" -gt 0 ]; then
    echo -e "  ${YELLOW}Failed tables: $FAILED_TABLES${NC}"
fi

echo ""
echo "Output files:"
echo "  Table list:        $OUTPUT_DIR/table_list.txt"
echo "  Summary:           $OUTPUT_DIR/schema_summary.txt"
echo "  MySQL DDL:         $OUTPUT_DIR/mysql_ddl/"
echo "  ClickHouse DDL:    $OUTPUT_DIR/clickhouse_ddl/"
echo ""
echo "Next step: Run 02_create_clickhouse_schema.sh"
echo ""

exit 0
