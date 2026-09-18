# Optimization Notes

Two indexes, tested against one query that matches almost every row and one that
matches almost none. Plans captured with `EXPLAIN (ANALYZE, BUFFERS)` in
`sql/explain/` (re-captured 2026-09-12). Indexes are in `04_indexes.sql`.

## Headline

The index did **not** speed up q1, and that's the correct outcome — q1 reads
almost the whole table, so the planner keeps a Seq Scan. A selective query (0.6%
of rows) is where an index genuinely wins: the plan flips to an Index Scan and
runs ~20x faster, touching 554 pages instead of 2,821.

## q1 — monthly revenue (index ignored)

- Before and after: the same plan, a parallel hash join between
  `fact_order_items` and `fact_orders`, both sides sequentially scanned.
  `idx_foi_purchase_month` appears nowhere in it.
- The filter `purchase_month BETWEEN '2017-01-01' AND '2018-08-01'` keeps
  112,279 of 112,650 rows and drops 371 — 99.7% survives. Reading that through an
  index means one random heap fetch per row at `random_page_cost` 4.0, against
  3,045 sequential pages at 1.0, so the index loses by a wide margin.
- Note when reading the plan: the scan runs with a parallel worker, so its
  `rows=56140 loops=2` and `Rows Removed by Filter: 186` are **per worker**.
  Multiply by `loops` to get the totals.
- Both runs report `Buffers: shared hit=5891` with **no reads**, so both were
  fully cached. The execution times (51.3 ms then 23.3 ms) differ because the
  second run found everything warm, not because of the index — the plans are
  identical line for line.

## Selective lookup — index used

```sql
SELECT order_id, customer_unique_id, payment_total
FROM fact_orders
WHERE order_status = 'canceled';
```

625 of 99,441 rows = 0.6%.

| | Plan | Buffers | Time |
|---|---|---|---|
| Before | Seq Scan | `shared hit=2821` | 5.008 ms |
| After | Index Scan using `idx_fo_order_status` | `shared hit=552 read=2` | 0.245 ms |

The buffer counts are the explanation: 554 pages touched instead of 2,821, and
no filter comparison against the 98,816 rows that don't match.

**554 is not a small number, and that's the interesting part.** If the 625
matching rows were physically clustered they'd occupy ~18 pages. Scattered at
random over 2,821 pages, the expected number of distinct pages touched is
`2821 × (1 − (1 − 1/2821)^625) ≈ 561`. The measurement lands there, so the index
is doing scattered random fetches over a fifth of the table — and still wins by
20x, because the alternative reads all of it.

## The planner's arithmetic is reproducible

The Seq Scan cost in `selective_before.sql` falls out of four documented
constants:

```
2,821 pages × 1.0      (seq_page_cost)      = 2821.0
99,441 rows × 0.01     (cpu_tuple_cost)     =  994.4
99,441 rows × 0.0025   (cpu_operator_cost)  =  248.6
                                              ------
                                              4064.0     plan says cost=0.00..4064.01
```

That subtraction — this cost against the Index Scan's 309.21 — *is* the planner's
decision. It's also computed before execution, with no knowledge of what's in
the buffer pool, which is why a fully cached table doesn't change the plan.

## Takeaway

Indexes help **selective** filters, not full-table aggregations. An index only
pays when it lets you skip pages; q1 skips none, so it gains nothing while
adding index maintenance to every write. Knowing when *not* to add one is the
point of the experiment.

Row-store versus columnar is worth naming here: Postgres stores a
low-cardinality column like `order_status` (~6 values) in full on every row, so
a scan reads all of it. A columnar engine (DuckDB, ClickHouse, Snowflake) would
dictionary-encode it and read only that column, making the full scan cheap
without any index — so the same trade-off would look very different there.

## What this does not establish

- **One run per side.** No repetition, no medians, no variance.
- **Everything was cached.** Both sides report buffer hits and essentially no
  reads, so this measures buffer lookups and CPU, not disk I/O. On cold storage
  the gap would widen, but that wasn't measured.
- **Two points, not a curve.** The crossover — where the planner actually
  switches — would need a selectivity sweep (0.5%, 2%, 5%, 10%, 25%) with
  repeated runs.
- **Only tested where the table fits in memory.** At ~24 MB it always does.
