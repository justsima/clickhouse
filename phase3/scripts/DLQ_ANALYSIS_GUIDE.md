# DLQ Analysis & Snapshot Verification Guide

This guide explains how to use the three scripts created to verify snapshot completion and analyze your 50GB+ DLQ data in depth.

## Scripts Overview

### 1. `snapshot_status.sh` - Quick Snapshot Check
**Purpose:** Fast check to see if the CDC snapshot is complete
**Runtime:** 5-10 seconds
**Use When:** You want to quickly check if snapshot is done

```bash
cd /home/user/clickhouse/phase3/scripts
./snapshot_status.sh
```

**What it checks:**
- Consumer lag (0 = snapshot complete)
- Estimated time remaining if still in progress
- Per-partition lag details

**Output:**
- ✓ SNAPSHOT IS COMPLETE (lag = 0)
- ℹ SNAPSHOT IN PROGRESS (shows remaining messages and ETA)

---

### 2. `deep_dlq_analysis.sh` - Comprehensive DLQ Analysis
**Purpose:** Complete analysis of DLQ with snapshot verification
**Runtime:** 5-15 minutes (depending on DLQ size)
**Use When:** You want the full picture of DLQ errors and data sync quality

```bash
cd /home/user/clickhouse/phase3/scripts
./deep_dlq_analysis.sh
```

**What it analyzes:**

1. **Snapshot Completion Status**
   - Consumer lag check
   - ETA calculation if in progress

