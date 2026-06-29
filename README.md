\# Olist Warehouse Performance Lab



A small analytical data warehouse built on the \[Olist Brazilian e-commerce

dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

(\~99k orders, Sep 2016 – Sep 2018). Loads raw CSVs into PostgreSQL 16, builds a

star schema, answers six business questions with analytical SQL, and documents a

small indexing experiment.



\## Stack

PostgreSQL 16. No extensions required.



\## Project layout

```

sql/

&#x20; 00\_raw\_schema.sql        raw tables (mirror the source CSVs)

&#x20; 01\_load\_raw.sql          \\copy loaders

&#x20; 02\_warehouse\_schema.sql  star schema DDL (3 dims, 3 facts)

&#x20; 03\_build\_facts\_dims.sql  transform + load raw -> warehouse

&#x20; 04\_indexes.sql           indexes for the optimization test

&#x20; q1..q6\_\*.sql             the six analytical queries

&#x20; explain/                 EXPLAIN ANALYZE captures (before/after)

findings.md                business results from q1-q6

schema\_notes.md            design decisions and why

optimization.md            indexing experiment write-up

data/raw/                  CSVs (not committed - see Setup)

```



\## Setup

1\. Download the 9 CSVs from Kaggle and place them in `data/raw/`.

2\. Create the database and run the scripts in order:



```bash

createdb olist

psql -d olist -f sql/00\_raw\_schema.sql

psql -d olist -f sql/01\_load\_raw.sql        # run from the repo root (\\copy uses relative paths)

psql -d olist -f sql/02\_warehouse\_schema.sql

psql -d olist -f sql/03\_build\_facts\_dims.sql

psql -d olist -f sql/04\_indexes.sql

```



Then run any analytical query, e.g. `psql -d olist -f sql/q1\_monthly\_revenue.sql`.



\## Schema

A star schema with three dimensions and three facts.



\- \*\*dim\_customers\*\* — one row per person (`customer\_unique\_id`), with location.

\- \*\*dim\_products\*\* — product attributes + English category.

\- \*\*dim\_sellers\*\* — seller location.

\- \*\*fact\_orders\*\* — one row per order; delivery + payment measures.

\- \*\*fact\_order\_items\*\* — one row per line item; `item\_total\_value` = price + freight.

\- \*\*fact\_reviews\*\* — one row per review (surrogate key); delivery delay + score.



Key design decisions (full detail in `schema\_notes.md`):

\- Customer key is `customer\_unique\_id`, not the per-order `customer\_id`.

\- Zip prefixes are `TEXT` to preserve leading zeros.

\- `fact\_reviews` uses a `BIGSERIAL` surrogate (no natural key is unique).

\- Cancelled orders are stored but filtered per query.



\## The six queries

| # | Query | Technique |

|---|-------|-----------|

| q1 | Monthly revenue | `LAG`, 3-month moving average |

| q2 | Cohort retention | per-customer cohorts, retention math |

| q3 | Top sellers per category | `RANK() OVER (PARTITION BY ...)` |

| q4 | Late delivery by state | conditional aggregation, fact->dim join |

| q5 | RFM segmentation | `NTILE(4)` on R / F / M |

| q6 | Review score vs delay | bucketed averages |



\## Key findings (see `findings.md`)

\- \*\*Revenue\*\* grew from \~R$137k (Jan 2017) to a \~R$1.1M/month plateau by mid-2018.

\- \*\*Retention is near zero\*\* — \~0.5% return the next month; 96.9% of customers

&#x20; order exactly once. A buy-once marketplace, not a recurring one.

\- \*\*Late delivery is regional\*\* — \~24% in Alagoas (north/northeast) vs single

&#x20; digits near São Paulo.

\- \*\*Delay drives bad reviews\*\* — early/on-time orders average \~4.3 stars,

&#x20; dropping to 1.79 when more than 5 days late.



\## Optimization (see `optimization.md`)

Indexing test on q1 (a full-table aggregation) and a selective lookup. q1's index

is ignored — Postgres keeps a Seq Scan because the query reads \~99.7% of the

table. A selective filter (`order\_status = 'canceled'`, 0.6% of rows) flips

Seq Scan -> Index Scan and runs \~17x faster. The lesson: indexes help selective

filters, not full scans.

