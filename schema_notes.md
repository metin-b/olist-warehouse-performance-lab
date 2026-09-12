# Schema Notes

Raw layer mirrors the source CSVs. Warehouse is a star schema: 3 dims, 3 facts,
with derived columns added at build time. Why each choice was made, and what the
alternatives were, is in `decisions.md`.

## Zip prefixes are TEXT

CEP prefixes have leading zeros (`01151`, `09790`). INTEGER strips them
(`01151` -> `1151`), breaking ~24% of customers. They're identifiers, not
numbers, so they're TEXT. All prefixes are length 5.

## Customer key is customer_unique_id, not customer_id

Olist gives each order a new `customer_id`, so it's unique per order, not per
person. `customer_unique_id` is the real person. `dim_customers` is keyed on it
(99,441 rows collapse to 96,096 people). `DISTINCT ON` + `ORDER BY customer_id`
keeps the pick deterministic when a person's rows disagree on city/zip. 2,997
people ordered more than once and 39 of them ever shipped to a different state;
`decisions.md` covers what that costs q4.

`customer_id` isn't stored in the dim — facts carry `customer_unique_id`
directly, so it's never needed as a join key.

## fact_reviews has a surrogate key

No *single-column* natural key is unique: `review_id` repeats (814 dupes, one
review recorded against several orders of a split purchase) and `order_id`
repeats (an order can have multiple reviews). `(review_id, order_id)` **is**
unique — 99,224 rows, 99,224 distinct pairs.

`review_sk BIGSERIAL` is used anyway; `decisions.md` says why. Nothing
references it.

`fact_orders` and `fact_order_items` keep natural keys since theirs are clean.

## Cancelled orders stay in, filtered per query

Cancellations are real events, so they're kept in `fact_orders`. Each query
decides: revenue/seller queries drop `canceled`/`unavailable`; late-delivery
uses `delivered` only.

## Derived columns

- `delivery_days` etc: `EXTRACT(EPOCH FROM (a-b))/86400.0` (fractional days)
- `is_delivered_late`: delivered > estimated (NULL if not delivered)
- `purchase_month`: month truncation for grouping
- `item_total_value` = price + freight

## Revenue: two bases

- `payment_total` (fact_orders) = what customers paid
- `item_total_value` (fact_order_items) = catalog price + freight (used in q1)

Both reconcile to raw; they differ by ~R$165k by definition.

## No FK constraints

Zero orphans across all facts->dims, verified 2026-09-12 (the check query is in
`decisions.md`). FKs left off — enforcement costs an index lookup per row per
constraint on load, and there's one writer whose input is a consistent export.
They would validate if added; the warehouse pattern is to verify after loading
rather than enforce during it.
