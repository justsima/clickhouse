# Phase 3 Execution Guide: Fixed Schema Conversion

## Overview

This guide provides step-by-step instructions for executing Phase 3 with the **fixed** schema conversion that resolves the critical issue where only 16% of columns were being extracted.

## What Was Fixed

**Before (Broken)**:
- Only 12 out of 74 columns extracted from `flatodd_member` table
- All types mapped to `String` (incorrect)
- Missing PRIMARY KEY → ORDER BY mapping
- No partitioning
- No CDC metadata columns

**After (Fixed)**:
- All 74 MySQL columns + 3 CDC columns = 77 total
- Gaming-optimized type mapping (LowCardinality, Decimal64, DateTime64)
- Proper PRIMARY KEY → ORDER BY conversion
- Monthly partitioning on timestamp columns
- ReplacingMergeTree with `_version`, `_is_deleted`, `_extracted_at`

## Prerequisites

**Completed on your VPS**:
- ✅ Phase 1: Environment validated
- ✅ Phase 2: All services running (Redpanda, ClickHouse, Kafka Connect)
- ✅ Docker containers healthy

**Current State**:
- All services running via Docker Compose
- ClickHouse accessible on ports 9000 (native) and 8123 (HTTP)
- Schema conversion scripts committed and pushed to GitHub

## Execution Steps

### Step 0: Merge PR and Pull Changes (On your VPS)

```bash
# After you merge the PR on GitHub:
cd /home/user/clickhouse
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
```

### Step 1: Cleanup Old Tables (If Any Exist)

**Purpose**: Remove any tables created with the old (broken) schema conversion.

```bash
cd /home/user/clickhouse/phase3
chmod +x scripts/00_cleanup_old_tables.sh
./scripts/00_cleanup_old_tables.sh
```

**Expected Output**:
```
=========================================
ClickHouse Table Cleanup Script
=========================================

✓ Connected to ClickHouse
✓ Database 'analytics' exists
✓ Found X table(s) to drop

Tables to be dropped:
  - flatodd_member
  - [other tables...]

Creating backup of table structures...
✓ Backup saved to: /home/user/clickhouse/phase3/backups/table_structures_backup_YYYYMMDD_HHMMSS.sql

⚠ WARNING: This will permanently drop X table(s)!

Are you sure you want to proceed? (yes/no):
```

**What to do**:
- Review the list of tables to be dropped
- Type `yes` to proceed
- The script will create a backup of old table structures before dropping

**If no tables exist**:
```
ℹ Database 'analytics' does not exist yet
Nothing to clean up. You can proceed with schema creation.
```

**Send me the output**: Copy and paste the entire output so I can verify cleanup was successful.

---

### Step 2: Verify MySQL DDL Files

**Purpose**: Confirm that the MySQL DDL files contain the raw `SHOW CREATE TABLE` output.

```bash
cd /home/user/clickhouse/schema_output/mysql_ddl
ls -lh | head -20
wc -l flatodd_member.sql
cat flatodd_member.sql | head -20
```

**Expected**: You should see the MySQL DDL files with raw CREATE TABLE statements.

**Send me the output**: Copy the output so I can verify the files are correct.

---

### Step 3: Run Fixed Conversion Script

**Purpose**: Convert all MySQL DDL files to ClickHouse DDL with proper type mapping.

```bash
cd /home/user/clickhouse/schema_output
python3 convert_ddl_fixed.py
```

**Expected Output**:
```
Processing 450 MySQL DDL files...
✓ Converted: flatodd_member (74 columns → 77 with CDC metadata)
✓ Converted: flatodd_bet (45 columns → 48 with CDC metadata)
...
✓ Successfully converted 450 tables
✓ Output: /home/user/clickhouse/schema_output/clickhouse_ddl/
```

**What it does**:
- Reads all MySQL DDL files from `schema_output/mysql_ddl/`
- Converts MySQL types to ClickHouse types (gaming-optimized)
- Adds CDC metadata columns (_version, _is_deleted, _extracted_at)
- Maps PRIMARY KEY to ORDER BY
- Adds monthly partitioning
- Writes ClickHouse DDL to `schema_output/clickhouse_ddl/`

**Send me the output**: Copy the conversion summary.

---

### Step 4: Verify Converted DDL

