# Ecommerce Data Platform — Learning Roadmap

Phased build matching [`docs/architecture.md`](docs/architecture.md). **Do not start with the full stack.**

```
Phase A  Python → Pandas → PostgreSQL → SQL → DQ → Incremental → Parquet → S3
        ↓
Phase B  PySpark → Medallion lake → Warehouse (Postgres; Redshift later)
        ↓
Phase C  dbt → Airflow
        ↓
Phase D  Postgres → Debezium → Kafka → Spark Structured Streaming
        ↓
Phase E  AWS (S3, RDS, EC2, CloudWatch) → Deploy + monitor → Power BI
```

**Business requirements:** [`docs/business-requirements.md`](docs/business-requirements.md)  
**Architecture (stack + diagrams):** [`docs/architecture.md`](docs/architecture.md)

---

## Phase A — Foundations (Batch + incremental + S3)

### Dataset
- [ ] Choose or generate sample ecommerce dataset
- [ ] Document schema + primary/foreign keys
- [x] Place raw files under `data/` with entity names (`customers`, `products`, `orders`, `order_items`, `payments`)
- [ ] Add a small seed sample for local smoke tests
- [ ] Write a short data dictionary (column meanings, nullability)

### PostgreSQL
- [ ] Run Postgres via Docker Compose
- [ ] Create source DB schemas/tables matching the dataset
- [ ] Load initial CSV/JSON into Postgres
- [ ] Add indexes for join/filter columns
- [ ] Verify row counts and referential integrity

### Python + Pandas
- [ ] Set up virtualenv + `requirements.txt` (pandas, psycopg, pytest, …)
- [ ] Create project layout (`src/`, `tests/`, `sql/`, `config/`)
- [ ] Implement DB connection helper (env-based config)
- [ ] Add logging and basic error handling
- [ ] Write a CLI entrypoint to run the batch job
- [ ] Use **Pandas** for initial extract/clean/transform

### Batch ETL + SQL
- [ ] Extract full tables from Postgres
- [ ] Transform (types, nulls, dedupe, derived columns) in Pandas and/or SQL
- [ ] Load into staging tables
- [ ] Promote staging → target tables with PostgreSQL SQL
- [ ] Run end-to-end once and record metrics (rows in/out, runtime)

### Data quality
- [ ] Null checks on required fields
- [ ] Referential integrity checks (orphans)
- [ ] Range/domain checks (amounts ≥ 0, valid statuses)
- [ ] Freshness check vs watermark
- [ ] Fail or quarantine bad rows; log DQ report
- [ ] Add **Great Expectations** suites and/or SQL assertions for core entities

### Incremental loading
- [ ] Identify high-change tables vs slowly changing ones
- [ ] Replace full reload with date/ID-based incremental extract
- [ ] Parameterize lookback window
- [ ] Compare full vs incremental row counts
- [ ] Document when to fall back to full refresh

### Watermarks
- [ ] Design watermark store (table or file)
- [ ] Persist last successful extract timestamp/ID per table
- [ ] Advance watermark only after successful load
- [ ] Handle late-arriving data (overlap window)
- [ ] Add reset/backfill procedure

### Upserts
- [ ] Define natural/business keys per entity
- [ ] Implement `INSERT ... ON CONFLICT` (or MERGE) for updates
- [ ] Soft-delete or tombstone strategy for removals
- [ ] Validate update vs insert ratios after each run
- [ ] Cover SCD Type 1 (and optionally Type 2) for dimensions

### Idempotency
- [ ] Ensure re-running the same batch does not duplicate rows
- [ ] Use deterministic job run IDs / batch IDs
- [ ] Make staging truncate-or-replace safe
- [ ] Add “exactly-once load” checks (unique constraints)
- [ ] Simulate crash mid-job and verify recovery

### Parquet + S3
- [ ] Write batch extracts as **Parquet**
- [ ] Create S3 (or MinIO) bucket + `bronze/` prefix
- [ ] Land Parquet into S3 Bronze from Python/Pandas ETL
- [ ] Document path conventions and partitioning keys

---

## Phase B — Lakehouse + warehouse

### S3 medallion
- [ ] Extend prefixes: `bronze/`, `silver/`, `gold/`
- [ ] Configure local MinIO or AWS credentials for dev
- [ ] Enable versioning / lifecycle rules (dev-appropriate)
- [ ] Bronze: raw immutable ingest (schema-on-read, Parquet)
- [ ] Silver: cleaned, typed, deduplicated entities
- [ ] Gold: business aggregates and marts
- [ ] Enforce layer contracts (what may/may not change)

### PySpark
- [ ] Add Spark local/Docker setup
- [ ] Read bronze → write silver jobs
- [ ] Partition by date / entity where useful
- [ ] Use Spark SQL for joins and aggregations
- [ ] Compare Spark job vs Python/Pandas batch for same transform

