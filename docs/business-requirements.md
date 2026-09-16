# Business Requirements

**Project:** Ecommerce Data Platform  
**Domain source:** Olist Brazilian marketplace dataset (`data/`)  
**Related:** [Architecture](architecture.md) · [Domain model](domain-model.md)
---

## 1. Purpose

Build a reliable analytics data platform for an ecommerce marketplace so business and data teams can answer revenue, customer, product, payment, and fulfillment questions from a **single trusted source of truth**, using the Olist Brazilian marketplace dataset under `data/` (`customers`, `products`, `orders`, `order_items`, `payments`, plus sellers, reviews, geolocation, and product category).

### What the platform must deliver (v1 reporting)

1. **Revenue** — daily and weekly GMV from `order_items.price` (and freight when included in the agreed revenue definition), filtered to delivered/approved `order_status` values once those statuses are locked in open decisions; support MoM growth and finance-grade totals.
2. **Assortment / demand (inventory proxy)** — product and category sell-through and price-band performance. The source data has no stock snapshot, so this is demand analytics, not a WMS inventory system.
3. **Retention** — new vs returning buyers and repeat-purchase rates by `customer_unique_id` over 30- and 90-day windows, including geo demand where zip/city/state enrichment is available.
4. **Fulfillment** — order status funnel, share of orders delivered on or before `order_estimated_delivery_date`, and seller ship-limit pressure via `shipping_limit_date` on order lines.
5. **Payments** — mix by `payment_type` (credit card, boleto, voucher, debit card, etc.) and installment bands, reconciled against order and line totals within a documented tolerance.

### Who it serves

| Stakeholder | Needs | Priority questions |
|-------------|-------|--------------------|
| **Executive / Finance** | Trusted revenue & margin views | GMV, net revenue, freight, payment mix, MoM growth |
| **Growth / Marketing** | Customer behavior | New vs returning (`customer_unique_id`), retention, geo demand |
| **Category / Merchandising** | Product performance | Top categories, attach rate, price bands |
| **Marketplace Ops** | Fulfillment health | Status funnel, delivery SLA vs estimate, seller ship-limit breaches |
| **Data Engineering** | Pipeline reliability | Freshness, completeness, DQ failures, job runtime |
| **Customer Experience** | Quality signals | Review scores by category / seller / delay |

### How the platform evolves (capability path)

Build **only in this order** — full stack and diagrams: [architecture.md](architecture.md).

1. **Phase A — Foundations** — Python → Pandas → PostgreSQL → SQL → data quality (Great Expectations / SQL) → incremental loading → Parquet → S3. Olist CSVs become an operational Postgres source; batch lands Bronze on S3.
2. **Phase B — Lake & warehouse** — PySpark → medallion lake (Bronze → Silver → Gold) → warehouse (**PostgreSQL** first; **Redshift** later).
3. **Phase C — Transformation & orchestration** — dbt models/tests on the warehouse → Apache Airflow schedules Python ETL, Spark, and dbt.
4. **Phase D — CDC & streaming** — PostgreSQL WAL → Debezium → Kafka → Spark Structured Streaming into the lake (alongside batch).
5. **Phase E — Cloud** — AWS (S3, RDS, EC2, CloudWatch) deployment + monitoring; **Power BI** on warehouse marts.

**v1 path in one line:** Olist CSV → Python/Pandas → PostgreSQL → DQ → incremental batch → Parquet on S3 Bronze.

**Final consumer path:** S3 Gold → Warehouse → dbt → Power BI (batch and CDC paths converge on the lake).

---

## 2. Domain entities

Canonical business entities (full schemas and keys in [domain-model.md](domain-model.md)):

| Entity | Business meaning | Primary grain |
|--------|------------------|---------------|
| **customers** | Buyers on the marketplace | One row per `customer_id` (person = `customer_unique_id`) |
| **products** | Catalog items | One row per `product_id` |
| **orders** | Purchase / checkout header | One row per `order_id` |
| **order_items** | Sold lines (product + seller + price) | One row per (`order_id`, `order_item_id`) |
| **payments** | Settlement of an order | One row per (`order_id`, `payment_sequential`) |

Supporting entities used for enrichment and ops reporting: **sellers**, **reviews**, **geolocation**, **product_category**.

```
customers ──< orders ──< order_items >── products
                │              └──> sellers
                ├──< payments
                └──< reviews
```

---

## 3. Success metrics

### 3.1 Data freshness

