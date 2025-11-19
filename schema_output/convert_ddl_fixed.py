#!/usr/bin/env python3
"""
MySQL to ClickHouse DDL Converter - FIXED VERSION
Based on: Real-Time CDC Migration to ClickHouse Technical Guide for Gaming Analytics

Fixes:
1. Properly handles escaped newlines in MySQL DDL output
2. Correctly extracts all columns (not just constraints)
3. Intelligent type mapping for gaming analytics workloads
4. Primary key → ORDER BY conversion
5. Partitioning on timestamp columns
6. ReplacingMergeTree with CDC metadata
"""

import re
import sys
import os
from typing import List, Tuple, Optional

def normalize_mysql_ddl(raw_ddl: str) -> str:
    """
    Convert MySQL SHOW CREATE TABLE output to properly formatted DDL

    MySQL SHOW CREATE TABLE returns format:
    Line 1: mysql: [Warning] Using a password... (sometimes)
    Line 2: Table\tCreate Table
    Line 3: table_name\tCREATE TABLE "table_name" (\n  "col" type,\n  ...)
    """
    # Split by actual newlines
    lines = raw_ddl.split('\n')

    # Find the line that starts with CREATE TABLE (ignoring case)
    create_part = None
    for line in lines:
        # Skip warning lines and header lines
        if 'mysql:' in line.lower() or line.strip() == '' or line.strip().lower() in ['table\tcreate table', 'table create table']:
            continue

        # Look for the line with actual CREATE TABLE DDL
        if '\t' in line and 'CREATE TABLE' in line.upper():
            # Format: table_name\tCREATE TABLE...
            parts = line.split('\t', 1)  # Split only on first tab
            if len(parts) >= 2 and 'CREATE TABLE' in parts[1].upper():
                create_part = parts[1]
                break

    if not create_part:
        # Try alternative format - some tables might have CREATE TABLE directly
        for line in lines:
            if line.strip().upper().startswith('CREATE TABLE'):
                create_part = line.strip()
                break

    if not create_part:
        raise Exception(f"Could not find CREATE TABLE statement. File has {len(lines)} lines. First few lines: {lines[:5]}")

    # Replace escaped newlines with real newlines
    ddl = create_part.replace('\\n', '\n')

    # Remove MySQL-specific escaping
    ddl = ddl.replace('\\"', '"')
    ddl = ddl.replace("\\'", "'")

    return ddl


def extract_columns_and_metadata(ddl_text: str) -> Tuple[List[Tuple[str, str]], List[str]]:
    """
    Extract columns and primary keys from normalized MySQL DDL

    Returns:
        (columns, primary_keys) where columns is [(name, definition), ...]
    """
    # Extract the content between CREATE TABLE ... ( and final )
    # Handle tables that end with just ) and no ENGINE clause
    match = re.search(r'CREATE TABLE[^(]+\((.*)\)\s*$', ddl_text, re.DOTALL | re.IGNORECASE)
    if not match:
        # Try without strict end match
        match = re.search(r'CREATE TABLE[^(]+\((.*)\)', ddl_text, re.DOTALL | re.IGNORECASE)
    if not match:
        raise Exception(f"Could not parse CREATE TABLE structure. DDL starts with: {ddl_text[:200]}")

    columns_section = match.group(1)

    # Split by lines and clean up
    lines = [line.strip() for line in columns_section.split('\n') if line.strip()]

    columns = []
    primary_keys = []

    for line in lines:
        # Skip constraint definitions
        upper_line = line.upper()
        if any(keyword in upper_line for keyword in [
            'PRIMARY KEY', 'UNIQUE KEY', 'FOREIGN KEY', 'CONSTRAINT',
            'KEY ', 'INDEX', 'CHECK ('
        ]):
            # Extract PRIMARY KEY if present
            if 'PRIMARY KEY' in upper_line:
                # Match: PRIMARY KEY ("id") or PRIMARY KEY ("id","user_id")
                pk_match = re.search(r'PRIMARY KEY \("([^"]+)"(?:,\s*"([^"]+)")*\)', line, re.IGNORECASE)
                if pk_match:
                    # Handle composite keys
                    pk_str = line[line.find('PRIMARY KEY'):].strip()
                    pk_cols = re.findall(r'"(\w+)"', pk_str)
                    primary_keys.extend(pk_cols)
            continue

        # Parse column definition: "column_name" type [constraints],
        # Match pattern: "col_name" TYPE ...
        col_match = re.match(r'"(\w+)"\s+(.+?)(?:,\s*$|$)', line)
        if col_match:
            col_name = col_match.group(1)
            col_definition = col_match.group(2).rstrip(',').strip()
            columns.append((col_name, col_definition))

    return columns, primary_keys