### Dimensional modeling
- [ ] Design star schema (fact_orders, dim_customer, dim_product, dim_date, …)
- [ ] Define grain for each fact table
- [ ] Map source columns → dims/facts
- [ ] Handle late-changing dimensions policy
- [ ] Draw ERD and keep it in `docs/`

### Data warehouse
- [ ] Stand up warehouse on **PostgreSQL** (analytics schema)
- [ ] Load gold/star tables
- [ ] Create analytic views for common questions
- [ ] Benchmark a few BI queries
- [ ] Document refresh cadence per mart
- [ ] Plan later move to **Amazon Redshift** (do not start Redshift in Phase B)

---

## Phase C — dbt + Airflow

### dbt
- [ ] Init dbt project and connect to warehouse
- [ ] Model staging (`stg_`) and mart (`fct_`, `dim_`) layers
- [ ] Add sources + freshness configs
- [ ] Write schema.yml tests (unique, not_null, relationships) — warehouse DQ
- [ ] Generate docs and lineage graph

### Airflow
- [ ] Run Airflow locally (Docker Compose)
- [ ] Create DAGs that orchestrate **Python ETL**, **Spark**, and **dbt**
- [ ] Wire sensors/operators for Postgres, S3, Spark/dbt
- [ ] Add retries, timeouts, and alerting hooks
- [ ] Parameterize env (dev vs prod connections)

### Testing
- [ ] Unit tests with **pytest** for Python transform helpers
- [ ] dbt data tests in CI or local pre-merge
- [ ] Integration test: seed → pipeline → assert row counts
- [ ] Contract tests between bronze and silver schemas
- [ ] Snapshot or golden-file checks for critical marts

### Production orchestration
- [ ] Schedule DAGs (cron / timetable)
- [ ] Separate environments (dev/stage/prod configs)
- [ ] Secrets via env / secret manager (no secrets in git)
- [ ] Runbook: backfill, pause, replay failed tasks
- [ ] Observability: task duration, failure rate, data freshness

---

## Phase D — CDC + Kafka + Spark Streaming

### Kafka
- [ ] Run Kafka (+ ZooKeeper/KRaft) via Docker Compose
- [ ] Create topics per domain (`orders`, `customers`, …)
- [ ] Produce/consume a sample message end-to-end
- [ ] Set retention and partition strategy
- [ ] Document topic naming and schemas (Avro/JSON Schema optional)

### Debezium
- [ ] Enable Postgres logical replication / WAL
- [ ] Deploy Debezium connector for source tables
- [ ] Verify change events in Kafka topics
- [ ] Tune snapshot vs streaming mode
- [ ] Handle schema changes (DDL) safely

### CDC
- [ ] Model op types: insert / update / delete
- [ ] Land CDC into bronze (append-only change log)
- [ ] Build silver from CDC (current-state + history)
- [ ] Compare CDC path vs batch incremental for same tables
- [ ] Document lag SLOs and monitoring

### Spark Structured Streaming
- [ ] Structured Streaming job from Kafka
- [ ] Watermarking + late data handling
- [ ] Windowed aggregations (e.g. orders/minute)
- [ ] Checkpointing to durable storage (S3)
- [ ] Failover test (kill job, restart from checkpoint)
- [ ] Exactly-once / at-least-once semantics notes
- [ ] Dead-letter path for bad events
- [ ] End-to-end latency measurement (source commit → silver)

---

## Phase E — AWS + Power BI

### Real-time analytics
- [ ] Define KPIs suitable for near-real-time (orders, GMV)
- [ ] Materialize streaming aggregates toward Gold / warehouse
- [ ] Validate against batch gold for the same window
- [ ] Set alert thresholds on anomaly / lag
- [ ] Document freshness guarantees to consumers

### Power BI
- [ ] Connect Power BI to warehouse **dbt marts** (not raw CSVs)
- [ ] Build core views: revenue, top products, order funnel, payments, fulfillment
- [ ] Add last-refreshed / data-as-of indicator
- [ ] Share read-only access for demo

### AWS deployment + monitoring
- [ ] Map local stack → **S3, RDS (Postgres), EC2, CloudWatch**
- [ ] IaC sketch (Terraform/CDK) or documented manual deploy
- [ ] Deploy one batch path and one streaming path
- [ ] Configure IAM least privilege + secrets
- [ ] CloudWatch metrics/alarms for jobs, lag, and failures
- [ ] Cost estimate + teardown checklist
- [ ] Optional: cut warehouse analytics over to **Redshift** when justified

---

## Progress tracker

| Phase | Focus | Status |
|-------|--------|--------|
| — | Business requirements + architecture docs | Done |
| A | Python → Pandas → Postgres → SQL → DQ → Incremental → Parquet → S3 | Not started |
| B | PySpark → Medallion → Warehouse (Postgres) | Not started |
| C | dbt → Airflow | Not started |
| D | Debezium → Kafka → Spark Structured Streaming | Not started |
| E | AWS (S3, RDS, EC2, CloudWatch) + Power BI | Not started |

Update status to `In progress` / `Done` as you go. Check off items in each section as you complete them.
