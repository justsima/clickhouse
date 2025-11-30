# MySQL to ClickHouse CDC Migration Project Summary

## Project Overview

**Objective**: Migrate data from DigitalOcean Managed MySQL to ClickHouse for analytics, with real-time CDC (Change Data Capture) synchronization and Power BI integration.

**Start Date**: November 26, 2025  
**Current Status**: ✅ Core migration complete, Power BI integration in progress

---

## Infrastructure

### Source Database (MySQL)

| Field     | Value                                                                     |
| --------- | ------------------------------------------------------------------------- |
| Host      | `mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com` |
| Port      | `25060`                                                                   |
| Database  | `mulazamflatoddbet`                                                       |
| User      | `mulasport`                                                               |
| SSL       | Required                                                                  |
| Tables    | ~450 tables                                                               |
| Data Size | ~22 GB                                                                    |

### Target Database (ClickHouse)

| Field         | Value             |
| ------------- | ----------------- |
| Host          | `142.93.168.177`  |
| HTTP Port     | `8123`            |
| Native Port   | `9000`            |
| Database      | `airbyte_cdc`     |
| Username      | `default`         |
| Password      | `clickhouse@2025` |
| Tables Synced | 73 tables         |
| Rows Synced   | 45+ million       |

### VPS Server

| Field    | Value                              |
| -------- | ---------------------------------- |
| IP       | `142.93.168.177`                   |
| OS       | CentOS 8                           |
| CPU      | 32 cores                           |
| RAM      | 62 GB                              |
| Disk     | 800 GB (237 GB free after cleanup) |
| SSH User | `centos`                           |

---

## Completed Tasks

### Phase 0: Environment Validation ✅

- [x] Created validation script (`airbyte/phase0/validate_phase0.sh`)
- [x] Verified VPS meets requirements (CPU, RAM, Disk)
- [x] Confirmed Docker installation (v26.1.3)
- [x] Verified network connectivity to MySQL source
- [x] Confirmed MySQL binlog/GTID enabled for CDC

### Phase 1: Airbyte Deployment ✅

- [x] Installed `abctl` (Airbyte CLI) v0.30.3
- [x] Deployed Airbyte OSS v2.0.1 via kind Kubernetes cluster
- [x] Configured Airbyte password (`airbyte@2025`)
- [x] Verified Airbyte accessible at `http://localhost:8000`
- [x] Created deployment script (`airbyte/phase1/deploy_airbyte.sh`)

### Phase 2: Connector Configuration ✅

- [x] Created MySQL source connector in Airbyte
  - Configured with SSL/TLS
  - Initially set up with CDC mode (later changed to Full Refresh)
- [x] Created ClickHouse destination connector
  - Used Docker bridge IP `172.17.0.1` for container connectivity
  - Database: `airbyte_cdc`
- [x] Resolved CDC cursor issues by switching to "Full refresh | Overwrite" mode
- [x] Created connector validation script (`airbyte/phase2/configure_connectors.sh`)

### Phase 3: Initial Data Sync ✅

- [x] Resolved disk space issues
  - Identified `phase2_redpanda_data` volume using 216 GB
  - Cleaned up old Docker volumes
  - Recovered 217 GB disk space (71% usage, 237 GB free)
- [x] Configured sync for 73 selected tables
- [x] Completed initial sync: **73 tables, 45+ million rows**
- [x] Verified data integrity in ClickHouse
- [x] Created sync validation script (`airbyte/phase3/validate_sync.sh`)

### Phase 4: ClickHouse Public Access ✅

- [x] Installed `firewalld` on VPS
- [x] Opened ports 8123 (HTTP) and 9000 (Native) in firewall
- [x] Restarted ClickHouse with public binding (`0.0.0.0`)
- [x] Configured password authentication (`clickhouse@2025`)
- [x] Verified public access from external machines
- [x] Shared credentials with backend team

### Phase 5: Power BI Integration 🔄 (In Progress)

- [x] Installed ClickHouse ODBC driver on Windows
- [x] Configured ODBC DSN for ClickHouse connection
- [x] Tested connection via SSH tunnel (localhost)
- [x] Tested direct connection (public IP)
- [ ] Create Power BI reports with Import mode
- [ ] Publish to Power BI Premium workspace
- [ ] Set up Azure Windows VM for Data Gateway
- [ ] Configure scheduled refresh (hourly)

---

## Issues Resolved

### 1. CDC Cursor Missing Error

**Problem**: Airbyte showed "Cursor missing" for all tables when using CDC mode.  
**Solution**: Changed sync mode from "Incremental | Append + Deduped" to "Full refresh | Overwrite" for initial sync.

### 2. CDC State Invalid (Binlog Purged)

**Problem**: MySQL binlog position was purged, causing CDC state corruption.  
**Solution**: Deleted MySQL source, recreated without CDC mode using "Scan Changes with User Defined Cursor".

### 3. ClickHouse Destination Unreachable

**Problem**: Airbyte couldn't connect to ClickHouse via `localhost`.  
**Solution**: Used Docker bridge IP `172.17.0.1` instead of `localhost`.

### 4. Disk Space Full (98%)

**Problem**: Only 20 GB free, not enough for 22 GB sync.  
**Solution**: Removed old `phase2_redpanda_data` volume (216 GB) and orphan volumes, recovered 217 GB.