| Layer | Target (batch phase) | Measurement |
|-------|----------------------|-------------|
| Source land (`data/`) | Manual / on-demand | File modified time documented per run |
| Staging in Postgres | ≤ 1 hour after job start | `MAX(loaded_at)` vs job start |
| Analytics tables | Same batch as staging promote | Watermark / `etl_updated_at` on target |

**Pass rule:** After a successful run, analytics tables reflect all source rows with `order_purchase_timestamp` (or agreed business date) ≤ watermark.

### 3.2 Completeness

| Check | Target | Notes |
|-------|--------|-------|
| Row count parity source → staging | 100% of extractable rows | Allow explicit quarantine set |
| Orders with ≥ 1 payment | ≥ 99% | Investigate gaps |
| Order items with valid `product_id` | 100% referential | Orphan lines fail DQ |
| Required fields non-null | 100% on PK/FK and business-critical attrs | e.g. `order_id`, `price` |

### 3.3 Accuracy

| Check | Target | Notes |
|-------|--------|-------|
| Payment total vs items | Documented tolerance | Compare `SUM(payment_value)` to `SUM(price + freight_value)` per order; explain known Olist mismatches |
| Duplicate PKs | 0 | Enforce unique constraints |
| Status / timestamp consistency | No delivered without delivery timestamp (except documented exceptions) | Soft fail → quarantine |

---

## 4. SLAs

| SLA | Target | Scope |
|-----|--------|--------|
| **Batch window** | Daily full/incremental load completing within **60 minutes** on the sample dataset (local) | Extract → transform → load → DQ |
| **Latency (batch)** | Data available for reporting by **T+1 day** (business date) | v1; streaming later reduces this |
| **Availability** | Pipeline success rate ≥ **95%** over rolling 30 runs | Failed runs alerted; replay documented |
| **Recovery** | Failed batch re-runnable without duplicate facts (**idempotent** load) | Incremental phase; design for it from day one |
| **DQ gate** | Critical DQ failures **block** promote to analytics | Non-critical → warn + report |

Streaming / CDC latency targets (future): order events visible in serving layer within minutes — defined when Kafka/CDC work starts.

---

## 5. Data flow (target architecture)

Canonical diagrams and stack: **[architecture.md](architecture.md)**.

```
Olist CSV → Python/Pandas → PostgreSQL (ops)
                 │                    │
            Batch ETL               CDC (WAL → Debezium → Kafka
                 │                      → Spark Structured Streaming)
                 └──────────┬─────────┘
                            ▼
                     S3 Data Lake
                   Bronze → Silver → Gold
                            │
                            ▼
                   Warehouse (Postgres → Redshift)
                            │
                           dbt
                            │
                        Power BI
```

**Orchestration:** Apache Airflow schedules Python ETL, Spark, and dbt above this data plane.

**Contracts:**

- Raw Olist files under `data/` are immutable; do not edit in place.
- PostgreSQL is the operational source for SQL practice and later CDC.
- S3 holds medallion layers in Parquet; warehouse + dbt are the contract for Power BI.
- Do not stand up Kafka/Debezium/Streaming or Redshift before Phase A–B are working (see architecture build order).

---

## 6. Non-functional requirements

- **Reproducibility** — same inputs + config → same curated outputs.
- **Config via environment** — no secrets in git (`.env` gitignored).
- **Observability** — log rows in/out, runtime, DQ summary per entity.
- **Documentation** — domain model and this BR stay in sync when entities change.

---

## 7. Out of scope (v1)

- Real-time stock / inventory management system
- Payment gateway integration (dataset is historical payments only)
- PII enrichment beyond fields already in Olist exports
- Multi-tenant SaaS packaging

---

## 8. Acceptance criteria (business requirements)

- [x] Domain entities defined: customers, products, orders, order_items, payments — [domain-model.md](domain-model.md)
- [x] Success metrics defined (freshness, completeness, accuracy)
- [x] SLAs documented (batch window, latency, availability, recovery)
- [x] Data flow aligned to target architecture ([architecture.md](architecture.md): batch + CDC → S3 medallion → warehouse → dbt → Power BI)
- [x] Purpose covers stakeholders and report use cases (revenue, assortment/demand, retention, fulfillment, payments)

---

## 9. Open decisions

Track and resolve before locking curated marts:

- [ ] Revenue definition: include freight or product `price` only?
- [ ] Which `order_status` values count as “recognized” revenue?
- [ ] `customer_id` vs `customer_unique_id` as customer dimension key
- [ ] Tolerance and handling when payments ≠ items + freight
- [ ] Geolocation dedupe rule before geo enrichment