def map_mysql_to_clickhouse_type(col_name: str, mysql_type_def: str) -> str:
    """
    Map MySQL types to ClickHouse with gaming-specific optimizations
    Based on Technical Guide recommendations
    """
    type_upper = mysql_type_def.upper()
    is_nullable = 'NOT NULL' not in type_upper
    is_unsigned = 'UNSIGNED' in type_upper

    # Extract base type and precision
    base_type_match = re.match(r'(\w+)(\([^)]+\))?', mysql_type_def)
    if not base_type_match:
        return default_with_nullable('String', is_nullable)

    base_type = base_type_match.group(1).upper()
    precision = base_type_match.group(2) if base_type_match.group(2) else ''

    col_name_lower = col_name.lower()

    # === GAMING-SPECIFIC OPTIMIZATIONS (from Technical Guide) ===

    # BOOLEAN fields: TINYINT(1) → Bool
    if base_type == 'TINYINT' and '(1)' in precision:
        return default_with_nullable('Bool', is_nullable, 'DEFAULT 0')

    # Player IDs, scores, counters → Unsigned Integers
    if any(keyword in col_name_lower for keyword in ['_id', 'count', 'number', 'score']):
        ch_type = map_integer_type(base_type, is_unsigned)
        return default_with_nullable(ch_type, is_nullable, 'DEFAULT 0')

    # Currency/Money fields → Decimal for precision (from guide)
    if any(keyword in col_name_lower for keyword in ['amount', 'balance', 'price', 'revenue', 'cost', 'limit']):
        if base_type == 'DOUBLE':
            ch_type = 'Decimal64(2)'  # Real money precision
        elif base_type == 'DECIMAL':
            ch_type = f'Decimal{precision}' if precision else 'Decimal64(2)'
        else:
            ch_type = map_base_type(base_type, precision, is_unsigned)
        return default_with_nullable(ch_type, is_nullable, '')

    # Country codes → LowCardinality(FixedString(2)) (from guide)
    if col_name_lower in ['country', 'country_code'] and ('CHAR(2)' in type_upper or 'VARCHAR(2)' in type_upper):
        return default_with_nullable('LowCardinality(FixedString(2))', is_nullable, "DEFAULT ''")

    # Categorical fields → LowCardinality(String) (from guide)
    if any(keyword in col_name_lower for keyword in [
        'type', 'status', 'tier', 'level', 'category', 'platform',
        'gender', 'zone', 'woreda', 'kebele', 'region', 'city'
    ]) and base_type in ['VARCHAR', 'CHAR', 'ENUM', 'SET']:
        return default_with_nullable('LowCardinality(String)', is_nullable, "DEFAULT ''")

    # DateTime with timezone (gaming requirement from guide)
    if base_type in ['DATETIME', 'TIMESTAMP']:
        if '(6)' in precision:  # Microsecond precision
            ch_type = "DateTime64(6, 'UTC')"
        elif '(3)' in precision:  # Millisecond precision
            ch_type = "DateTime64(3, 'UTC')"
        else:
            ch_type = "DateTime('UTC')"
        return default_with_nullable(ch_type, is_nullable, 'DEFAULT toDateTime(0)')

    # UUID fields (CHAR(36) or CHAR(32))
    if '(36)' in precision or '(32)' in precision:
        if any(keyword in col_name_lower for keyword in ['uuid', 'guid']):
            return default_with_nullable('UUID', is_nullable, '')
        else:
            return default_with_nullable('String', is_nullable, "DEFAULT ''")

    # Default type conversion
    ch_type = map_base_type(base_type, precision, is_unsigned)

    # Avoid Nullable for performance (guide recommendation)
    if 'Int' in ch_type or 'UInt' in ch_type:
        default_val = 'DEFAULT 0'
    elif ch_type == 'String' or 'LowCardinality' in ch_type:
        default_val = "DEFAULT ''"
    elif 'DateTime' in ch_type:
        default_val = 'DEFAULT toDateTime(0)'
    elif 'Date' == ch_type:
        default_val = 'DEFAULT toDate(0)'
    elif ch_type == 'Bool':
        default_val = 'DEFAULT 0'
    elif 'Float' in ch_type:
        default_val = 'DEFAULT 0.0'
    elif 'Decimal' in ch_type:
        default_val = 'DEFAULT 0'
    else:
        default_val = ''

    return default_with_nullable(ch_type, is_nullable, default_val)