### 5. ClickHouse HTTP Authentication

**Problem**: Native client worked but HTTP interface returned 403.  
**Solution**: URL-encode the `@` symbol as `%40` in password for HTTP requests.

### 6. Docker/Firewalld Conflict

**Problem**: Docker failed to create iptables chains after firewalld installation.  
**Solution**: Restart Docker service after firewalld installation/configuration.

### 7. Power BI Timeout Errors

**Problem**: ODBC timeout when importing large tables.  
**Solution**: Increase ODBC timeout to 3600 seconds, import smaller tables first.

### 8. Airbyte Not Accessible After Reboot

**Problem**: `localhost:8000` returned "Not Found" after server reboot.  
**Solution**: Airbyte runs inside kind cluster; just needed to reconnect SSH tunnel properly.

---

## Connection Credentials

### ClickHouse (For All Users)

```
Host: 142.93.168.177
HTTP Port: 8123
Native Port: 9000
Database: airbyte_cdc
Username: default
Password: clickhouse@2025
```

### Airbyte UI

```
URL: http://localhost:8000 (via SSH tunnel)
Password: airbyte@2025
```

### SSH Tunnel Command

```bash
ssh -L 8000:localhost:8000 -L 8123:localhost:8123 centos@142.93.168.177 -i <path_to_key>
```

---

## Code Samples

### Python (clickhouse-driver)

```python
from clickhouse_driver import Client

client = Client(
    host='142.93.168.177',
    port=9000,
    user='default',
    password='clickhouse@2025',
    database='airbyte_cdc'
)

result = client.execute('SELECT count() FROM your_table')
print(result)
```

### Python (clickhouse-connect)

```python
import clickhouse_connect

client = clickhouse_connect.get_client(
    host='142.93.168.177',
    port=8123,
    username='default',
    password='clickhouse@2025',
    database='airbyte_cdc'
)

result = client.query('SELECT count() FROM your_table')
print(result.result_rows)
```

### JDBC Connection String

```
jdbc:clickhouse://142.93.168.177:8123/airbyte_cdc?user=default&password=clickhouse@2025
```

### cURL

```bash
curl "http://142.93.168.177:8123/?user=default&password=clickhouse@2025&database=airbyte_cdc" \
  -d "SELECT count() FROM your_table"
```

---

## Power BI ODBC Configuration

| Field    | Value                   |
| -------- | ----------------------- |
| Name     | `ClickHouse_Production` |
| Host     | `142.93.168.177`        |
| Port     | `8123`                  |
| Database | `airbyte_cdc`           |
| User     | `default`               |
| Password | `clickhouse@2025`       |
| Timeout  | `3600`                  |

---

## Remaining Tasks

### Power BI Premium Setup

1. [ ] Create Azure Windows VM (~$60/month)
2. [ ] Install On-Premises Data Gateway
3. [ ] Install ClickHouse ODBC driver on gateway VM
4. [ ] Configure System DSN on gateway VM
5. [ ] Add data source in Power BI Service
6. [ ] Configure scheduled refresh (hourly)

### Monitoring & Maintenance

1. [ ] Set up refresh failure alerts
2. [ ] Document refresh schedule
3. [ ] Create monitoring dashboard for sync status

---

## Architecture Diagram

```
┌─────────────────────────┐
│  MySQL (Source)         │
│  DigitalOcean Managed   │
│  Port: 25060            │
└───────────┬─────────────┘
            │ Airbyte CDC (Hourly)
            ▼
┌─────────────────────────┐
│  ClickHouse VPS         │
│  142.93.168.177         │
│  Port: 8123/9000        │
│  Database: airbyte_cdc  │
│  73 tables, 45M+ rows   │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    │               │
    ▼               ▼
┌────────────┐  ┌────────────────┐
│ Backend    │  │ Power BI       │
│ Services   │  │ (via Gateway)  │
│ Direct     │  │ Azure VM       │
│ Connection │  │ Hourly Refresh │
└────────────┘  └────────────────┘
```

---

## Files Created

| File                                     | Purpose                       |
| ---------------------------------------- | ----------------------------- |
| `airbyte/phase0/validate_phase0.sh`      | Environment validation script |
| `airbyte/phase1/deploy_airbyte.sh`       | Airbyte deployment script     |
| `airbyte/phase2/configure_connectors.sh` | Connector validation script   |
| `airbyte/phase3/validate_sync.sh`        | Sync monitoring script        |
| `.env`                                   | Configuration variables       |
| `PROJECT_SUMMARY.md`                     | This summary document         |

---

## Cost Summary

| Component                      | Monthly Cost   |
| ------------------------------ | -------------- |
| ClickHouse VPS (existing)      | Included       |
| Airbyte OSS                    | Free           |
| Azure VM for Gateway (planned) | ~$60           |
| Power BI Premium (existing)    | Included       |
| **Total Additional**           | **~$60/month** |

---

## Contact & Support

For issues with:

- **ClickHouse**: Check container logs with `docker logs clickhouse-server`
- **Airbyte**: Access UI at `http://localhost:8000` via SSH tunnel
- **Power BI Gateway**: Check Windows Event Viewer on Azure VM

---

_Last Updated: November 30, 2025_
