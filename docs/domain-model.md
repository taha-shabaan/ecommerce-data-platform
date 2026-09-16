# Ecommerce Domain Model (Olist)

Source: Brazilian Olist marketplace CSVs in `data/`.  
**Related:** [Architecture](architecture.md) · [Business requirements](business-requirements.md)

Core entities: **customers**, **products**, **orders**, **order_items**, **payments**.  
Supporting entities: **sellers**, **reviews**, **geolocation**, **product_category**.  
Business context: [business-requirements.md](business-requirements.md).

```
customers ──< orders ──< order_items >── products
                │              │
                │              └──> sellers
                │
                ├──< payments
                └──< reviews

products >── product_category
customers / sellers ──> geolocation (via zip_code_prefix)
```

---

## 1. customers

**Source file:** `data/customers.csv` (~99,441 rows)

| Column | Type | Role | Notes |
|--------|------|------|-------|
| `customer_id` | string | PK | Key used on each order (one per order in Olist) |
| `customer_unique_id` | string | business key | True person identity across orders |
| `customer_zip_code_prefix` | string | FK → geolocation | First 5 digits of ZIP |
| `customer_city` | string | attr | |
| `customer_state` | string | attr | UF code (e.g. `SP`) |

**Business meaning:** Buyer on the marketplace. Prefer `customer_unique_id` for retention / lifetime analysis; join orders on `customer_id`.

---

## 2. products

**Source file:** `data/products.csv` (~32,951 rows)

| Column | Type | Role | Notes |
|--------|------|------|-------|
| `product_id` | string | PK | |
| `product_category_name` | string | FK → category | Portuguese category; may be null |
| `product_name_lenght` | int | attr | Typo in source: *lenght* |
| `product_description_lenght` | int | attr | |
| `product_photos_qty` | int | attr | |
| `product_weight_g` | int | attr | |
| `product_length_cm` | int | attr | |
| `product_height_cm` | int | attr | |
| `product_width_cm` | int | attr | |

**Related:** `data/product_category.csv` maps `product_category_name` → `product_category_name_english`.

**Business meaning:** Catalog item sold by one or more sellers (seller is on the order line, not on the product).

---

## 3. orders

**Source file:** `data/orders.csv` (~99,441 rows)

| Column | Type | Role | Notes |
|--------|------|------|-------|
| `order_id` | string | PK | |
| `customer_id` | string | FK → customers | |
| `order_status` | string | attr | e.g. `delivered`, `shipped`, `canceled`, … |
| `order_purchase_timestamp` | timestamp | event | Order placed |
| `order_approved_at` | timestamp | event | Payment approved (nullable) |
| `order_delivered_carrier_date` | timestamp | event | Handed to carrier (nullable) |
| `order_delivered_customer_date` | timestamp | event | Delivered (nullable) |
| `order_estimated_delivery_date` | date | attr | Promised delivery |

**Business meaning:** Header for a purchase. Grain = one checkout / order. Lifecycle is encoded in status + timestamp columns.

---

## 4. order_items

**Source file:** `data/order_items.csv` (~112,650 rows)

| Column | Type | Role | Notes |
|--------|------|------|-------|
| `order_id` | string | PK (part), FK → orders | |
| `order_item_id` | int | PK (part) | Line number within the order |
| `product_id` | string | FK → products | |
| `seller_id` | string | FK → sellers | |
| `shipping_limit_date` | timestamp | attr | Seller ship-by deadline |
| `price` | decimal | measure | Item price (BRL) |
| `freight_value` | decimal | measure | Shipping allocated to this line |

**Composite PK:** (`order_id`, `order_item_id`)

**Business meaning:** Line item — what was sold, by whom, at what price. Revenue facts usually start here (`price` + `freight_value`).

---

## 5. payments

**Source file:** `data/payments.csv` (~103,886 rows)

| Column | Type | Role | Notes |
|--------|------|------|-------|
| `order_id` | string | PK (part), FK → orders | |
| `payment_sequential` | int | PK (part) | Multiple payments per order possible |
| `payment_type` | string | attr | e.g. `credit_card`, `boleto`, `voucher`, `debit_card` |
| `payment_installments` | int | attr | |
| `payment_value` | decimal | measure | Amount for this payment sequence |

**Composite PK:** (`order_id`, `payment_sequential`)

**Business meaning:** How the order was paid. One order can have several payment rows (split payment / vouchers).

---

## Supporting entities

### sellers
`data/sellers.csv` — PK `seller_id`; location via zip/city/state. Linked from `order_items`.

### reviews
`data/reviews.csv` — PK `review_id`; FK `order_id`; score + optional comments + timestamps.

### geolocation
`data/geolocation.csv` — many rows per `geolocation_zip_code_prefix` (lat/lng). Join carefully (aggregate or pick one point per zip).

### product_category
`data/product_category.csv` — PK `product_category_name`; English label for reporting.

---

## Relationship summary

| From | To | Cardinality | Join key |
|------|-----|-------------|----------|
| orders | customers | N:1 | `customer_id` |
| order_items | orders | N:1 | `order_id` |
| order_items | products | N:1 | `product_id` |
| order_items | sellers | N:1 | `seller_id` |
| payments | orders | N:1 | `order_id` |
| reviews | orders | N:1 (approx.) | `order_id` |
| products | product_category | N:1 | `product_category_name` |
| customers | geolocation | N:N* | `customer_zip_code_prefix` = `geolocation_zip_code_prefix` |

\*Geolocation is not unique on zip prefix — resolve before joining.

---

## Suggested analytical grains

| Use case | Grain | Primary tables |
|----------|-------|----------------|
| Order funnel / status | 1 row per order | `orders` |
| GMV / item revenue | 1 row per order line | `order_items` (+ `orders`, `products`) |
| Payment mix | 1 row per payment | `payments` (+ `orders`) |
| Customer retention | 1 row per unique customer | `customers.customer_unique_id` ← `orders` |
| Seller performance | 1 row per seller × period | `order_items` ← `sellers` |

---

## Open decisions

- [ ] Treat `customer_id` vs `customer_unique_id` consistently in dims
- [ ] How to handle null `product_category_name` and null delivery timestamps
- [ ] Whether payment totals must equal sum of item `price` + `freight_value`
- [ ] Geolocation dedupe rule before location enrichment
