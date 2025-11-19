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
