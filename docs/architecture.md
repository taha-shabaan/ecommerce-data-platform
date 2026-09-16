# Architecture

**Project:** Ecommerce Data Platform  
**Related:** [Business requirements](business-requirements.md) · [Domain model](domain-model.md) · [Roadmap](../ROADMAP.md)

This document is the **source of truth** for technology choices, target topology, and build order. Do not introduce stack components ahead of the phased plan below.

---

## 1. Core stack

| Area | Technology | Why |
|------|------------|-----|
| Programming | **Python** | ETL, data processing, automation |
| Data manipulation | **Pandas** | Initial batch ETL and data cleaning |
| Database | **PostgreSQL** | Operational source + strong SQL practice |
| SQL | **PostgreSQL SQL** | Transformations, analytics, modeling |
| Data format | **Parquet** | Efficient columnar storage |
| Data lake | **S3** | Bronze / Silver / Gold storage |
| Data processing | **PySpark** | Distributed batch + streaming processing |
| Transformation | **dbt** | SQL-based warehouse transformations |
| Orchestration | **Apache Airflow** | Schedule and orchestrate pipelines |
| CDC | **Debezium** | PostgreSQL change data capture |
| Streaming | **Apache Kafka** | Event streaming |
| Streaming processing | **Spark Structured Streaming** | Process Kafka events |
| Warehouse | **PostgreSQL** initially → **Redshift** later | Dimensional analytics |
| Visualization | **Power BI** | Business dashboards |
| Containers | **Docker + Docker Compose** | Reproducible local environment |
| Cloud | **AWS** | S3, RDS, EC2, CloudWatch |
| Testing | **pytest** | ETL / data pipeline tests |
| Data quality | **Great Expectations** or **dbt tests** | Data validation |
| Version control | **Git + GitHub** | Portfolio + collaboration |

Local stand-ins are allowed while developing (e.g. MinIO for S3, local Kafka/Debezium via Compose) as long as interfaces match the target AWS shape.

---

## 2. Target architecture

### 2.1 Data plane

```
                  ┌──────────────────┐
                  │ Olist CSV Dataset│
                  └────────┬─────────┘
                           │
                           ▼
                    Python / Pandas
                           │
                           ▼
                    PostgreSQL
                  Operational Source
                           │
              ┌────────────┴────────────┐
              │                         │
          Batch ETL                  CDC
              │                         │
              ▼                         ▼
         S3 Bronze              PostgreSQL WAL
                                        │
                                        ▼
                                   Debezium
                                        │
                                        ▼
                                      Kafka
                                        │
                                        ▼
                              Spark Structured
                                  Streaming
              │                         │
              └────────────┬────────────┘
                           ▼
                      S3 Data Lake
                           │
                    ┌──────┴──────┐
                    │             │
                  Bronze        Silver
                                  │
                                  ▼
                                Gold
                                  │
                                  ▼
                              Warehouse
                           (Postgres → Redshift)
                                  │
                                  ▼
                                 dbt
                                  │
                                  ▼
                              Power BI
```

**Paths:**

| Path | Flow | Role |
|------|------|------|
| **Batch** | CSV → Python/Pandas → PostgreSQL → batch ETL → S3 Bronze → Silver → Gold → Warehouse → dbt → Power BI | Primary historical / daily loads |
| **CDC** | PostgreSQL WAL → Debezium → Kafka → Spark Structured Streaming → S3 lake (Silver/Gold) → Warehouse → dbt → Power BI | Near-real-time change propagation |

Both paths converge on the **S3 medallion lake** and the **warehouse**; Power BI reads curated warehouse models (dbt marts), not raw CSVs.

### 2.2 Control plane (orchestration)

Airflow sits **above** the pipeline and triggers / schedules work; it is not a data store.

```
                    Apache Airflow
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
    Python ETL         Spark              dbt
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
                     Data Platform
```

Typical DAG ownership:

