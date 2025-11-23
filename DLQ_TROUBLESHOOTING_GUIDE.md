# DLQ Troubleshooting Guide

## 🚨 Your Current Situation

- **Problem:** Most data going to `clickhouse-dlq` instead of ClickHouse tables
- **Impact:** 250GB Kafka storage for 22GB database (10x overhead!)
- **Root Cause:** `"errors.tolerance": "all"` + underlying data/schema issues

---

## 🔍 Step 1: Diagnose (Find the Real Problem)

**Run the diagnostic script on your VPS:**

```bash
# SSH into your VPS
ssh -i "C:\Users\sima\Documents\Convex\VPS\Convex_VPS" centos@142.93.168.177

# Navigate to project
cd /path/to/your/clickhouse/project

# Make script executable
chmod +x diagnose_and_fix_dlq.sh

# Run diagnostics
./diagnose_and_fix_dlq.sh
```

**This will show you:**
1. ✅ Connector status (running/failed?)
2. ✅ Storage breakdown (what's using space?)
3. ✅ **Sample DLQ errors** ← This is KEY!
4. ✅ Configuration issues
5. ✅ Recommended fixes

---

## 🐛 Step 2: Identify Root Cause

Look at the **"Sample DLQ Errors"** section from the diagnostic output.

### Common Issues and Solutions:

#### ❌ Error: "Table doesn't exist"
**Cause:** ClickHouse tables not created before data arrives
**Fix:**
```sql
-- Create missing tables in ClickHouse
-- Match the structure from your MySQL tables
```

---

#### ❌ Error: "Data type mismatch" or "Cannot convert"
**Cause:** MySQL and ClickHouse column types don't match
**Fix:** Update ClickHouse table schemas to match MySQL types

**Example mappings:**
```
MySQL              → ClickHouse
VARCHAR(255)       → String
INT                → Int32
BIGINT             → Int64
DATETIME           → DateTime
DECIMAL(10,2)      → Decimal(10,2)
TEXT               → String
JSON               → String (store as JSON string)
```

---

#### ❌ Error: "Primary key constraint violation" or "Duplicate key"
**Cause:** `primary.key.mode: "record_key"` but keys are missing/null
**Fix:** Change connector config:

```json
{
  "primary.key.mode": "record_value",
  "primary.key.fields": "id"  // Your actual primary key column
}
```

---

#### ❌ Error: "Transform error" or "Topic not found"
**Cause:** RegexRouter transform pattern doesn't match topic names
**Fix:** Check your topics vs. transform pattern

**Your topics:** `mysql.your_database.table_name`
**Transform should be:** `mysql\.your_database\.(.*)`
**Result:** `table_name`

---

#### ❌ Error: "Schema evolution disabled"
**Cause:** MySQL schema changed but ClickHouse didn't
**Fix:** Update connector config:

```json
{
  "schema.evolution": "basic"  // Allows adding columns
}
```

---

## 🔧 Step 3: Fix the Issue

### Option A: Quick Fix (Recommended First)

1. **Temporarily disable error tolerance** to see real errors:

Edit `configs/connectors/clickhouse-sink.json`:
```json
{
  "errors.tolerance": "none",  // Changed from "all"
  "errors.log.enable": "true"
}
```

2. **Redeploy connector:**
```bash
curl -X DELETE http://localhost:8085/connectors/clickhouse-sink-connector
# Wait 5 seconds
curl -X POST http://localhost:8085/connectors \
  -H "Content-Type: application/json" \
  -d @configs/connectors/clickhouse-sink.json
```

3. **Watch logs immediately:**
```bash
docker logs -f kafka-connect-clickhouse
```

4. **The connector will fail fast** and show you the EXACT error
5. **Fix that specific error** (table, schema, data type, etc.)
6. **Restart and test**

---

### Option B: Clean Slate Approach

If you want to start fresh:

```bash
# Run cleanup script
chmod +x cleanup_dlq_and_restart.sh
./cleanup_dlq_and_restart.sh

# This will:
# - Stop connector
# - Delete DLQ topic (frees up 250GB!)
# - Optionally clean old topics
# - Guide you through restart
```

---

## 🧹 Step 4: Clean Up Storage

After fixing the issue:

```bash
# Delete DLQ topic
docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq

# Check storage savings
docker system df

# Optional: Prune unused Docker resources
docker system prune -a --volumes
```

---

## ✅ Step 5: Prevent Future Issues

### Update Connector Config:

```json
{
  // EITHER: Fail fast (recommended during debugging)
  "errors.tolerance": "none",

  // OR: Log errors but continue (once stable)
  "errors.tolerance": "all",
  "errors.deadletterqueue.topic.name": "clickhouse-dlq",

  // Enable schema evolution
  "schema.evolution": "basic",

  // Use sensible retries
  "max.retries": "3",
  "retry.backoff.ms": "5000",

  // Better primary key handling
  "primary.key.mode": "record_value",
  "primary.key.fields": "id"
}
```

### Monitor Regularly:

```bash
# Check connector status
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | python3 -m json.tool

# Check DLQ size
docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq

# Check ClickHouse data arrival
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query "SELECT name, total_rows FROM system.tables WHERE database = 'analytics'"
```

---

## 🆘 Still Having Issues?

### Consider Simpler Alternatives:

If CDC continues to be problematic, see **ALTERNATIVE_SOLUTIONS.md** for:
1. **Python ETL** (recommended for BI use cases) - Simple, reliable
2. **ClickHouse MySQL Engine** - Zero infrastructure
3. **Debezium Server** (no Kafka) - Simpler CDC
4. **Apache Airflow** - Enterprise ETL

**For BI/Power BI use case:** Python ETL running every 15 minutes is often the sweet spot between simplicity and freshness.

---

## 📋 Checklist

- [ ] Run `diagnose_and_fix_dlq.sh` on VPS
- [ ] Review sample DLQ errors
- [ ] Identify root cause category
- [ ] Fix the specific issue (schema, config, etc.)
- [ ] Set `errors.tolerance: "none"` temporarily
- [ ] Redeploy connector
- [ ] Monitor logs for immediate errors
- [ ] Fix any new errors that appear
- [ ] Once stable, clean up DLQ
- [ ] Consider switching to simpler architecture

---

## 🎯 Expected Outcome

After fixing:
- ✅ Data flows to ClickHouse tables (not DLQ)
- ✅ Kafka storage drops from 250GB to < 10GB
- ✅ Connector runs without errors
- ✅ Power BI shows real-time data
- ✅ Snapshot completes successfully

---

## 📞 Quick Commands Reference

```bash
# Check connector status
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status

# View connector config
curl -s http://localhost:8085/connectors/clickhouse-sink-connector

# Restart connector
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart

# Delete DLQ
docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq

# Check ClickHouse tables
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query "SHOW TABLES FROM analytics"

# Check data in ClickHouse
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query "SELECT count() FROM analytics.your_table_name"
```

Good luck! 🚀