def map_integer_type(base_type: str, is_unsigned: bool) -> str:
    """Map integer types to appropriate ClickHouse types"""
    int_map = {
        'TINYINT': 'UInt8' if is_unsigned else 'Int8',
        'SMALLINT': 'UInt16' if is_unsigned else 'Int16',
        'MEDIUMINT': 'UInt32' if is_unsigned else 'Int32',
        'INT': 'UInt32' if is_unsigned else 'Int32',
        'INTEGER': 'UInt32' if is_unsigned else 'Int32',
        'BIGINT': 'UInt64' if is_unsigned else 'Int64',
    }
    return int_map.get(base_type, 'Int32')


def map_base_type(base_type: str, precision: str, is_unsigned: bool) -> str:
    """Base type conversion mapping"""
    TYPE_MAP = {
        'TINYINT': 'UInt8' if is_unsigned else 'Int8',
        'SMALLINT': 'UInt16' if is_unsigned else 'Int16',
        'MEDIUMINT': 'UInt32' if is_unsigned else 'Int32',
        'INT': 'UInt32' if is_unsigned else 'Int32',
        'INTEGER': 'UInt32' if is_unsigned else 'Int32',
        'BIGINT': 'UInt64' if is_unsigned else 'Int64',
        'FLOAT': 'Float32',
        'DOUBLE': 'Float64',
        'DECIMAL': f'Decimal{precision}' if precision else 'Decimal64(2)',
        'CHAR': 'String',
        'VARCHAR': 'String',
        'TEXT': 'String',
        'TINYTEXT': 'String',
        'MEDIUMTEXT': 'String',
        'LONGTEXT': 'String',
        'BLOB': 'String',
        'TINYBLOB': 'String',
        'MEDIUMBLOB': 'String',
        'LONGBLOB': 'String',
        'BINARY': 'String',
        'VARBINARY': 'String',
        'DATE': 'Date',
        'DATETIME': 'DateTime',
        'TIMESTAMP': 'DateTime',
        'TIME': 'String',
        'YEAR': 'UInt16',
        'ENUM': 'LowCardinality(String)',
        'SET': 'String',
        'JSON': 'String',
        'BOOL': 'Bool',
        'BOOLEAN': 'Bool',
    }

    return TYPE_MAP.get(base_type, 'String')


def default_with_nullable(ch_type: str, is_nullable: bool, default_val: str = '') -> str:
    """
    Handle nullable types with defaults instead of Nullable() for performance
    Per guide: avoid Nullable for 10-20% performance gain
    """
    if is_nullable and default_val:
        # Use default value instead of Nullable
        return f'{ch_type} {default_val}'
    elif is_nullable and not default_val:
        # For types where null is semantically important, use Nullable
        return f'Nullable({ch_type})'
    else:
        # NOT NULL columns
        return ch_type


def generate_clickhouse_ddl(table_name: str, columns: List[Tuple[str, str]], primary_keys: List[str]) -> str:
    """
    Generate ClickHouse CREATE TABLE with CDC optimizations
    Based on Technical Guide recommendations
    """
    ch_columns = []
    timestamp_columns = []

    # Convert all columns
    for col_name, col_def in columns:
        ch_type = map_mysql_to_clickhouse_type(col_name, col_def)
        ch_columns.append(f'    `{col_name}` {ch_type}')

        # Track timestamp columns for partitioning
        if any(t in col_def.upper() for t in ['DATETIME', 'TIMESTAMP']) and col_name.lower() not in ['updated_at', 'deleted_at']:
            timestamp_columns.append(col_name)

    # Add CDC metadata columns (CRITICAL - from guide)
    ch_columns.append('    `_version` UInt64 DEFAULT 0')
    ch_columns.append('    `_is_deleted` UInt8 DEFAULT 0')
    ch_columns.append('    `_extracted_at` DateTime DEFAULT now()')

    # Build CREATE TABLE
    ddl = f'CREATE TABLE IF NOT EXISTS analytics.`{table_name}`\n(\n'
    ddl += ',\n'.join(ch_columns)
    ddl += '\n)\n'

    # Engine: ReplacingMergeTree with version and is_deleted (from guide)
    ddl += 'ENGINE = ReplacingMergeTree(_version, _is_deleted)\n'

    # ORDER BY clause (MySQL PRIMARY KEY → ClickHouse ORDER BY)
    if primary_keys:
        order_cols = ', '.join([f'`{pk}`' for pk in primary_keys])
        ddl += f'ORDER BY ({order_cols})\n'
    else:
        # No PK: use tuple() - query performance will be poor but functional
        ddl += 'ORDER BY tuple()\n'

    # Partitioning on timestamp columns (from guide: daily for high volume)
    if timestamp_columns:
        # Use first timestamp column (prefer created_at, created, date)
        partition_col = None
        for preferred in ['created_at', 'created', 'date', 'timestamp']:
            if any(preferred in col.lower() for col in timestamp_columns):
                partition_col = next(col for col in timestamp_columns if preferred in col.lower())
                break

        if not partition_col:
            partition_col = timestamp_columns[0]

        # Daily partitioning for high volume (100M+ rows/day from guide)
        ddl += f'PARTITION BY toYYYYMM(`{partition_col}`)\n'

    # Settings (from guide: clean_deleted_rows for auto-cleanup)
    ddl += "SETTINGS clean_deleted_rows = 'Always',\n"
    ddl += '         index_granularity = 8192;'

    return ddl


