# Comprehensive DLQ Diagnostic Script - Usage Guide

## Overview

The `comprehensive_dlq_diagnostic.py` script is an intelligent, multi-phase diagnostic tool that analyzes your Kafka DLQ (Dead Letter Queue) messages to identify root causes of failures in your CDC pipeline.

## Features

✅ **Automatic Docker Management**
- Checks if required containers are running
- Automatically starts stopped containers
- Waits appropriate time for services to be ready
- Validates container health before proceeding

✅ **7-Phase Comprehensive Analysis**
1. Data Collection (DLQ messages, connector config, schemas)
2. Error Header Parsing (structured extraction)
3. Pattern Recognition (intelligent categorization)
4. Cross-Reference Validation (confirms root causes)
5. Statistical Analysis (quantifies impact)
6. Root Cause Determination (ranked by priority)
7. Report Generation (actionable outputs)

✅ **Intelligent Error Categorization**
- Schema mismatches (data type issues)
- Missing tables
- Primary key problems
- Transform errors (topic mapping)
- Connection failures
- Data overflow issues
- Encoding problems

✅ **Confidence Scoring**
- Each error gets a confidence score (0-100%)
- Multi-level pattern matching
- Exception class, keywords, and stage analysis

✅ **Actionable Outputs**
- Detailed text report
- JSON data export
- Auto-generated SQL fix scripts
- Suggested connector configuration
- Prioritized recommendations

---

## Prerequisites

- Python 3.6+
- Docker and Docker Compose running
- Access to your VPS with the ClickHouse project

---

## Installation

1. **Copy script to your VPS:**

```bash
# SSH into your VPS
ssh -i "C:\Users\sima\Documents\Convex\VPS\Convex_VPS" centos@142.93.168.177

# Navigate to your ClickHouse project directory
cd /path/to/your/clickhouse/project

# The script should already be there: comprehensive_dlq_diagnostic.py
```

2. **Make it executable (if not already):**

```bash
chmod +x comprehensive_dlq_diagnostic.py
```

3. **Verify Python version:**

```bash
python3 --version
# Should be 3.6 or higher
```

---

## Usage

### Basic Usage

Simply run the script - it handles everything automatically:

```bash
python3 comprehensive_dlq_diagnostic.py
```

Or:

```bash
./comprehensive_dlq_diagnostic.py
```

### What Happens Automatically

1. **Container Check**: Verifies Docker containers are running
2. **Auto-Start**: Starts any stopped containers
3. **Health Check**: Validates Redpanda, ClickHouse, Kafka Connect
4. **DLQ Analysis**: Fetches and analyzes up to 1000 DLQ messages
5. **Pattern Matching**: Categorizes errors intelligently
6. **Validation**: Cross-references with actual system state
7. **Report Generation**: Creates comprehensive reports

---

## Output Files

The script generates several files with timestamps:

### 1. **Text Report** (`dlq_diagnostic_report_YYYYMMDD_HHMMSS.txt`)

Human-readable comprehensive report including:
- Executive summary
- Top root causes (detailed)
- Recommended actions
- Affected tables and fields

**Example:**
```
TOP ROOT CAUSES (Detailed)

1. SCHEMA_MISMATCH
   Error Count: 45234 (67.2%)
   Affected Tables: orders, users, products
   Affected Fields: created_at, updated_at
   Fix Complexity: MEDIUM (Alter column types)
   Sample Error: Cannot convert MySQL DATETIME to ClickHouse Date...
```

### 2. **JSON Data** (`dlq_diagnostic_data_YYYYMMDD_HHMMSS.json`)

Machine-readable structured data for programmatic analysis:
- Complete statistics
- All root causes with details
- Connector configuration
- Error categorization

### 3. **SQL Fix Script** (`fix_schema_issues_YYYYMMDD_HHMMSS.sql`)

Auto-generated SQL commands to fix identified issues:

```sql
-- Fix DateTime range issues
ALTER TABLE analytics.orders MODIFY COLUMN created_at DateTime64(3);
ALTER TABLE analytics.users MODIFY COLUMN updated_at DateTime64(3);
```

**⚠️ Review before executing!**

### 4. **Suggested Config** (`suggested_connector_config_YYYYMMDD_HHMMSS.json`)

Recommended connector configuration changes:

```json
{
  "config": {
    "primary.key.mode": "record_value",
    "primary.key.fields": "id",
    "schema.evolution": "basic"
  }
}
```

---

## Understanding the Output

### Error Categories

**SCHEMA_MISMATCH**
- Data type incompatibilities between MySQL and ClickHouse
- Common: DateTime range issues, type conversions
- Fix: Alter ClickHouse column types

**MISSING_TABLE**
- Tables don't exist in ClickHouse
- Fix: Create tables before starting connector

**PRIMARY_KEY**
- NULL keys or key configuration issues
- Fix: Change `primary.key.mode` configuration

**TRANSFORM**
- RegexRouter pattern doesn't match topic names
- Fix: Update transform pattern in config

**CONNECTION**
- Timeouts, network issues
- Fix: Increase timeouts, check network

**DATA_OVERFLOW**
- Values exceed column size/range
- Fix: Use larger data types (e.g., Int64 instead of Int32)

**ENCODING**
- Character encoding mismatches
- Fix: Ensure UTF-8 encoding

### Priority Levels

- **CRITICAL** (≥50% of errors): Fix immediately
- **HIGH** (20-49%): Fix soon
- **MEDIUM** (5-19%): Address after critical/high
- **LOW** (<5%): Monitor, fix when convenient

---

## Common Scenarios

### Scenario 1: Script Says "DLQ topic doesn't exist"

**Meaning:** No errors have occurred, or DLQ isn't configured.

**Action:**
1. Check if connector is running and processing data
2. Verify DLQ configuration in connector config
3. If no errors, great! Your pipeline is working.

---

### Scenario 2: Container Auto-Start Fails

**Error:** "Some containers could not be started"

**Actions:**
1. Check Docker daemon: `sudo systemctl status docker`
2. Check if containers exist: `docker ps -a`
3. Check logs: `docker logs container-name`
4. Manual start: `docker-compose up -d`

---

### Scenario 3: ClickHouse Password Error

**Error:** Authentication failed

**Fix:** Update password in script (line 23):
```python
CLICKHOUSE_PASSWORD = "your_actual_password"
```

---

### Scenario 4: 67% Schema Mismatches (DateTime)

**Common Finding:**
```
CRITICAL: DateTime Range Mismatch [67.2% of errors]
- Fields: created_at, updated_at
- Cause: MySQL DATETIME (1000-9999) vs ClickHouse DateTime (1970-2106)
```

**Fix:**
```bash
# Apply generated SQL script
clickhouse-client --password 'password' < fix_schema_issues_*.sql
```

Or manually:
```sql
ALTER TABLE analytics.orders MODIFY COLUMN created_at DateTime64(3);
```

---

## Advanced Usage

### Analyze More Messages

Edit the script (line 24) to increase sample size:
```python
SAMPLE_SIZE = 5000  # Analyze more messages
```

### Change Database/Password

Edit configuration at the top of the script:
```python
CLICKHOUSE_PASSWORD = "your_password"
CLICKHOUSE_USER = "your_user"
CLICKHOUSE_DATABASE = "your_database"
```

### Export to Different Format

The JSON output can be imported into:
- Excel/Google Sheets (convert JSON to CSV)
- BI tools (Power BI can read JSON)
- Custom dashboards (Grafana, etc.)

---

## Troubleshooting

### "rpk command not found"

**Cause:** Script trying to run Redpanda commands in wrong container

**Fix:** Check container names match:
```bash
docker ps --format "{{.Names}}"
```

