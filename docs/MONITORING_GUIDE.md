# Monitoring Script Guide

## Overview

The enhanced `04_monitor_snapshot.sh` script provides comprehensive real-time monitoring of your MySQL → ClickHouse CDC pipeline.

## What You'll See

### 1. Connector Status Section

**MySQL Source Connector:**
```
▶ Connector Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MySQL Source Connector: RUNNING
    Worker: kafka-connect-clickhouse:8083
    Tasks: 1/1 RUNNING
      Task 0: RUNNING (worker: kafka-connect-clickhouse:8083)
```

**If you see 0/1 tasks (THE PROBLEM):**
```
  MySQL Source Connector: RUNNING
    Worker: kafka-connect-clickhouse:8083
    Tasks: 0/1 (NO TASKS CREATED!)
    ⚠ WARNING: Source connector has no tasks!
    Snapshot cannot proceed without tasks.
```

**ClickHouse Sink Connector:**
```
  ClickHouse Sink Connector: RUNNING
    Worker: kafka-connect-clickhouse:8083
    Tasks: 4/4 RUNNING
      Task 0: RUNNING (worker: kafka-connect-clickhouse:8083)
      Task 1: RUNNING (worker: kafka-connect-clickhouse:8083)
      Task 2: RUNNING (worker: kafka-connect-clickhouse:8083)
      Task 3: RUNNING (worker: kafka-connect-clickhouse:8083)
```

### 2. Kafka Topics Section

Shows Redpanda topic creation progress with visual progress bar:

```
▶ Kafka Topics (Redpanda)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Topics Created: 245 / 450
  [████████████████████░░░░░░░░░░░░░░░░░░░░]  54% (245/450)
  Rate: 12.5 topics/min
  ETA: ~16 minutes remaining

  Sample topics:
    • mysql.mulazamflatoddbet.flatodd_member
    • mysql.mulazamflatoddbet.baccarat_bet
    • mysql.mulazamflatoddbet.user_account
    • mysql.mulazamflatoddbet.transaction_log
    • mysql.mulazamflatoddbet.game_session
    ... and 240 more
```

### 3. ClickHouse Data Section

Shows table population progress and data statistics:

```
▶ ClickHouse Analytics Database
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total Tables: 450
  Tables with Data: 245
  Empty Tables: 205

  [████████████████████░░░░░░░░░░░░░░░░░░░░]  54% (245/450)

  Total Rows: 12,458,932
  Total Size: 3.45 GB
  Insertion Rate: 45,231 rows/sec

  Top 10 Tables by Row Count:
    ┌─name──────────────┬─rows─────┬─size────┐
    │ flatodd_member    │ 1.2M     │ 245 MB  │
    │ baccarat_bet      │ 856K     │ 189 MB  │
    │ transaction_log   │ 743K     │ 167 MB  │
    │ game_session      │ 623K     │ 134 MB  │
    │ user_activity     │ 521K     │ 112 MB  │
    │ slot_spin         │ 489K     │ 98 MB   │
    │ bonus_transaction │ 412K     │ 87 MB   │
    │ login_history     │ 367K     │ 76 MB   │
    │ payment_record    │ 334K     │ 71 MB   │
    │ withdrawal_request│ 298K     │ 64 MB   │
    └───────────────────┴──────────┴─────────┘
```

### 4. Issues Detection Section

**When there are problems:**

```
▶ ⚠ Issues Detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✗ MySQL source connector has NO TASKS
    This means the snapshot cannot start.
    Possible causes:
      • MySQL binlog not enabled
      • Missing MySQL user permissions (REPLICATION SLAVE/CLIENT)
      • MySQL connectivity issues

    Run: ./diagnose_mysql_connector.sh to identify the issue

  Recent errors from Kafka Connect logs:
    ERROR WorkerSourceTask{id=mysql-source-connector-0} Task threw an uncaught...
    ERROR Failed to start connector mysql-source-connector...
```

### 5. Summary Line

Shows overall status at bottom:

**Healthy snapshot in progress:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Status: Snapshot in progress (15m 32s elapsed)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**When issues detected:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Status: ISSUES DETECTED - Review warnings above
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**When snapshot complete:**
```
▶ ✓ Snapshot Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  All tables have been snapshotted successfully!

  Final Statistics:
    • Topics created: 450
    • Tables populated: 450
    • Total rows: 21,847,523
    • Total time: 48m 15s

  The pipeline is now in CDC mode (real-time replication).

  Next steps:
    1. Verify data accuracy with sample queries
    2. Test CDC by making changes in MySQL
    3. Monitor for ongoing errors
```

---

## Key Metrics Explained

### Tasks (Critical!)

