# Optimization Notes

Tested indexing on one analytical query (q1) and one selective lookup.

Plans captured with `EXPLAIN (ANALYZE, BUFFERS)` in `sql/explain/`.

Indexes are in `04_indexes.sql`.

## Headline

The index did **not** speed up q1 — and that's the correct outcome. q1 scans
almost the whole table, so the planner ignores the index and keeps a Seq Scan.
A selective query (0.6% of rows) is where an index genuinely wins: the plan
flips Seq Scan -> Index Scan, ~17x faster.

## q1 — monthly revenue (index ignored)

- Before: Seq Scan on `fact_order_items`.
- After: still Seq Scan — same plan, index not used.
- The filter `purchase_month >= '2017-01-01'` keeps 112,280 of 112,650 rows
  (drops only 370). Reading ~99.7% of the table, a Seq Scan is cheaper than an
  index, so Postgres ignores `idx_foi_purchase_month`. The plan is identical
  before and after; any time difference is caching (cold disk vs warm memory),
  not the index.

## Selective lookup — index used

Query:

```sql
SELECT order_id, customer_unique_id, payment_total
FROM fact_orders
WHERE order_status = 'canceled';
```

625 of 99,441 rows = 0.6%.

- Before: Seq Scan, 8.2 ms.
- After: Index Scan using `idx_fo_order_status`, 0.49 ms (~17x faster).
- The plan flips to `Index Scan` with
  `Index Cond: (order_status = 'canceled')` — Postgres jumps straight to the
  625 matching rows instead of reading all 99,441.

## Takeaway

Indexes help **selective** filters, not full-table aggregations. q1 (and the
other analytical queries) read most or all of each table, so they gain nothing
from indexing; their cost is reading and sorting data an index cannot avoid.
Knowing when *not* to add an index is part of the point.

Note (row-store vs columnar): Postgres is a row-store with no native columnar
compression, so a low-cardinality column like `order_status` (~6 values) is
stored in full on every row. A columnar/OLAP engine (DuckDB, ClickHouse,
Snowflake, Redshift) would dictionary-encode it and read only that column,
making full scans cheap without indexes — but that advantage shows up at far
larger scale than this ~100k-row dataset.