If different, update `REQUIRED_CONTAINERS` in script.

---

### "Permission denied" on Docker commands

**Fix:** Run with sudo or add user to docker group:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

---

### Script hangs at "Fetching DLQ messages"

**Cause:** Large DLQ topic (>100k messages)

**Fix:**
1. Wait (can take 2-3 minutes)
2. Or reduce SAMPLE_SIZE in script
3. Or: `docker exec redpanda-clickhouse rpk topic trim clickhouse-dlq --offset 50000`

---

### "No Python 3" error

**Fix:**
```bash
# CentOS/RHEL
sudo yum install python3

# Ubuntu/Debian
sudo apt install python3
```

---

## What to Do After Analysis

### Step 1: Review Text Report

```bash
cat dlq_diagnostic_report_*.txt
```

Focus on:
- Top 3 root causes (usually fix 95%+ of issues)
- Recommended actions
- Fix complexity

### Step 2: Apply Fixes Based on Priority

**For SCHEMA_MISMATCH:**
```bash
# Review SQL script
cat fix_schema_issues_*.sql

# Apply to ClickHouse
docker exec -it clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  < fix_schema_issues_*.sql
```

**For PRIMARY_KEY:**
```bash
# Update connector config with suggested settings
# Then redeploy connector
curl -X DELETE http://localhost:8085/connectors/clickhouse-sink-connector
curl -X POST http://localhost:8085/connectors \
  -H "Content-Type: application/json" \
  -d @suggested_connector_config_*.json
```

**For MISSING_TABLE:**
```bash
# Create missing tables (script will list them)
# Use MySQL schema as reference
```

### Step 3: Clean Up DLQ (After Fixes)

```bash
# Only after confirming fixes work!
docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq
```

### Step 4: Monitor

```bash
# Re-run diagnostic after fixes
python3 comprehensive_dlq_diagnostic.py

# Should show dramatically fewer errors
```

---

## Performance Notes

- **Analysis Time:** 1-5 minutes for 1000 messages
- **Memory Usage:** <500MB typically
- **Disk Space:** Reports ~1-5MB total

---

## Integration with CI/CD

You can run this script automatically:

```bash
# In cron (daily analysis)
0 2 * * * cd /path/to/project && python3 comprehensive_dlq_diagnostic.py >> /var/log/dlq_analysis.log 2>&1

# Alert if errors found
python3 comprehensive_dlq_diagnostic.py && mail -s "DLQ Analysis" admin@example.com < dlq_diagnostic_report_*.txt
```

---

## FAQ

**Q: Will this script make any changes to my system?**
A: No, it's read-only. It only analyzes and generates reports. The fix scripts must be manually reviewed and applied.

**Q: Can I run this on my local machine instead of VPS?**
A: No, it needs to run where Docker containers are (your VPS).

**Q: How often should I run this?**
A: When you notice DLQ growing, or weekly as a health check.

**Q: What if I get "UNKNOWN" category errors?**
A: Check the JSON output for raw error messages. May need manual investigation.

**Q: Does it work with other databases (not ClickHouse)?**
A: The core DLQ analysis works with any Kafka Connect sink. ClickHouse-specific validation would need adjustment.

---

## Support

If you encounter issues:

1. Check container logs:
   ```bash
   docker logs redpanda-clickhouse
   docker logs kafka-connect-clickhouse
   docker logs clickhouse-server
   ```

2. Verify containers are running:
   ```bash
   docker ps
   ```

3. Check the JSON output for raw error data

4. Review the script's console output for specific error messages

---

## Next Steps

After running diagnostics and applying fixes:

1. **Monitor DLQ**: `docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq`
2. **Check data flow**: Verify data arriving in ClickHouse tables
3. **Consider alternatives**: If CDC remains problematic, see `ALTERNATIVE_SOLUTIONS.md` for simpler architectures (Python ETL recommended for BI use cases)

---

**Happy Debugging!** 🚀
