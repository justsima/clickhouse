# MySQL → ClickHouse CDC Implementation Plan

## 1. Objectives

- Migrate historical MySQL data (multi‑TB scale) into ClickHouse with zero downtime.
- Keep ClickHouse in near real time using Change Data Capture (CDC) from MySQL binlogs.
- Run Airbyte OSS on an existing VPS (Docker deployment) as the replication orchestrator.
- Respect the security constraint that MySQL only accepts traffic from explicitly allow‑listed IPs (the VPS), while ClickHouse currently has no IP filtering.
- Provide an auditable, supportable workflow that covers provisioning, deployment, monitoring, recovery, and future scale‑out.

## 2. Target Architecture

```
DigitalOcean Managed MySQL ──TLS/SSH──> VPS / Airbyte OSS ──HTTPS──> ClickHouse Cluster (Kubernetes)
```

- **MySQL**: Managed instance with binlog + GTIDs enabled, accessible only from allow‑listed IPs.
- **VPS**: Hosts Docker + `abctl` Airbyte install. Airbyte stores metadata locally (or optional external Postgres) and performs MySQL snapshot + CDC ingestion, then writes to ClickHouse via native HTTP API.
- **ClickHouse on Kubernetes**: Exposed through an ingress / load balancer with TLS; Airbyte authenticates using a dedicated service account.

## 3. Reference Documentation