**Purpose**: Spot-check the converted ClickHouse DDL to ensure correctness.

```bash
cd /home/user/clickhouse/schema_output/clickhouse_ddl

# Check the problematic table that was only showing 12 columns before
wc -l flatodd_member.sql
cat flatodd_member.sql
```

**Expected**: You should see approximately 77-80 lines (74 columns + CDC + DDL structure).

**Key things to verify**:
1. All columns present (not just 12)
2. Types are correct (not all String)
3. `ENGINE = ReplacingMergeTree(_version, _is_deleted)`
4. `ORDER BY (id)` or appropriate primary key
5. `PARTITION BY toYYYYMM(created_at)` or appropriate timestamp
6. CDC columns present: `_version`, `_is_deleted`, `_extracted_at`

**Send me the output**: Copy the `flatodd_member.sql` content.

---

### Step 5: Create ClickHouse Tables

**Purpose**: Execute all ClickHouse DDL files to create tables in the `analytics` database.

```bash
cd /home/user/clickhouse/phase3
chmod +x scripts/02_create_clickhouse_schema.sh
./scripts/02_create_clickhouse_schema.sh
```

**Expected Output**:
```
=========================================
Creating ClickHouse Schema
=========================================

✓ Connected to ClickHouse
✓ Database 'analytics' created

Creating tables from DDL files...
✓ Created: flatodd_member
✓ Created: flatodd_bet
...
✓ Successfully created 450 tables

Table count verification:
  Expected: 450
  Actual: 450
  Status: ✓ Match

Schema creation complete!
```

**What it does**:
- Connects to ClickHouse
- Creates `analytics` database (if not exists)
- Executes all DDL files in `schema_output/clickhouse_ddl/`
- Verifies table count matches expected

**If errors occur**:
- Note which table failed
- Check the DDL syntax in that specific file
- Send me the error message

**Send me the output**: Copy the entire output.

---

### Step 6: Verify Tables in ClickHouse

**Purpose**: Confirm all tables were created with correct structure.

```bash
# Connect to ClickHouse
docker exec -it clickhouse-server clickhouse-client

# Run these queries inside ClickHouse client:
```

```sql
-- List all databases
SHOW DATABASES;

-- Use analytics database
USE analytics;

-- Count tables
SELECT count() FROM system.tables WHERE database = 'analytics';

-- Expected: 450

-- Verify flatodd_member structure
DESCRIBE TABLE flatodd_member;

-- Check engine type
SELECT
    database,
    name,
    engine,
    partition_key,
    sorting_key,
    primary_key
FROM system.tables
WHERE database = 'analytics' AND name = 'flatodd_member';

-- Exit ClickHouse client
EXIT;
```

**Expected Results**:
- Database `analytics` exists
- 450 tables created
- `flatodd_member` has all columns (not just 12)
- Engine is `ReplacingMergeTree`
- Has partition key and sorting key

**Send me the output**: Copy the query results.

---

### Step 7: Deploy Debezium Connector (Initial Snapshot)

**Purpose**: Start the Debezium connector to perform initial snapshot of MySQL data.

**Note**: We'll start with snapshot first, then enable CDC later when you have replication privileges.

```bash
cd /home/user/clickhouse/phase3
chmod +x scripts/03_deploy_connectors.sh
./scripts/03_deploy_connectors.sh
```

**Expected Output**:
```
=========================================
Deploying CDC Connectors
=========================================

Deploying Debezium MySQL source connector...
✓ Connector 'mysql-source-connector' created successfully

Deploying ClickHouse sink connector...
✓ Connector 'clickhouse-sink-connector' created successfully

Verifying connector status...
✓ mysql-source-connector: RUNNING
✓ clickhouse-sink-connector: RUNNING

Connectors deployed successfully!
```

**What it does**:
- Creates Debezium MySQL source connector
- Creates ClickHouse sink connector
- Starts initial snapshot of all 450 tables
- Data flows: MySQL → Kafka → ClickHouse

**If connector fails**:
- Check connector status: `curl http://localhost:8085/connectors/mysql-source-connector/status`
- Check logs: `docker compose logs -f kafka-connect`
- Send me the error details

**Send me the output**: Copy the deployment output.

---

### Step 8: Monitor Snapshot Progress

**Purpose**: Track the initial data snapshot progress.