2. **DLQ Topic Overview**
   - Total DLQ messages (exact count)
   - DLQ disk usage (shows if it's really 50GB+)
   - Messages per partition

3. **Table Identification**
   - Samples first 10,000 DLQ messages
   - Extracts which tables have errors
   - Shows error count per table

4. **Error Pattern Analysis**
   - Categorizes ClickHouse error codes
   - Shows most common errors (Code: 1001, 27, 44, etc.)
   - Sample error messages

5. **Data Sync Percentage**
   - Compares MySQL total vs ClickHouse total
   - Calculates success rate
   - Shows DLQ percentage
   - Explains if ClickHouse has MORE rows (CDC capturing changes)

6. **Recommendations**
   - Based on DLQ size, provides specific actions
   - Shows how to investigate specific tables

**Example Output:**
```
Snapshot Status: COMPLETE
Total DLQ Messages: 1,234,567
DLQ Disk Usage: 52GB
Affected Tables: 23

Data Sync Quality:
  Success Rate: 97.54%
  DLQ Rate: 2.46%
```

---

### 3. `dlq_table_breakdown.sh` - Detailed Table-by-Table Analysis
**Purpose:** Deep dive into which specific tables are in DLQ and why
**Runtime:** 10-30 minutes (for 50GB+ DLQ)
**Use When:** You need to know EXACTLY which tables have errors and what to fix

```bash
cd /home/user/clickhouse/phase3/scripts
./dlq_table_breakdown.sh

# Or analyze more messages (default is 20,000)
./dlq_table_breakdown.sh 50000  # Analyze 50k messages
```

**What it provides:**

1. **DLQ Overview**
   - Total message count
   - Disk usage

2. **Table Error Counts**
   - Ranked list of tables by error count
   - Percentage of errors per table
   - Shows top 50 tables

3. **Error Types by Table (Top 10)**
   - For each top table, shows:
     - Specific ClickHouse error codes
     - Error code descriptions
     - Sample error messages

4. **Recommended Actions**
   - Exact commands to compare schemas
   - How to check sample data
   - How to verify table existence

5. **Extrapolation to Total DLQ**
   - If sampling (e.g., 20k out of 1M messages)
   - Estimates total errors per table
   - Shows sample percentage coverage

**Example Output:**
```
DLQ Errors by Table (from 20,000 message sample):
───────────────────────────────────────────────
ERRORS     TABLE NAME                            PERCENTAGE
───────────────────────────────────────────────
5,234      payment                               42.35%
2,891      rental                                23.41%
1,456      inventory                             11.79%
987        customer                              7.99%
...

Extrapolated Total Errors (estimate):
  payment:    ~261,700 errors (of 50GB total)
  rental:     ~144,550 errors
  inventory:  ~72,800 errors
```

---

## Recommended Usage Flow

### Step 1: Quick Status Check
Start with the quick check to see if snapshot is done:

```bash
./snapshot_status.sh
```

If it shows **COMPLETE**, proceed to DLQ analysis. If **IN PROGRESS**, wait until lag reaches 0.

---

### Step 2: Full DLQ Analysis
Once snapshot is complete, run the comprehensive analysis:

```bash
./deep_dlq_analysis.sh
```

This will show:
- Total DLQ size (verify the 50GB claim)
- Overall success rate
- Affected tables count

If DLQ is significant (>1% of data), proceed to detailed breakdown.

---

### Step 3: Table-by-Table Investigation
For detailed investigation of specific tables:

```bash
# Start with 20k message sample (fast)
./dlq_table_breakdown.sh

# If you need more precision with 50GB DLQ, analyze more
./dlq_table_breakdown.sh 100000  # 100k messages
```

This will show:
- Exactly which tables have the most errors
- What error codes are occurring
- Specific commands to investigate each table

---

## Understanding the Results

### Snapshot Status

**COMPLETE (lag = 0)**
- All initial data has been synced
- CDC is now only capturing ongoing changes
- Safe to proceed with DLQ analysis

**IN PROGRESS (lag > 0)**
- Still syncing initial snapshot
- Wait until lag reaches 0
- DLQ analysis may be incomplete

### DLQ Analysis

**DLQ Rate < 1%**
- Excellent sync quality
- Minor errors are normal (data type mismatches, etc.)
- No action needed unless specific tables are critical

**DLQ Rate 1-5%**
- Good sync quality
- Review top tables with errors
- Fix schema mismatches if needed
- Consider replaying DLQ for critical tables

**DLQ Rate > 5%**
- Investigate immediately
- Likely schema or configuration issues
- Fix root cause before continuing

### Common Error Codes

| Code | Description | Common Cause | Fix |
|------|-------------|--------------|-----|
| 1001 | Generic exception | std::bad_function_call, batch failures | Check ClickHouse version, review table schemas |
| 27   | Type mismatch | Column type doesn't match data | Align MySQL and ClickHouse column types |
| 44   | Cannot insert NULL | NOT NULL constraint violated | Check NULL constraints in ClickHouse |
| 6    | Cannot parse data | Data format issue | Review data formats and transformations |
| 16   | Table does not exist | Table not created in ClickHouse | Ensure table exists before CDC |

---

## Investigating Specific Tables

After running `dlq_table_breakdown.sh`, you'll get specific commands for each table. Example:

```bash
# For table 'payment' with high DLQ errors:

# 1. Compare schemas
docker exec mysql-clickhouse mysql -u root -p$MYSQL_PASSWORD sakila -e "DESCRIBE payment"
docker exec clickhouse-server clickhouse-client --password $CLICKHOUSE_PASSWORD --query "DESCRIBE sakila.payment"

# 2. Check sample data
docker exec mysql-clickhouse mysql -u root -p$MYSQL_PASSWORD sakila -e "SELECT * FROM payment LIMIT 5"

# 3. Verify table exists and has data
docker exec clickhouse-server clickhouse-client --password $CLICKHOUSE_PASSWORD --query "SELECT count() FROM sakila.payment"
```

Look for:
- Column type differences (e.g., DECIMAL vs Float64)
- NULL constraints (MySQL allows NULL, ClickHouse doesn't)
- Missing columns
- Column name differences

---

## Performance Notes

### For 50GB+ DLQ:

**`deep_dlq_analysis.sh`**
- Samples 10,000 messages (fast)
- Provides good overview
- Runtime: ~5-10 minutes

**`dlq_table_breakdown.sh`**
- Default samples 20,000 messages
- For 50GB, consider analyzing 50k-100k for better accuracy
- Runtime scales with sample size:
  - 20k messages: ~10 minutes
  - 50k messages: ~20 minutes
  - 100k messages: ~30 minutes

**Tip:** Start with default sample size. If results show many affected tables, run again with larger sample for precision.

---

## What to Expect with 50GB DLQ

If you truly have 50GB of DLQ data, this indicates:

**Approximate message count:**
- Assuming ~50KB per message: ~1,000,000 messages
- Assuming ~10KB per message: ~5,000,000 messages

**This means:**
- Significant portion of data failed to sync
- Likely systematic schema or configuration issue
- Not random errors - pattern will be clear

**The scripts will:**
1. Identify the exact tables affected
2. Show the specific error codes
3. Provide commands to investigate
4. Help you fix the root cause

**Expected findings:**
- Probably 5-20 tables causing most errors
- Likely Code:1001 or Code:27 (schema issues)
- Clear pattern pointing to specific fix

---

## Next Steps After Analysis

Based on DLQ analysis results:

1. **Fix Schema Issues**
   - Align MySQL and ClickHouse column types
   - Adjust NULL constraints
   - Add missing columns

2. **Recreate Tables if Needed**
   ```bash
   # Drop and recreate ClickHouse table with correct schema
   docker exec clickhouse-server clickhouse-client --password $CLICKHOUSE_PASSWORD \
     --query "DROP TABLE IF EXISTS sakila.payment"

   # Recreate with correct schema matching MySQL
   ```

3. **Reset Connector (if needed)**
   ```bash
   # Delete connector
   curl -X DELETE http://localhost:8085/connectors/mysql-source-connector

   # Recreate connector with fixed configuration
   # This will re-snapshot from MySQL (may take time)
   ```

4. **Monitor DLQ Going Forward**
   ```bash
   # Set up periodic checks
   watch -n 60 './snapshot_status.sh'
   ```

---

## Troubleshooting

### Script hangs at "Consuming messages"
- Large DLQ takes time
- Wait up to 5 minutes
- Script has 300-second timeout

### "Cannot connect to Redpanda"
- Check if Redpanda is running:
  ```bash
  docker ps | grep redpanda
  docker start redpanda-clickhouse  # if stopped
  ```

### "Could not parse DLQ message count"
- Try running with sudo
- Check Redpanda logs:
  ```bash
  docker logs redpanda-clickhouse --tail 50
  ```

### "No table names found in DLQ"
- DLQ message format may be different
- Check raw message structure:
  ```bash
  docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
    --brokers localhost:9092 --num 5
  ```

---

## Summary

**To answer your questions:**

1. **"Is snapshot completed?"**
   ```bash
   ./snapshot_status.sh
   ```
   Look for "SNAPSHOT IS COMPLETE" or lag = 0

2. **"Check DLQ in depth with 50GB+ data"**
   ```bash
   ./deep_dlq_analysis.sh          # Overall analysis
   ./dlq_table_breakdown.sh 50000  # Detailed breakdown
   ```

3. **"Analysis on DLQ tables correctly"**
   - Scripts extract table names from messages
   - Show error counts per table
   - Provide specific investigation commands
   - Extrapolate sample to total DLQ size

Run these scripts in order, and you'll have complete visibility into your CDC pipeline health and DLQ status.
