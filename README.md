# Ecommerce Data Platform

Analytics data platform for an ecommerce marketplace (Olist sample data).  
**Build order matters:** foundations first (Python / Pandas / PostgreSQL), then lakehouse, dbt + Airflow, CDC streaming, then AWS — see [docs/architecture.md](docs/architecture.md).

## Docs

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Core stack, target diagrams, phased build order |
| [Business requirements](docs/business-requirements.md) | Purpose, stakeholders, metrics, SLAs |
| [Domain model](docs/domain-model.md) | Entities: customers, products, orders, order_items, payments (+ supporting) |

## Data

Entity-named CSVs under `data/`:

- `customers.csv`, `products.csv`, `orders.csv`, `order_items.csv`, `payments.csv`
- Supporting: `sellers.csv`, `reviews.csv`, `geolocation.csv`, `product_category.csv`

Raw data files are gitignored; keep local copies in `data/`.

## Core stack (summary)

| Area | Technology |
|------|------------|
| ETL / processing | Python, Pandas, PySpark, Spark Structured Streaming |
| Storage | PostgreSQL, Parquet, S3 (Bronze/Silver/Gold) |
| Transform / orchestrate | dbt, Apache Airflow |
| CDC / streaming | Debezium, Apache Kafka |
| Warehouse / BI | PostgreSQL → Redshift, Power BI |
| Platform | Docker Compose, AWS (S3, RDS, EC2, CloudWatch), pytest, Great Expectations / dbt tests, GitHub |

## Target flow (short)

```
Olist CSV → Python/Pandas → PostgreSQL
                │                │
           Batch ETL            CDC → Debezium → Kafka → Spark Streaming
                └────────┬───────┘
                         ▼
              S3 Bronze → Silver → Gold → Warehouse → dbt → Power BI

              Apache Airflow orchestrates Python ETL, Spark, and dbt
```

## Quick start

```bash
# Phase A (foundations) — coming next on the roadmap:
# docker compose up -d
# python -m venv .venv && source .venv/bin/activate
# pip install -r requirements.txt
```

See [docs/architecture.md](docs/architecture.md) for the full sequence.