def validate_conversion(table_name: str, mysql_columns: List[Tuple[str, str]],
                       clickhouse_ddl: str, primary_keys: List[str]) -> bool:
    """Validate the conversion was successful"""
    # Count columns in ClickHouse DDL (each column has exactly 2 backticks)
    ch_col_count = clickhouse_ddl.count('`') // 2
    mysql_col_count = len(mysql_columns)

    # Expected: MySQL columns + 3 CDC metadata columns
    expected_ch_cols = mysql_col_count + 3

    success = True

    if ch_col_count != expected_ch_cols:
        print(f"❌ COLUMN MISMATCH: {table_name}")
        print(f"   MySQL: {mysql_col_count} columns")
        print(f"   ClickHouse: {ch_col_count} columns (expected {expected_ch_cols})")
        print(f"   Missing: {expected_ch_cols - ch_col_count} columns")
        success = False

    # Check for ORDER BY
    if 'ORDER BY tuple()' in clickhouse_ddl and primary_keys:
        print(f"⚠️  WARNING: {table_name} - PRIMARY KEY not properly mapped to ORDER BY")
        success = False

    # Check if not all types are String (indicates mapping worked)
    string_count = clickhouse_ddl.count(' String')
    if string_count > mysql_col_count * 0.7:
        print(f"⚠️  WARNING: {table_name} - Too many String types ({string_count}/{mysql_col_count})")

    if success:
        print(f"✅ {table_name}: {mysql_col_count} columns → {ch_col_count} columns (PK: {','.join(primary_keys) if primary_keys else 'none'})")

    return success


def main(input_dir: str, output_dir: str):
    """Main conversion logic"""
    converted = 0
    failed = 0
    validation_report = []

    print("\n" + "="*70)
    print("  MySQL to ClickHouse DDL Converter (FIXED VERSION)")
    print("  Based on: Real-Time CDC Migration Technical Guide")
    print("="*70 + "\n")

    # Get all SQL files
    sql_files = [f for f in os.listdir(input_dir) if f.endswith('.sql')]
    total_files = len(sql_files)

    print(f"Found {total_files} MySQL DDL files to convert\n")

    for idx, filename in enumerate(sql_files, 1):
        table_name = filename[:-4]
        input_file = os.path.join(input_dir, filename)
        output_file = os.path.join(output_dir, filename)

        try:
            # Read MySQL DDL
            with open(input_file, 'r', encoding='utf-8') as f:
                raw_ddl = f.read()

            # Normalize DDL (fix escaped newlines)
            normalized_ddl = normalize_mysql_ddl(raw_ddl)

            # Extract columns and primary key
            columns, primary_keys = extract_columns_and_metadata(normalized_ddl)

            # Generate ClickHouse DDL
            ch_ddl = generate_clickhouse_ddl(table_name, columns, primary_keys)

            # Validate conversion
            is_valid = validate_conversion(table_name, columns, ch_ddl, primary_keys)
            validation_report.append((table_name, len(columns), len(primary_keys), is_valid))

            # Write output
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(ch_ddl)
                f.write('\n')

            converted += 1

        except Exception as e:
            failed += 1
            print(f"✗ Error converting {table_name}: {e}")
            import traceback
            traceback.print_exc()

    # Print summary
    print(f"\n{'='*70}")
    print(f"Conversion Summary:")
    print(f"  Total files: {total_files}")
    print(f"  ✅ Converted: {converted}")
    print(f"  ❌ Failed: {failed}")
    print(f"  Output: {output_dir}/")
    print(f"{'='*70}\n")

    # Print validation summary
    print("Validation Summary:")
    valid_count = sum(1 for _, _, _, valid in validation_report if valid)
    invalid_count = sum(1 for _, _, _, valid in validation_report if not valid)
    print(f"  ✅ Valid conversions: {valid_count}")
    print(f"  ⚠️  Issues found: {invalid_count}")

    if invalid_count > 0:
        print(f"\nTables with issues:")
        for table, cols, pks, valid in validation_report:
            if not valid:
                print(f"  - {table} ({cols} columns, PK: {pks} keys)")

    print()

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: convert_ddl_fixed.py <input_dir> <output_dir>")
        sys.exit(1)

    sys.exit(main(sys.argv[1], sys.argv[2]))
