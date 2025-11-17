#!/bin/bash
# Phase 3 - MySQL Schema Analysis Script
# Purpose: Analyze MySQL database and generate ClickHouse DDL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"
OUTPUT_DIR="$PHASE3_DIR/schema_output"

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

echo "========================================"
echo "   MySQL Schema Analysis"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found at $CONFIG_DIR/.env${NC}"
    exit 1
fi

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
    exit 1
fi

echo ""
echo "2. Fetching Table List"
echo "----------------------"

# Get list of all tables
TABLES=$($MYSQL_CMD -N -e "SHOW TABLES;" 2>/dev/null)
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

for TABLE in $TABLES; do
    ((ANALYZED++))
    echo -ne "\rAnalyzing table $ANALYZED/$TABLE_COUNT: $TABLE                    "

    # Get MySQL CREATE TABLE statement
    $MYSQL_CMD -e "SHOW CREATE TABLE \`$TABLE\`;" > "$OUTPUT_DIR/mysql_ddl/${TABLE}.sql" 2>/dev/null || {
        echo -e "\n${YELLOW}Warning: Could not get DDL for table: $TABLE${NC}"
        continue
    }

    # Get row count
    ROW_COUNT=$($MYSQL_CMD -N -e "SELECT COUNT(*) FROM \`$TABLE\`;" 2>/dev/null || echo "0")

    # Get table size
    TABLE_SIZE=$($MYSQL_CMD -N -e "
        SELECT ROUND(((data_length + index_length) / 1024 / 1024), 2)
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
print_status 0 "Analyzed $ANALYZED tables"

echo ""
echo "4. Generating ClickHouse DDL"
echo "----------------------------"

# Create a Python script to convert MySQL DDL to ClickHouse DDL
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

    # Extract column definitions
    column_pattern = r'`(\w+)`\s+([^,\n]+?)(?:,|\n)'
    columns = re.findall(column_pattern, mysql_ddl, re.MULTILINE)

    clickhouse_columns = []
    primary_keys = []

    # Extract PRIMARY KEY
    pk_pattern = r'PRIMARY KEY \(`([^`]+)`\)'
    pk_match = re.search(pk_pattern, mysql_ddl)
    if pk_match:
        primary_keys = [pk.strip() for pk in pk_match.group(1).split(',')]

    for col_name, col_def in columns:
        # Skip if this is a constraint line
        if col_name.upper() in ['PRIMARY', 'KEY', 'INDEX', 'UNIQUE', 'CONSTRAINT']:
            continue

        # Parse column definition
        parts = col_def.strip().split()
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

                print(f"Converted: {table_name}")
            except Exception as e:
                print(f"Error converting {table_name}: {e}", file=sys.stderr)

    print(f"\nConversion complete! Check {output_dir}/")
PYTHON_SCRIPT

chmod +x "$OUTPUT_DIR/convert_ddl.py"

# Run the conversion
if command -v python3 &> /dev/null; then
    python3 "$OUTPUT_DIR/convert_ddl.py" "$OUTPUT_DIR/mysql_ddl" "$OUTPUT_DIR/clickhouse_ddl"
    print_status 0 "ClickHouse DDL generated successfully"
elif command -v python &> /dev/null; then
    python "$OUTPUT_DIR/convert_ddl.py" "$OUTPUT_DIR/mysql_ddl" "$OUTPUT_DIR/clickhouse_ddl"
    print_status 0 "ClickHouse DDL generated successfully"
else
    print_status 1 "Python not found - cannot generate ClickHouse DDL automatically"
    echo "  Please install Python 3 and re-run this script"
fi

echo ""
echo "========================================"
echo "   Analysis Complete!"
echo "========================================"
echo ""
echo "Output files:"
echo "  Table list:        $OUTPUT_DIR/table_list.txt"
echo "  Summary:           $OUTPUT_DIR/schema_summary.txt"
echo "  MySQL DDL:         $OUTPUT_DIR/mysql_ddl/"
echo "  ClickHouse DDL:    $OUTPUT_DIR/clickhouse_ddl/"
echo ""
echo "Next step: Run 02_create_clickhouse_schema.sh"
echo ""