| Topic                       | Key Docs                                                                                                 |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| Airbyte OSS deployment      | [Airbyte OSS Quickstart](https://docs.airbyte.com/platform/using-airbyte/getting-started/oss-quickstart) |
| MySQL source (CDC)          | [Airbyte MySQL Source Guide](https://docs.airbyte.com/integrations/sources/mysql)                        |
| ClickHouse destination      | [Airbyte ClickHouse Destination Guide](https://docs.airbyte.com/integrations/destinations/clickhouse)    |
| Binlog / privileges         | MySQL manual, Debezium best practices (binlog_format=ROW, binlog_row_image=FULL)                         |
| Airbyte API & orchestration | [Airbyte API reference](https://reference.airbyte.com/)                                                  |

## 4. Assumptions & Inputs

- VPS: Ubuntu 22.04 LTS, ≥4 vCPU, ≥16 GB RAM, ≥200 GB SSD, outbound internet access.
- Docker Engine 24+ installed; `abctl` available.
- SSH access to VPS for deployment; firewall rules manageable.
- DigitalOcean MySQL user with admin rights for configuration changes.
- ClickHouse Kubernetes cluster exposes HTTPS endpoint (e.g., `https://ch-lb.example.com:8443`).
- Estimated dataset for initial backfill: 22 GB sample, scaling to multiple TB later.

## 5. High-Level Phases & Timeline

| Phase                        | Tasks                                                              | Est. Duration    |
| ---------------------------- | ------------------------------------------------------------------ | ---------------- |
| A. Preparation               | Confirm networking, credentials, binlog retention, ClickHouse user | 0.5 day          |
| B. Airbyte deployment        | Install Docker deps, deploy Airbyte via `abctl`, secure access     | 0.5 day          |
| C. Source/Destination config | Create Airbyte source+destination, connection, run dry run         | 0.5 day          |
| D. Initial snapshot          | Execute 22 GB pilot sync, validate row counts                      | < 1 hour runtime |
| E. CDC cutover               | Enable scheduled CDC sync, monitoring, alerting                    | 0.5 day          |
| F. Hardening & docs          | Playbooks, backup/restore, scaling plan                            | 0.5 day          |

## 6. Detailed Implementation Steps

### 6.1 Network & Security Configuration

1. **Whitelist VPS IP on MySQL**
   - Use DigitalOcean firewall to allow TCP 3306 (or DO managed port) from VPS static IP only.
   - If DO requires SSL, download CA cert for client validation.
2. **ClickHouse exposure**
   - Ensure Kubernetes ingress terminates TLS with a valid cert.
   - Restrict credentials (username/password or mTLS). Because no IP filter exists, enforce strong auth and optionally Basic Auth + TLS client certs.
3. **VPS hardening**
   - Enable UFW to allow only SSH (22) and Airbyte UI port (default 8000) from trusted administrative ranges.
   - Install fail2ban to protect SSH.

### 6.2 MySQL Preparation

1. **Enable binlog + GTID (if not already)**
   - Set in MySQL configuration:
     ```
     server_id=9001
     log_bin=mysql-bin
     binlog_format=ROW
     binlog_row_image=FULL
     gtid_mode=ON
     enforce_gtid_consistency=ON
     binlog_expire_logs_seconds=604800  # >= 7 days
     ```
   - Restart MySQL if required; confirm via `SHOW VARIABLES LIKE 'log_bin';`.
2. **Create replication user**
   ```sql
   CREATE USER 'airbyte'@'<vps-ip>' IDENTIFIED BY '<strong-password>' REQUIRE SSL;
   GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'airbyte'@'<vps-ip>';
   FLUSH PRIVILEGES;
   ```
3. **Baseline health checks**
   - Capture table counts, size statistics (`information_schema.TABLES`) for later validation.
   - Document critical schemas and tables, expected primary keys, and any large LOB columns.

### 6.3 ClickHouse Preparation

1. **Create Airbyte role**
   ```sql
   CREATE USER airbyte IDENTIFIED BY '<clickhouse-password>';
   GRANT CREATE, ALTER, DROP TABLE, TRUNCATE, INSERT, SELECT ON <target_db>.* TO airbyte;
   ```
2. **Connectivity test**
   - From VPS: `curl -u airbyte:<pwd> https://ch-lb.example.com:8443/ping` should return `Ok.`
3. **Target schema strategy**
   - Decide per-table naming convention (e.g., `mysql_<schema>_<table>`).
   - For dedup’d CDC streams, use `ReplacingMergeTree` with `sign`/`version` columns created by Airbyte’s Append+Dedup mode.

### 6.4 VPS / Airbyte Deployment

1. **Install dependencies**
   ```bash
   sudo apt update && sudo apt install -y docker.io docker-compose-plugin curl jq
   sudo usermod -aG docker $USER
   curl -LsfS https://get.airbyte.com | bash
   ```
2. **Deploy Airbyte**
   ```bash
   abctl local install
   abctl local credentials  # note default admin user/password
   ```
3. **Secure Airbyte UI**
   - Change default password: `abctl local credentials --password '<strong-pass>'`.
   - Optionally place behind Caddy/Nginx reverse proxy with HTTPS.
4. **Persistent storage (optional)**
   - Airbyte stores configs in `~/.airbyte`. Snapshot regularly or configure external Postgres + S3 if high availability is required.

### 6.5 Configure Airbyte Source (MySQL)

1. **Add Source**
   - Host: DO endpoint.
   - Port: managed port (default 25060 for DO?).
   - Database: primary schema.
   - SSL Mode: `verify-ca` or `require` (upload DO CA cert).
   - Replication Method: `Read changes using Binary Log (CDC)`.
   - Advanced tuning:
     - `checkpoint_target_interval_seconds`: 60 (ensures state save every minute).
     - `max_db_connections`: 4 (match MySQL limits).
     - `concurrency`: 4 (parallel snapshot threads for large tables).
     - Table filters: include/exclude as needed.
2. **(Optional) SSH Tunnel**
   - If DO enforces private networking, configure Airbyte connector with SSH bastion parameters instead of direct TLS.
3. **Connection test**
   - Validate Airbyte can list schemas; fix firewall or TLS issues if not.

### 6.6 Configure Airbyte Destination (ClickHouse)

1. **Add Destination**
   - Host: `ch-lb.example.com` (without protocol).
   - Port: `8443` (HTTPS) or `8123` (HTTP) as available.
   - Protocol: `HTTPS` (for self-hosted deployments specify explicitly).
   - Database: `airbyte_raw` (or chosen DB). Airbyte creates DB if permitted.
   - Username/password: dedicated ClickHouse user.
   - Enable JSON: true if ClickHouse version supports native JSON type; otherwise leave false to store JSON as String.
   - Record window size: default 15 minutes unless huge bursts expected.
2. **Test destination**
   - Airbyte attempts to create test tables; verify success.

### 6.7 Build Connections & Workflows

1. **Define connection**
   - Source tables: start with pilot schema (22 GB dataset) before adding more.
   - Sync mode: `Full Refresh | Append` for initial snapshot, then switch to `Incremental | Append + Deduped` once CDC catches up.
   - Destination namespace: `mirror` mode to reflect MySQL schema names or prefix them.
   - Schedule: Manual trigger for first load → change to every 5 minutes for CDC.
2. **Initial snapshot**
   - Kick off job; monitor Airbyte UI logs.
   - Track throughput: expect 30–60 MB/s (22 GB completes in ~6–12 minutes).
3. **CDC verification**
   - After snapshot completes and CDC starts, issue writes/deletes in MySQL test table; verify they land in ClickHouse within lag budget (<1 minute).

### 6.8 Validation & Quality Gates

1. **Row counts & checksums**
   - Use ClickHouse queries: `SELECT count() FROM mysql_schema_table` vs. MySQL `COUNT(*)`.
   - For large tables, compare sample checksums (`MD5(CONCAT(pk, col))`).
2. **Schema evolution tests**
   - Add column in MySQL; ensure Airbyte CDC handles DDL (MySQL connector captures DDL metadata, ClickHouse destination will adjust schema automatically if configured).
3. **Backfill reruns**
   - Document how to re-run snapshot (Airbyte incremental snapshot signal) if data corruption occurs.

### 6.9 Monitoring & Alerting

1. **Airbyte job monitoring**
   - Enable notifications (Slack/webhook) on failure.
   - Use Airbyte API `/jobs/get` to scrape status for Prometheus/Grafana.
2. **Infrastructure metrics**
   - VPS: CPU/RAM/disk (node exporter).
   - MySQL: replication lag, binlog disk usage.
   - ClickHouse: `system.merges`, `system.parts` to ensure inserts keep up.
3. **Logs retention**
   - Configure logrotate for Docker logs to prevent disk exhaustion.

### 6.10 Operations & Maintenance

- **State backups**: Tarball `~/.airbyte` nightly or configure external metadata DB.
- **Upgrades**: Follow Airbyte release notes. Use `abctl local upgrade` for minor updates.
- **Disaster recovery**: Document how to redeploy Airbyte on new VPS using stored `.env`/config and resume from last CDC offset.
- **Security reviews**: Quarterly review of MySQL allow‑list, ClickHouse users/password rotation, Airbyte admin credentials.
- **Scaling**: For multi‑TB ingest, consider moving Airbyte to Kubernetes or Airbyte Cloud, and store staging files in S3 (if using Large Sync Mode once available).

## 7. Risks & Mitigations

| Risk                                    | Impact                   | Mitigation                                                                                                            |
| --------------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Binlog purged before Airbyte catches up | Requires full resnapshot | Keep `binlog_expire_logs_seconds` ≥ 7 days; monitor lag                                                               |
| VPS resource exhaustion                 | Job failures             | Size VM with headroom, monitor, consider dedicated disks                                                              |
| ClickHouse exposed publicly             | Security breach          | Enforce TLS, strong auth, consider IP allow‑listing or mTLS even if currently open                                    |
| Schema drift (DDL) handled poorly       | Data inconsistency       | Test DDL scenarios, enable incremental snapshots after DDL, document change process                                   |
| Large tables causing long locks         | Snapshot delays          | Use Airbyte incremental snapshot chunking (default 10k rows) and set `snapshot_target_size` to minimize lock duration |

## 8. Acceptance Checklist

- [ ] VPS hardened, Docker + Airbyte running, access restricted.
- [ ] MySQL binlog + GTID verified; Airbyte user whitelisted.
- [ ] ClickHouse user created; connectivity from VPS confirmed.
- [ ] Airbyte source & destination configured, tested.
- [ ] Initial 22 GB snapshot completed; row counts validated.
- [ ] CDC events verified for inserts/updates/deletes.
- [ ] Monitoring/alerting pipeline active.
- [ ] Runbook documented for reruns, upgrades, failure recovery.

## 9. Future Enhancements

- Automate sync orchestration via Airflow / Dagster using Airbyte operators.
- Store Airbyte state in external Postgres + S3 to simplify redeployments.
- Add data quality checks (Great Expectations / dbt tests) against ClickHouse tables.
- Consider ClickPipes (managed CDC) if moving fully to ClickHouse Cloud later.

---

_Last updated: 2025-11-24_
