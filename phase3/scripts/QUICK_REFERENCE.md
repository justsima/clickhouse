# Quick Reference - DLQ Analysis Scripts

## Three Scripts - One Goal: Understand Your 50GB+ DLQ

### 1️⃣ Quick Check (10 seconds)
```bash
./snapshot_status.sh
```
**Answers:** Is snapshot done? How much lag remains?

---

### 2️⃣ Full Analysis (5-10 min)
```bash
./deep_dlq_analysis.sh
```
**Answers:**
- How big is the DLQ really? (verify 50GB)
- What's my success rate?
- Which tables are affected?
- What error patterns exist?

---

### 3️⃣ Table Breakdown (10-30 min)
```bash
./dlq_table_breakdown.sh
```
**Answers:**
- Which specific tables have the most errors?
- What error codes per table?
- How to fix each table?

---

## Quick Start

```bash
cd /home/user/clickhouse/phase3/scripts

# Step 1: Check if snapshot is complete
./snapshot_status.sh

# Step 2: Full DLQ analysis
./deep_dlq_analysis.sh

# Step 3: Detailed table-by-table (if DLQ > 1%)
./dlq_table_breakdown.sh
```

---

## What You'll Learn

✅ Snapshot completion status (lag = 0?)
✅ Exact DLQ message count
✅ DLQ disk usage (is it really 50GB?)
✅ Success rate (e.g., 97.5% synced)
✅ Which tables have errors
✅ Error codes and meanings
✅ Specific commands to investigate each table
✅ Recommendations for fixes

---

## Common Results

**Scenario 1: Small DLQ (<1GB, <1%)**
```
Result: Success rate 99%+
Action: No action needed - normal CDC operation
```

**Scenario 2: Medium DLQ (1-10GB, 1-5%)**
```
Result: Success rate 95-99%
Action: Review top 3-5 tables, fix schema mismatches
```

**Scenario 3: Large DLQ (50GB+, >5%)**
```
Result: Success rate <95%
Action: Systematic issue - investigate immediately
        Likely schema mismatch or config error
        Fix root cause before continuing
```

---

## Error Code Quick Reference

| Code | Fix |
|------|-----|
| 1001 | Check ClickHouse version, review schemas |
| 27   | Align column types between MySQL and ClickHouse |
| 44   | Check NOT NULL constraints |
| 6    | Review data formats |

---

## Need Help?

See full guide: `DLQ_ANALYSIS_GUIDE.md`

Or check other diagnostic scripts:
- `./check_connector_health.sh` - Connector status
- `./analyze_connector_logs.sh` - Log analysis
- `./which_logs_to_check.sh` - Log guide
