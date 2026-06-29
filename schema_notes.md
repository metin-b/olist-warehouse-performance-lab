\# Schema Notes



Raw layer mirrors the source CSVs. Warehouse is a star schema: 3 dims, 3 facts,

with derived columns added at build time.



\## Zip prefixes are TEXT

CEP prefixes have leading zeros (`01151`, `09790`). INTEGER strips them

(`01151` -> `1151`), breaking \~24% of customers. They're identifiers, not

numbers, so they're TEXT. All prefixes are length 5.



\## Customer key is customer\_unique\_id, not customer\_id

Olist gives each order a new `customer\_id`, so it's unique per order, not per

person. `customer\_unique\_id` is the real person. `dim\_customers` is keyed on it

(99,441 rows collapse to 96,096 people). `DISTINCT ON` + `ORDER BY customer\_id`

keeps the pick deterministic when a person's rows disagree on city/zip.

`customer\_id` isn't stored in the dim — facts carry `customer\_unique\_id`

directly, so it's never needed as a join key.



\## fact\_reviews has a surrogate key

No natural key is unique: `review\_id` repeats (814 dupes), `order\_id` repeats

(orders can have multiple reviews). `review\_sk BIGSERIAL` guarantees identity,

lets the load take every row, and leaves dedup as a query-time choice.

`fact\_orders` and `fact\_order\_items` keep natural keys since theirs are clean.



\## Cancelled orders stay in, filtered per query

Cancellations are real events, so they're kept in `fact\_orders`. Each query

decides: revenue/seller queries drop `canceled`/`unavailable`; late-delivery

uses `delivered` only.



\## Derived columns

\- `delivery\_days` etc: `EXTRACT(EPOCH FROM (a-b))/86400.0` (fractional days)

\- `is\_delivered\_late`: delivered > estimated (NULL if not delivered)

\- `purchase\_month`: month truncation for grouping

\- `item\_total\_value` = price + freight



\## Revenue: two bases

\- `payment\_total` (fact\_orders) = what customers paid

\- `item\_total\_value` (fact\_order\_items) = catalog price + freight (used in q1)



Both reconcile to raw; they differ by \~R$165k by definition.



\## No FK constraints

Verified zero orphans across all facts->dims. FKs left off (load speed; build

guarantees integrity) but would validate if added.

