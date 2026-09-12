# Olist Warehouse Performance Lab

A small analytical data warehouse built on the [Olist Brazilian e-commerce
dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(~99k orders, Sep 2016 – Sep 2018). Loads raw CSVs into PostgreSQL 16, builds a
star schema, answers six business questions with analytical SQL, and documents a
small indexing experiment.

## Stack

PostgreSQL 16. No extensions required.

## Project layout

```text
sql/
  00_raw_schema.sql        raw tables (mirror the source CSVs)
  01_load_raw.sql          \copy loaders
  02_warehouse_schema.sql  star schema DDL (3 dims, 3 facts)
  03_build_facts_dims.sql  transform + load raw -> warehouse
  04_indexes.sql           indexes for the optimization test
  05_checks.sql            read-only checks behind the docs
  q1..q6_*.sql             the six analytical queries
  explain/                 EXPLAIN ANALYZE captures (before/after)
findings.md                business results from q1-q6
schema_notes.md            schema-level notes
decisions.md               decision record: what, why, alternatives, when I'd choose differently
optimization.md            indexing experiment write-up
data/raw/                  CSVs (not committed - see Setup)
```

## Setup

1. Download the 9 CSVs from Kaggle and place them in `data/raw/`.
2. Create the database and run the scripts in order:

```bash
createdb olist
psql -d olist -f sql/00_raw_schema.sql
psql -d olist -f sql/01_load_raw.sql        # run from the repo root (\copy uses relative paths)
psql -d olist -f sql/02_warehouse_schema.sql
psql -d olist -f sql/03_build_facts_dims.sql
psql -d olist -f sql/04_indexes.sql
psql -d olist -f sql/05_checks.sql          # every check should return what its comment says
```

Then run any analytical query, e.g. `psql -d olist -f sql/q1_monthly_revenue.sql`.

## Schema

A star schema with three dimensions and three facts.

- **dim_customers** — one row per person (`customer_unique_id`), with location.
- **dim_products** — product attributes + English category.
- **dim_sellers** — seller location.
- **fact_orders** — one row per order; delivery + payment measures.
- **fact_order_items** — one row per line item; `item_total_value` = price + freight.
- **fact_reviews** — one row per review (surrogate key); delivery delay + score.

Key design decisions (full detail in `schema_notes.md`):

- Customer key is `customer_unique_id`, not the per-order `customer_id`.
- Zip prefixes are `TEXT` to preserve leading zeros.
- `fact_reviews` uses a `BIGSERIAL` surrogate (no natural key is unique).
- Cancelled orders are stored but filtered per query.
- Lateness is compared by calendar day — the estimated delivery date has no time of day.

## The six queries

| # | Query | Technique |
|---|-------|-----------|
| q1 | Monthly revenue | `LAG`, 3-month moving average |
| q2 | Cohort retention | per-customer cohorts, retention math |
| q3 | Top sellers per category | `RANK() OVER (PARTITION BY ...)` |
| q4 | Late delivery by state | conditional aggregation, fact->dim join |
| q5 | RFM segmentation | `NTILE(4)` on R / F / M |
| q6 | Review score vs delay | bucketed averages |

## Key findings (see `findings.md`)

- **Revenue** grew from ~R$137k (Jan 2017) to a ~R$1.0–1.15M/month plateau from
  Jan 2018, measured over non-cancelled orders in a 2017-01 .. 2018-08 window.
- **Retention is near zero** — ~0.5% return the next month; 96.9% of customers
  order exactly once. A buy-once marketplace, not a recurring one.
- **Late delivery is regional** — 21.4% in Alagoas (north/northeast) vs single
  digits near São Paulo; 6.77% nationally.
- **Delay drives bad reviews** — early orders average 4.29 stars, 2.99 when 1–5
  days late, 1.74 when more than 5 days late.

## Optimization (see `optimization.md`)

Indexing test on q1 (a full-table aggregation) and a selective lookup. q1's index
is ignored — Postgres keeps a Seq Scan because the query reads ~99.7% of the
table. A selective filter (`order_status = 'canceled'`, 0.6% of rows) flips
Seq Scan -> Index Scan and runs ~20x faster, touching 554 pages instead of 2,821.
The lesson: indexes help selective filters, not full scans.