- **Python ETL** — land CSVs into Postgres; batch extract to S3 Bronze (Parquet)
- **Spark** — Bronze → Silver → Gold; Structured Streaming from Kafka
- **dbt** — warehouse models, tests, documentation for Power BI

---

## 3. Medallion layers (S3)

| Layer | Contents | Writers | Consumers |
|-------|----------|---------|-----------|
| **Bronze** | Raw / near-raw landings (Parquet), append-friendly | Python batch ETL, Spark Streaming (CDC land) | Spark cleansing jobs |
| **Silver** | Cleaned, typed, deduplicated entities | PySpark | Gold jobs, some DQ |
| **Gold** | Business aggregates / conformed marts ready for warehouse | PySpark | Warehouse load |
| **Warehouse** | Dimensional models (facts/dims) | Load from Gold + **dbt** transforms | **Power BI** |

---

## 4. Build order — do not start with everything

**Important:** Introduce technologies only when the previous stage is working end-to-end.

### Phase A — Foundations

```
Python
  ↓
Pandas
  ↓
PostgreSQL
  ↓
SQL
  ↓
Data Quality (Great Expectations and/or SQL checks)
  ↓
Incremental Loading
  ↓
Parquet
  ↓
S3
```

Outcome: Olist CSVs loaded to Postgres; reliable incremental batch; Parquet landed on S3 (Bronze).

### Phase B — Lake & warehouse

```
PySpark
  ↓
Data Lake / Medallion (Bronze → Silver → Gold)
  ↓
Data Warehouse (PostgreSQL first)
```

Outcome: Distributed transforms; dimensional warehouse for analytics.

### Phase C — Transformation & orchestration

```
dbt
  ↓
Airflow
```

Outcome: Tested SQL marts; scheduled DAGs for Python ETL, Spark, and dbt.

### Phase D — CDC & streaming

```
PostgreSQL
  ↓
Debezium
  ↓
Kafka
  ↓
Spark Structured Streaming
```

Outcome: Change events from Postgres flow into the lake alongside batch.

### Phase E — Cloud

```
AWS (S3, RDS, EC2, CloudWatch)
  ↓
Deployment + Monitoring
```

Outcome: Production-shaped deploy; dashboards and alerts on CloudWatch; Power BI against the warehouse.

---

## 5. Component contracts (short)

| Component | Contract |
|-----------|----------|
| **Olist CSVs** | Immutable inputs under `data/`; entity names (`customers`, `products`, `orders`, `order_items`, `payments`, …) |
| **PostgreSQL (ops)** | System of record for batch practice and CDC source (WAL) |
| **S3** | Single lake root with `bronze/`, `silver/`, `gold/` prefixes; Parquet preferred |
| **Warehouse** | Start on PostgreSQL schemas/marts; migrate analytical workload to **Redshift** when scale/cost justifies |
| **dbt** | Only models warehouse relations Power BI (and other consumers) may depend on |
| **Airflow** | Owns schedule, retries, lineage of task runs — not business logic inside operators beyond thin wrappers |
| **Power BI** | Connects to warehouse (dbt marts), shows data-as-of / refresh metadata |

---

## 6. Out of scope for early phases

- Standing up Kafka / Debezium / Spark Streaming before Phase A–B are solid
- Redshift before a working PostgreSQL warehouse + dbt models
- Airflow before there are at least two reliable jobs worth scheduling
- Power BI production workspace before Gold / warehouse contracts exist

---

## 7. Alignment checklist

- [x] Core stack table locked (Python, Pandas, Postgres, Parquet, S3, PySpark, dbt, Airflow, Debezium, Kafka, Spark Structured Streaming, Power BI, Docker, AWS, pytest, GE/dbt tests, GitHub)
- [x] Target data-plane diagram (batch + CDC → lake → warehouse → dbt → Power BI)
- [x] Airflow control-plane diagram
- [x] Phased build order documented (A → E)
