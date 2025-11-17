# MySQL to ClickHouse Real-Time CDC Pipeline

Real-time data replication from MySQL (DigitalOcean) to ClickHouse for analytical workloads using Debezium CDC and Redpanda.

## Architecture

```
MySQL (DO) → Debezium → Redpanda (Kafka) → ClickHouse Sink → ClickHouse → Power BI
```

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1** | ✅ Complete | Foundation & Prerequisites |
| **Phase 2** | ✅ Ready | Service Deployment & Configuration |
| **Phase 3** | 🔜 Pending | Data Pipeline Implementation |
| **Phase 4** | 🔜 Pending | Operational Readiness & BI Integration |

## Quick Start

### Current Phase: Phase 2 - Service Deployment

**Objective**: Deploy Redpanda, Kafka Connect, ClickHouse, and Redpanda Console

**Duration**: 15-20 minutes

**Steps**:
1. Navigate to Phase 2:
   ```bash
   cd /home/centos/clickhouse/phase2
   ```

2. Deploy all services:
   ```bash
   chmod +x scripts/*.sh
   ./scripts/deploy.sh
   ```

3. Verify services are healthy:
   ```bash
   ./scripts/health_check.sh
   ```

4. Access services:
   - **Redpanda Console**: http://localhost:8086
   - **ClickHouse Web UI**: http://localhost:8123/play
   - **Kafka Connect API**: http://localhost:8085

**Full Instructions**: See [phase2/README.md](phase2/README.md)

4. Check validation reports:
   ```bash
   ls -lh phase1/*.txt
   ```

**Full Instructions**: See [phase1/README.md](phase1/README.md)

## Technology Stack

- **Source**: MySQL 8.0 (DigitalOcean Managed Database)
- **CDC**: Debezium MySQL Connector
- **Message Broker**: Redpanda (Kafka-compatible)
- **Sink**: ClickHouse with ReplacingMergeTree
- **BI**: Power BI with DirectQuery
- **Deployment**: Docker Compose on CentOS VPS

## Key Features

- ✅ **Zero MySQL Impact**: CDC reads binlog only, no OLTP load
- ✅ **Real-Time**: Sub-second data freshness
- ✅ **Scalable**: Handle 100M+ rows
- ✅ **Reliable**: Automatic recovery from failures
- ✅ **Cost-Effective**: Single VPS deployment
- ✅ **Observable**: Web UIs for all components

## Prerequisites

- VPS: 32GB+ RAM, 500GB+ disk, Docker installed
- MySQL 8.0 with binlog_format=ROW
- Network: VPS → MySQL connectivity
- Credentials: Admin access to MySQL

## Documentation

- [Phase 1: Foundation & Prerequisites](phase1/README.md)
- [Architecture Overview](phase1/docs/ARCHITECTURE.md)
- [Port Mapping & Security](phase1/docs/PORTS_AND_SECURITY.md)

## Environment

- **VPS**: CentOS, 64GB RAM, 1TB SSD
- **MySQL**: DigitalOcean Managed Database, ~100M rows
- **Network**: VPS connects to MySQL via internet (port 25060)

## Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| Redpanda Kafka | 9092 | Data streaming |
| Redpanda Console | 8080 | Web UI |
| Kafka Connect | 8083 | Connector management |
| ClickHouse HTTP | 8123 | Web UI, REST API |
| ClickHouse Native | 9000 | High-performance queries |

## Project Structure

```
clickhouse/
├── README.md                    # This file
├── .gitignore                   # Exclude .env and reports
├── phase1/                      # Foundation & Prerequisites
│   ├── README.md
│   ├── scripts/                 # Validation scripts
│   ├── configs/                 # .env template
│   └── docs/                    # Architecture & security
├── phase2/                      # Service Deployment (coming)
├── phase3/                      # Data Pipeline (coming)
└── phase4/                      # Operations & BI (coming)
```

## Implementation Phases

### Phase 1: Foundation & Prerequisites ✅

**Deliverables**:
- Environment validation scripts
- MySQL configuration checks
- Replication user setup
- Network throughput testing
- Architecture documentation
- Security planning

**Status**: Complete - Ready to run validation

---

### Phase 2: Service Deployment & Configuration 🔜

**Deliverables**:
- Docker Compose for all services
- Redpanda (broker + console)
- Kafka Connect
- ClickHouse server
- Health checks and monitoring

**Status**: Not started

---

### Phase 3: Data Pipeline Implementation 🔜

**Deliverables**:
- ClickHouse table schemas (ReplacingMergeTree)
- Debezium source connector config
- ClickHouse sink connector config
- Initial data load
- CDC validation

**Status**: Not started

---

### Phase 4: Operational Readiness & BI Integration 🔜

**Deliverables**:
- Monitoring dashboards
- Alerting rules
- Power BI connection guide
- Operational runbooks
- Acceptance tests

**Status**: Not started

---

## Getting Help

1. **Phase-specific issues**: Check README in each phase directory
2. **Generated reports**: Review `*_report.txt` files for diagnostics
3. **Documentation**: See `docs/` folders for detailed guides
4. **Logs**: Check Docker logs for service issues

## Security Notes

- 🔒 All credentials stored in `.env` (gitignored)
- 🔒 Firewall restricts access to your IP only
- 🔒 Replication user has minimal privileges
- 🔒 Web UIs protected with basic auth
- 🔒 Regular security audits recommended

## Contributing

This is a production deployment project. All changes should be:
1. Tested on VPS before committing
2. Documented in phase README files
3. Committed with clear messages
4. Pushed to branch: `claude/mysql-to-clickhouse-migration-*`

## License

Internal use only - not for public distribution

---

**Project Started**: 2025-11-14
**Current Phase**: Phase 1 (Validation)
**Target Completion**: 4 phases over 2-3 weeks
**Branch**: `claude/mysql-to-clickhouse-migration-01CUjxKPiV5QGUrW9bSaszHe`
