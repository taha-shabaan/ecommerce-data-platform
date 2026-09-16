# Data Dictionary

**Source:** Olist CSVs in `data/`  
**Related:** [Domain model](domain-model.md) · [Business requirements](business-requirements.md)

Nullability is measured on the local files (empty string treated as null).  
**Nullable?** = observed nulls in source (`Yes` if any nulls; `No` if none). PK/FK columns should remain non-null in the warehouse even when source is clean.

---

## customers — `data/customers.csv`

**Rows:** 99,441

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `customer_id` | string | No | 0 | PK. Key used on each order (Olist: one `customer_id` per order) |
| `customer_unique_id` | string | No | 0 | True person identity across orders (retention key) |
| `customer_zip_code_prefix` | string | No | 0 | ZIP prefix; join to geolocation |
| `customer_city` | string | No | 0 | Customer city |
| `customer_state` | string | No | 0 | Brazilian state UF (e.g. `SP`) |

---

## products — `data/products.csv`

**Rows:** 32,951

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `product_id` | string | No | 0 | PK |
| `product_category_name` | string | Yes | 610 (1.85%) | Category in Portuguese; FK → product_category |
| `product_name_lenght` | int | Yes | 610 (1.85%) | Length of product name (source typo: *lenght*) |
| `product_description_lenght` | int | Yes | 610 (1.85%) | Length of description |
| `product_photos_qty` | int | Yes | 610 (1.85%) | Number of product photos |
| `product_weight_g` | int | Yes | 2 (0.01%) | Weight in grams |
| `product_length_cm` | int | Yes | 2 (0.01%) | Length (cm) |
| `product_height_cm` | int | Yes | 2 (0.01%) | Height (cm) |
| `product_width_cm` | int | Yes | 2 (0.01%) | Width (cm) |

---

## orders — `data/orders.csv`

**Rows:** 99,441

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `order_id` | string | No | 0 | PK |
| `customer_id` | string | No | 0 | FK → customers |
| `order_status` | string | No | 0 | Lifecycle status (`delivered`, `shipped`, `canceled`, …) |
| `order_purchase_timestamp` | timestamp | No | 0 | When the order was placed |
| `order_approved_at` | timestamp | Yes | 160 (0.16%) | Payment/approval time |
| `order_delivered_carrier_date` | timestamp | Yes | 1,783 (1.79%) | Handed to carrier |
| `order_delivered_customer_date` | timestamp | Yes | 2,965 (2.98%) | Delivered to customer |
| `order_estimated_delivery_date` | date | No | 0 | Promised delivery date |

---

## order_items — `data/order_items.csv`

**Rows:** 112,650  
**PK:** (`order_id`, `order_item_id`)

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `order_id` | string | No | 0 | FK → orders |
| `order_item_id` | int | No | 0 | Line number within the order |
| `product_id` | string | No | 0 | FK → products |
| `seller_id` | string | No | 0 | FK → sellers |
| `shipping_limit_date` | timestamp | No | 0 | Seller ship-by deadline |
| `price` | decimal | No | 0 | Item price (BRL) |
| `freight_value` | decimal | No | 0 | Freight allocated to this line (BRL) |

---

## payments — `data/payments.csv`

**Rows:** 103,886  
**PK:** (`order_id`, `payment_sequential`)

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `order_id` | string | No | 0 | FK → orders |
| `payment_sequential` | int | No | 0 | Sequence when an order has multiple payments |
| `payment_type` | string | No | 0 | e.g. `credit_card`, `boleto`, `voucher`, `debit_card` |
| `payment_installments` | int | No | 0 | Number of installments |
| `payment_value` | decimal | No | 0 | Amount for this payment row (BRL) |

---

## sellers — `data/sellers.csv`

**Rows:** 3,095

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `seller_id` | string | No | 0 | PK |
| `seller_zip_code_prefix` | string | No | 0 | ZIP prefix |
| `seller_city` | string | No | 0 | Seller city |
| `seller_state` | string | No | 0 | Seller state UF |

---

## reviews — `data/reviews.csv`

**Rows:** 99,224

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `review_id` | string | No | 0 | PK |
| `order_id` | string | No | 0 | FK → orders |
| `review_score` | int | No | 0 | Score (typically 1–5) |
| `review_comment_title` | string | Yes | 87,658 (88.34%) | Optional title |
| `review_comment_message` | string | Yes | 58,274 (58.73%) | Optional free text |
| `review_creation_date` | timestamp | No | 0 | Review created |
| `review_answer_timestamp` | timestamp | No | 0 | Review answered / recorded |

---

## geolocation — `data/geolocation.csv`

**Rows:** 1,000,163  
**Note:** `geolocation_zip_code_prefix` is **not unique** — many lat/lng rows per prefix. Dedupe before joining.

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `geolocation_zip_code_prefix` | string | No | 0 | ZIP prefix (join key) |
| `geolocation_lat` | float | No | 0 | Latitude |
| `geolocation_lng` | float | No | 0 | Longitude |
| `geolocation_city` | string | No | 0 | City name |
| `geolocation_state` | string | No | 0 | State UF |

---

## product_category — `data/product_category.csv`

**Rows:** 71

| Column | Type (logical) | Nullable? | Nulls | Meaning |
|--------|----------------|-----------|-------|---------|
| `product_category_name` | string | No | 0 | PK; Portuguese category name |
| `product_category_name_english` | string | No | 0 | English label for reporting |

---

## Nullability summary (watch list)

| Table | Column | Null % | Handling note |
|-------|--------|--------|----------------|
| orders | `order_approved_at` | 0.16% | Expected for some non-approved statuses |
| orders | `order_delivered_carrier_date` | 1.79% | Null until shipped / if canceled |
| orders | `order_delivered_customer_date` | 2.98% | Null until delivered / if canceled |
| products | category + name/desc/photos fields | 1.85% | Same 610 products missing category metadata |
| products | weight / dimensions | 0.01% | Rare; impute or quarantine in DQ |
| reviews | `review_comment_title` | 88.34% | Optional text — do not fail DQ |
| reviews | `review_comment_message` | 58.73% | Optional text — do not fail DQ |
