# Decision Record

What was chosen, why, what else was considered, and when the choice would
change. Schema facts are in `schema_notes.md`, measurements in
`optimization.md`, and the checks behind the numbers in `sql/05_checks.sql`.

| # | Decision | In one line |
|---|---|---|
| 1 | PostgreSQL 16 | The deliverable is an indexing experiment, which needs user-defined indexes and a readable planner |
| 2 | Star schema | Raw is shaped for recording; the star is shaped for asking, and fixes each definition in one place |
| 3 | `customer_unique_id` as the customer key | `customer_id` is per-order, so keying on it would make retention and frequency unmeasurable |
| 4 | Measures derived in the build | One definition beats six; the cost is that the rule becomes invisible from the query |
| 5 | Cancelled orders kept in the facts | Filtering in the build destroys data; filtering in the query keeps the choice |
| 6 | No foreign key constraints | One controlled writer, so integrity is verified after the load instead of enforced during it |
| 7 | `BIGSERIAL` surrogate on `fact_reviews` | No single-column natural key is unique; a composite one exists but nothing needs a stable key here |
| 8 | The index experiment | Measures when an index earns its keep, not how fast a query can be made |

## 1. PostgreSQL 16

**Decision.** A row-store, client/server RDBMS, over the embedded and columnar
options I'd already used.

**Why.** Postgres was the default choice, not a considered one. The reason that
holds up is the deliverable: an indexing experiment needs user-defined indexes
and a planner whose plans can be read.

**Alternatives.** DuckDB would be faster on all six queries — it's columnar, so
it reads only the columns a query touches. It does support `CREATE INDEX`
(adaptive radix tree indexes), but those mainly serve point lookups and
constraints, and its automatic min-max zonemaps already skip data on range
filters, so the trade-off this experiment measures — sequential scan against an
index plus heap fetches — wouldn't show up the same way. Snowflake's standard
tables have no user-defined indexes by design: pruning on micro-partition
metadata does that job.

**When I'd choose differently.** DuckDB for analytics on one machine with no
server to run; its limit is being embedded and single-writer, not data volume.
Snowflake once there are concurrent users, hundreds of GB, or a team needing one
source of truth.

**Cost.** An analytical workload on a row store: every query reads whole pages
carrying all of a row's columns, where a columnar engine would read one column.
Irrelevant at this size, and it's what makes the index experiment visible at all.

## 2. Star schema over querying raw

**Decision.** Three dimensions and three facts, built by
`03_build_facts_dims.sql`.

**Why.** The raw tables are shaped for recording transactions — a "customer"
there is whatever checkout created. The star is shaped for asking questions, so
every query is one fact plus a join per dimension, and each definition is fixed
in one place: revenue, lateness, delivery days and customer identity are settled
in the build instead of re-decided in six queries.

**Alternatives.** Querying raw directly, or building the same shape as views. At
100k static rows views would have worked — the build step buys precomputation
this dataset doesn't really need.

**Cost.** Computed once also means wrong once: the lateness definition lives in
the build, so a bad comparison there is invisible from q4 and q6, which read a
boolean that looks authoritative. Otherwise nil here — the dataset is a finished
export, so nothing goes stale and no copy can drift.

**Rebuild is safe.** Every warehouse table is a pure function of raw, so
`TRUNCATE` + rebuild reproduces the same rows. Nothing here accumulates state,
unlike an SCD2 dimension whose history is built up by the pipeline rather than
read from the source.

### Why `fact_order_items` repeats three columns from `fact_orders`

`customer_unique_id`, `purchase_date` and `purchase_month` are carried down to
line-item grain so revenue queries read one table instead of joining back.

That's safe on two conditions, not guarantees: both facts are rebuilt in one
transaction from the same rows, so the copies can't diverge; and the copied
columns are keys and event timestamps rather than attributes that change —
copying `customer_state` would freeze an address at build time.

**The live hazard is fan-out.** `payment_total` is order-grain, so joining the
two facts repeats it per line item and summing it multiplies revenue. Nothing
prevents that. q3 joins both and avoids it by summing `item_total_value`, the
item-grain measure.

## 3. Customer key is `customer_unique_id`

**Decision.** One row per person in `dim_customers`: 99,441 raw rows collapse to
96,096 people.

**Why.** Olist issues a new `customer_id` per order, so it identifies a checkout,
not a person. Keying on it would make the dimension one row per order, and it
would break two analyses: q2 retention would show nobody ever returning, because
every order invents a new customer, and q5's frequency score would be 1 for
everyone. That 96.9% of customers order exactly once is only measurable because
the key is the person.

**Which row survives.** The smallest `customer_id`, which is a hash with no time
component — deterministic but arbitrary, neither earliest nor latest.
Deterministic is what makes rebuilds reproducible; it isn't the same as correct.

**Cost, measured.** 2,997 people ordered more than once and 39 ever shipped to a
different state, so q4 attributes those orders to the wrong state (check 9 in
`sql/05_checks.sql`).

**When I'd choose differently.** A shipping address belongs to the order, not the
person. At meaningful volume I'd store the state on `fact_orders`, or make
`dim_customers` Type 2 and join point-in-time on the order date — which is what
`dim_user` does in the Gym Log warehouse, where the history is the point. Type 1
is right here for 39 customers.

## 4. Measures computed in the build, not in the queries