**MySQL Source Tasks:**
- **Expected:** 1/1 RUNNING
- **Problem:** 0/1 (NO TASKS) ← This prevents snapshot from starting
- **Problem:** 1/1 FAILED ← Connector error

**ClickHouse Sink Tasks:**
- **Expected:** 4/4 RUNNING (4 parallel workers for faster ingestion)
- **Degraded:** 3/4 RUNNING (1 failed, but still works at reduced speed)
- **Problem:** 0/4 or all FAILED

### Topics Created

- **0 topics** = Snapshot hasn't started (check MySQL source tasks)
- **Increasing count** = Snapshot in progress
- **450 topics** = All MySQL tables have been captured

### Tables with Data

- **Should match topic count** (with small delay)
- **If much lower than topics** = Sink connector may have issues
- **If 0 despite topics existing** = ClickHouse sink is failing

### Insertion Rate

- **Normal:** 10,000 - 100,000 rows/sec (depends on data size)
- **0 rows/sec** = May be between batches (normal if occasional)
- **Consistently 0** = Problem with sink connector

---

## Using the Monitor

### Start Monitoring

```bash
cd /home/centos/clickhouse/phase3/scripts
./04_monitor_snapshot.sh
```

The script updates every 10 seconds automatically.

### Interpreting Results

**Healthy Snapshot:**
1. MySQL Source: RUNNING with 1/1 tasks
2. ClickHouse Sink: RUNNING with 4/4 tasks
3. Topics increasing steadily
4. Tables with data matching topics
5. Insertion rate > 0

**Stuck Snapshot (Current Issue):**
1. MySQL Source: RUNNING but **0/1 tasks** ← THE PROBLEM
2. Topics: 0 (not increasing)
3. Tables with data: 0
4. Issues section shows "NO TASKS" warning

**Failed Snapshot:**
1. Connector state: FAILED
2. Tasks: FAILED
3. Issues section shows error messages

### What to Do When Issues Detected

The monitoring script will tell you exactly what's wrong in the "Issues Detected" section.

**For "NO TASKS" issue:**
```bash
# Run diagnostic script
./diagnose_mysql_connector.sh

# Check the detailed fix guide
cat ../MYSQL_CONNECTOR_FIX.md
```

**For other errors:**
- Check the error trace shown in the output
- Look at recent Kafka Connect logs displayed
- Run suggested diagnostic commands

---

## Stopping the Monitor

Press `Ctrl+C` to stop monitoring at any time.

The snapshot will continue running in the background - the monitor is just for viewing progress.

---

## Monitor Comparison

### Old Monitor (Before)
- Basic connector status
- Topic count only
- Basic row count
- No task details
- No error detection
- No progress bars
- No rate calculations

### New Monitor (After)
✅ Detailed task status for BOTH connectors
✅ Individual task breakdown (ID, state, worker)
✅ Visual progress bars
✅ Real-time rates (topics/min, rows/sec)
✅ ETA calculations
✅ Top 10 tables display
✅ Comprehensive error detection
✅ Clear warnings when 0 tasks
✅ Auto-completion detection
✅ Color-coded visual indicators
✅ Human-readable formatting

---

## Quick Reference

| Metric | Good | Warning | Problem |
|--------|------|---------|---------|
| MySQL Source Tasks | 1/1 RUNNING | 0/1 (starting) | 0/1 after 1 min |
| Sink Tasks | 4/4 RUNNING | 3/4 RUNNING | 0/4 or all FAILED |
| Topics | Increasing | Slow increase | 0 after 5 min |
| Tables w/ Data | ~Same as topics | Lagging topics | 0 despite topics |
| Insertion Rate | >10K rows/sec | Occasional 0 | Consistently 0 |

---

## Example Session

**Pull latest code:**
```bash
cd /home/centos/clickhouse
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
```

**After deploying connectors:**
```bash
cd phase3/scripts
./04_monitor_snapshot.sh
```

**Expected timeline:**
- 0-30 sec: Connectors starting, tasks being created
- 30 sec - 1 min: First topics appear
- 1-45 min: Steady topic/table growth
- 45-60 min: Snapshot completes, all 450 tables populated

**If you see 0/1 tasks after 1 minute:**
```bash
# Stop monitoring (Ctrl+C)
# Run diagnostic
./diagnose_mysql_connector.sh

# Fix the root cause (likely binlog or permissions)
# Then redeploy connectors
./03_deploy_connectors.sh

# Resume monitoring
./04_monitor_snapshot.sh
```

---

## The monitor will clearly show you the 0/1 tasks issue you're experiencing!

This is the critical blocker preventing your snapshot from starting.