```bash
cd /home/user/clickhouse/phase3
chmod +x scripts/04_monitor_snapshot.sh
./scripts/04_monitor_snapshot.sh
```

**Expected Output** (updates every 30 seconds):
```
=========================================
Snapshot Progress Monitor
=========================================

Snapshot Status:
  Current table: flatodd_bet (45/450)
  Progress: 10%
  Rows processed: 1,234,567
  Duration: 5 minutes

ClickHouse Table Counts:
  flatodd_member: 100,000 rows
  flatodd_bet: 500,000 rows
  ...
```

**What it monitors**:
- Which table is being snapshotted
- Overall progress percentage
- Row counts in ClickHouse
- Connector health

**Duration**: Initial snapshot typically takes 2-4 hours for 21.7GB (based on network speed).

**Send me periodic updates**: Copy the output every 30 minutes or when snapshot completes.

---

### Step 9: Validate Data After Snapshot

**Purpose**: Compare MySQL row counts with ClickHouse to verify data integrity.

```bash
cd /home/user/clickhouse/phase3
chmod +x scripts/05_validate_data.sh
./scripts/05_validate_data.sh
```

**Expected Output**:
```
=========================================
Data Validation Report
=========================================

Comparing MySQL and ClickHouse row counts...

✓ flatodd_member: MySQL=100,000 | ClickHouse=100,000 | Match
✓ flatodd_bet: MySQL=500,000 | ClickHouse=500,000 | Match
...

Summary:
  Total tables: 450
  Matching: 450
  Mismatched: 0
  Status: ✓ All data validated successfully
```

**If mismatches occur**:
- Small differences (<1%) are acceptable during active writes
- Large differences indicate snapshot issue
- Re-check connector status and logs

**Send me the output**: Copy the validation report.

---

## Troubleshooting

### Issue: "Cannot connect to ClickHouse"

**Solution**:
```bash
# Check if ClickHouse is running
docker compose ps

# Check ClickHouse logs
docker compose logs clickhouse

# Restart if needed
docker compose restart clickhouse
```

### Issue: "Table already exists"

**Solution**: Run cleanup script again (Step 1).

### Issue: "Conversion script fails"

**Solution**:
- Check Python 3 is installed: `python3 --version`
- Check MySQL DDL files exist: `ls schema_output/mysql_ddl/ | wc -l`
- Send me the error message

### Issue: "Debezium connector fails"

**Common causes**:
- MySQL credentials incorrect
- Network connectivity issue
- MySQL binlog not enabled

**Solution**:
```bash
# Check connector status
curl http://localhost:8085/connectors/mysql-source-connector/status | jq

# Check logs
docker compose logs -f kafka-connect

# Send me the logs
```

---

## Summary of Commands

**Step 0**: Merge PR and pull changes
```bash
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
```

**Step 1**: Cleanup old tables
```bash
./scripts/00_cleanup_old_tables.sh
```

**Step 2**: Verify MySQL DDL files
```bash
cat schema_output/mysql_ddl/flatodd_member.sql | head -20
```

**Step 3**: Run conversion
```bash
python3 schema_output/convert_ddl_fixed.py
```

**Step 4**: Verify converted DDL
```bash
cat schema_output/clickhouse_ddl/flatodd_member.sql
```

**Step 5**: Create ClickHouse tables
```bash
./scripts/02_create_clickhouse_schema.sh
```

**Step 6**: Verify tables
```bash
docker exec -it clickhouse-server clickhouse-client
# Run queries from Step 6
```

**Step 7**: Deploy connectors
```bash
./scripts/03_deploy_connectors.sh
```

**Step 8**: Monitor progress
```bash
./scripts/04_monitor_snapshot.sh
```

**Step 9**: Validate data
```bash
./scripts/05_validate_data.sh
```

---

## Next Steps

After Phase 3 completes successfully:

1. **Enable Real-Time CDC** (when you have replication privileges)
   - Update Debezium connector config
   - Enable binlog streaming
   - Verify real-time updates

2. **Proceed to Phase 4**: Operations & BI Integration
   - Set up monitoring dashboards
   - Configure Power BI
   - Implement operational runbooks

---

## Support

**For each step**:
1. Run the command
2. Copy the entire output
3. Send it to me
4. Wait for my confirmation before proceeding to next step

This ensures we catch any issues early and don't compound problems.