**Decision.** `delivery_days`, `late_delivery_days`, `is_delivered_late`,
`payment_total` and `item_total_value` are derived in the build and stored.

**Why.** Consistency first, performance second. `is_delivered_late` is a
comparison between two columns of the same row, so deriving it per query would
cost almost nothing — but six queries writing their own comparison is six
chances to disagree about the same order. `payment_total` is the one where
performance matters: it aggregates every payment row per order.

**Cost.** The definition is frozen — changing it means rebuilding, not editing a
query — and it's invisible: q4 reads `is_delivered_late` and shows nothing of the
rule behind it, which is how a wrong rule would hide.

**Where the line sits.** Would two analysts reasonably want different versions of
this column? Elapsed days: no, so it goes in the build. q6's delay buckets: yes,
someone else picks different cut-offs, so they stay in the query.

**What I'd add.** An `is_completed` flag on `fact_orders` for the
`canceled`/`unavailable` exclusion, so the definition is fixed once while the
filtering stays per query. q1 ran without that filter while q3 applied it, and
nothing made the mismatch visible until it was fixed on 2026-09-12.

## 5. Cancelled orders stay in the facts

**Decision.** Every order is loaded whatever its status. Each query decides which
statuses it counts.

**Why.** Dropping rows in the build is irreversible: a query can always filter
rows out, but no query can bring back rows that were never loaded. Without
cancelled orders I couldn't ask whether people who cancel paid differently from
people who didn't — that comparison needs both populations in the table. It would
also quietly bias unrelated questions: "how do customers pay?" over a table with
cancellations removed is really answering "how do customers who completed an
order pay?"

**Three separate decisions, not one.** q1 and q3 exclude `canceled` and
`unavailable` because they measure revenue; q4 keeps only `delivered` because
only a delivered order can be late; q2 counts every order because any order shows
the customer was active.

**Cost.** Each rule lives only in its own `WHERE` clause, so an omitted filter
is indistinguishable from a deliberate one — which is exactly what happened to q1.

## 6. No foreign key constraints

**Decision.** None declared. Facts reference dimensions by convention, and joins
behave as they would with constraints.

**Why.** A foreign key is checked on every insert, and here there is exactly one
writer — the build script — whose input is an export from a system that already
enforced these rules. The trade inverts in a transactional database, where writes
arrive continuously from many places and the database is the last line of defence.

**What they'd have bought.** Turning an assumption into an enforced invariant:
"every item's product exists" is currently a belief, and a violation would
surface silently. `fact_orders` resolves `customer_unique_id` through a
`LEFT JOIN`, so a missing customer yields NULL rather than a lost row, and q4
then inner-joins to `dim_customers` and drops that order — a wrong number, no
error, at either step.

**What "the build guarantees integrity" means.** Each dimension is built from the
same raw table the facts reference, so the warehouse is consistent *if the export
is*. The build inherits integrity rather than creating it, and nothing verified
that inheritance until `sql/05_checks.sql` existed. Zero orphans on all four
paths, 2026-09-12.

**When I'd choose differently.** If anything but the build script could write to
these tables, or if the source stopped being one consistent export. Otherwise the
warehouse pattern is to verify after loading rather than enforce during it.

## 7. `fact_reviews` has a `BIGSERIAL` surrogate key

**Decision.** `review_sk BIGSERIAL PRIMARY KEY`, while the other two facts keep
their natural keys.

**Why.** Neither single-column candidate is unique. `order_id` repeats because an
order can have several reviews; `review_id` repeats because one review is
recorded against several orders — checked, and the duplicates are 3 rows against
3 *different* orders with the same score, i.e. one purchase split into separate
orders. A surrogate lets the load take every source row and leaves dedup as a
query-time choice.

**The honest correction.** `(review_id, order_id)` **is** unique — 99,224 rows,
99,224 distinct pairs (check 2) — so a composite natural key does exist. "No
natural key is unique" is only true of single columns.

**Why the surrogate still stands.** Nothing references `review_sk`, so a sequence
costs nothing here even though it depends on insertion order and isn't guaranteed
stable across rebuilds.

**When I'd use a hash instead.** As soon as the key must be stable across builds
or across systems. Gym Log's `fct_sets` needs that: `delete+insert` on
`set_key = md5(set_id)` only finds the previous version because the key is
derived from the data. The DuckDB → Snowflake reconciliation needed it too — both
engines derived identical keys from identical input, so rows could be compared
directly.

## 8. What the index experiment measured

**Decision.** Two indexes, one on a filter matching almost every row and one on a
filter matching almost none, with `EXPLAIN (ANALYZE, BUFFERS)` captured before
and after each. Numbers and plans are in `optimization.md` and `sql/explain/`.

**What was optimized: nothing, deliberately.** The experiment measures when an
index earns its keep, and half the answer is a case where the right move is not
to use one. On a 0.6% filter the plan flips to an Index Scan and touches 554
pages instead of 2,821; on a 99.7% filter the planner ignores the index, because
reading nearly every row through it would mean a random fetch per row instead of
a sequential pass.

**The buffer counts are the evidence.** A warm cache makes a query faster while
the work stays the same; a plan change shows up in pages touched. That's the
difference between this and a query that returns quickly because a cache answered
it.

**What it doesn't establish.** One run per side, both fully cached, two points
rather than a curve, and only tested where the table fits in memory.
`optimization.md` lists these against the numbers.
