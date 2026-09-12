# Findings

Olist Brazilian e-commerce, ~99k orders, Sep 2016 – Sep 2018.

q1–q6 complete. Numbers re-run 2026-09-12, after lateness was changed to a
calendar-day comparison and q1 was given the cancelled-order filter and an
upper bound on its window.

Scope: activity before 2017-01 is negligible (4 orders in 2016-09, 1 in 2016-12,
Nov 2016 empty) and the data thins out after 2018-08 (16 orders in 2018-09, 4 in
2018-10), so trend analysis runs 2017-01 through 2018-08.

## q1 — Monthly revenue

Grew from ~R$137k (Jan 2017) to a ~R$1.0–1.15M/month plateau from Jan 2018
onward, ending at ~R$997k in Aug 2018. Roughly doubled over 2017, then flat
through 2018. The 3-month average confirms real growth rather than spikes; the
only large single-month jump is Nov 2017 (+53%, Black Friday).

Revenue here is `item_total_value` on orders that weren't cancelled or
unavailable.

## q2 — Cohort retention

Near zero. ~0.48% return the month after their first order, ~1.9% ever return.
Cause: 96.96% of customers order exactly once. This is a buy-once marketplace,
not a recurring business.

## q3 — Top sellers per category

Category leaders: office_furniture (R$219,596), watches_gifts (R$218,531),
bed_bath_table (R$193,268) — each figure is that category's top seller, not the
category total. Some categories are run by one dominant seller (agro_industry:
R$33.8k against R$8.4k for #2); others are close. Revenue and order count don't
always track — one health_beauty seller reaches similar revenue on 1,048 orders
as another on 166.

Two categories have no English translation (`pc_gamer`,
`portateis_cozinha_e_preparadores_de_alimentos`) and appear under their
Portuguese names. `unknown` is reserved for products carrying no category at
all, and is R$207k of revenue — worth knowing before treating it as a category.

## q4 — Late delivery by state

**8.11% → 6.77% nationally** after lateness was redefined as delivery on a later
calendar day than estimated. The old timestamp comparison counted an order
delivered at any time on the estimated day as late, which inflated every figure
here.

Still strongly regional, and the worst states are in the North/Northeast, far
from the São Paulo hub: Alagoas 21.4%, Maranhão 17.5%, Sergipe 15.1%, Piauí
13.9%, Ceará 13.7%. States near São Paulo are in single digits.

Read the small states carefully — Roraima shows 12.2% on 41 delivered orders,
which is five orders.

## q5 — RFM segmentation

Scored each customer 1–4 on Recency, Frequency and Monetary over non-cancelled
orders (snapshot = last order + 1 day). Frequency is a dead axis: 96.96% order
once, so three of the four F buckets are all single-order customers and the
score is just sort position. Segmentation effectively runs on Recency and
Monetary, which have real spread.

`customer_unique_id` breaks ties in every `NTILE`, so scores are reproducible
between runs — without it, tens of thousands of equal rows are split
arbitrarily.

## q6 — Review score vs delivery delay

| Bucket | Reviews | Avg score |
|---|---|---|
| Early | 88,658 | 4.29 |
| On the estimated day | 1,291 | 4.03 |
| 1–5 days late | 2,729 | 2.99 |
| More than 5 days late | 3,681 | 1.74 |

Lateness sharply lowers ratings, and the drop starts immediately: arriving on
the promised day already costs a quarter of a star against arriving early, and
more than five days late averages 1.74.

The middle bucket fell from 3.46 to 2.99 when lateness moved to calendar days —
same-day deliveries used to be counted as "1–5 days late" and were dragging that
average up.
