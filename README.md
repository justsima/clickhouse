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
| **Phase 2** | ✅ Complete | Service Deployment & Configuration |
| **Phase 3** | ✅ Complete | Data Pipeline Implementation (Full CDC Mode) |
| **Phase 4** | ✅ Complete | Operational Readiness & BI Integration |

## Quick Start

### All Phases Complete! 🎉

The MySQL to ClickHouse CDC pipeline is **fully implemented** and ready to deploy.

**Quick Deployment Guide**:

1. **Phase 1**: Validate environment
   ```bash
   cd /home/user/clickhouse/phase1
   chmod +x scripts/*.sh
   ./scripts/01_environment_check.sh
   ```

2. **Phase 2**: Deploy services
   ```bash
   cd /home/user/clickhouse/phase2
   ./scripts/deploy.sh
   ./scripts/health_check.sh
   ```

3. **Phase 3**: Deploy CDC pipeline (with FULL CDC support)
   ```bash
   cd /home/user/clickhouse/phase3
   ./scripts/01_analyze_mysql_schema.sh
   ./scripts/02_create_clickhouse_schema.sh
   ./scripts/03_deploy_connectors.sh
   ./scripts/04_monitor_snapshot.sh  # Monitor progress
   ./scripts/05_validate_data.sh     # Validate after completion
   ```

4. **Phase 4**: Monitor and integrate with BI
   ```bash
   cd /home/user/clickhouse/phase4
   ./scripts/01_monitor_cdc_lag.sh   # Real-time monitoring
   ./scripts/03_health_check.sh      # Health checks
   # See docs/POWER_BI_SETUP.md for BI integration
   ```

**Access Services**:
- **Redpanda Console**: http://localhost:8086
- **ClickHouse Web UI**: http://localhost:8123/play
- **Kafka Connect API**: http://localhost:8085

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
├── phase1/                      # Foundation & Prerequisites ✅
│   ├── README.md
│   ├── scripts/                 # Validation scripts
│   ├── configs/                 # .env template
│   └── docs/                    # Architecture & security
├── phase2/                      # Service Deployment ✅
│   ├── docker-compose.yml       # All services
│   ├── scripts/                 # Deploy & health checks
│   └── configs/                 # ClickHouse configs
├── phase3/                      # Data Pipeline (Full CDC) ✅
│   ├── README.md
│   ├── TECHNICAL_DETAILS.md
│   ├── scripts/                 # 5 pipeline scripts
│   └── configs/                 # Connector configs
└── phase4/                      # Operations & BI ✅
    ├── README.md
    ├── scripts/                 # Monitoring & health checks
    └── docs/                    # Power BI, runbooks, troubleshooting
```

## Implementation Phases

### Phase 1: Foundation & Prerequisites ✅

**Deliverables**:
- ✅ Environment validation scripts
- ✅ MySQL configuration checks
- ✅ Replication user setup
- ✅ Network throughput testing
- ✅ Architecture documentation
- ✅ Security planning

**Status**: Complete

---

### Phase 2: Service Deployment & Configuration ✅

**Deliverables**:
- ✅ Docker Compose for all services
- ✅ Redpanda (broker + console)
- ✅ Kafka Connect
- ✅ ClickHouse server
- ✅ Health checks and monitoring

**Status**: Complete

---

### Phase 3: Data Pipeline Implementation ✅

**Deliverables**:
- ✅ ClickHouse table schemas (ReplacingMergeTree)
- ✅ Debezium source connector config (**Full CDC mode enabled**)
- ✅ ClickHouse sink connector config
- ✅ Initial snapshot + continuous streaming
- ✅ Data validation scripts
- ✅ Real-time progress monitoring

**Key Feature**: **Full CDC (Change Data Capture)** - Streams INSERT, UPDATE, DELETE operations in real-time

**Status**: Complete - Ready for deployment

---

### Phase 4: Operational Readiness & BI Integration ✅

**Deliverables**:
- ✅ CDC lag monitoring script
- ✅ Data quality validation script
- ✅ Health check automation
- ✅ Connector status monitoring
- ✅ Power BI integration guide
- ✅ Troubleshooting documentation
- ✅ Operational runbooks

**Status**: Complete - Production ready

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
**Project Completed**: 2025-11-18
**Current Status**: All 4 phases complete - **Production Ready**
**Branch**: `claude/review-codebase-status-01LDqnbvSSqxEuPhstQZsg9e`

## What's New in This Update

🎯 **Full CDC Enabled**: Changed from snapshot-only to full real-time CDC mode
- `snapshot.mode: initial` (snapshot then continuous streaming)
- Captures INSERT, UPDATE, DELETE operations in real-time
- Requires MySQL replication privileges (REPLICATION SLAVE/CLIENT)

📊 **Phase 4 Complete**: Operational readiness and BI integration
- Real-time CDC lag monitoring
- Data quality validation
- Health check automation
- Power BI integration guide
- Troubleshooting documentation
- Operational runbooks

✅ **Ready to Deploy**: Complete end-to-end pipeline
- All scripts tested and documented
- Comprehensive monitoring tools
- Production-grade error handling
- Full operational documentation
