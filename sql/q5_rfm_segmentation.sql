-- q5 — RFM segmentation. Score each customer 1-4 on Recency, Frequency, Monetary.
-- Excludes canceled/unavailable orders, matching q1 and q3 (schema_notes.md).
-- Snapshot = last order date + 1 (data ends 2018, so "now" is in-dataset).
-- customer_unique_id breaks ties in every NTILE: ~97% of customers have exactly
-- one order, so without a tiebreaker the F score is assigned arbitrarily among
-- tens of thousands of equal rows and changes between runs.
WITH valid_orders AS (
    SELECT customer_unique_id, purchase_date, payment_total
    FROM fact_orders
    WHERE order_status NOT IN ('canceled', 'unavailable')
),
records AS (
    SELECT customer_unique_id,
           MAX(purchase_date)              AS last_order,
           COUNT(*)                        AS total_orders,
           COALESCE(SUM(payment_total), 0) AS total_payment   -- NULL spend -> 0 (scores low)
    FROM valid_orders
    GROUP BY 1
),
anchor AS (SELECT MAX(purchase_date) + 1 AS snapshot FROM valid_orders),
r2 AS (
    SELECT customer_unique_id, total_orders, total_payment,
           (SELECT snapshot FROM anchor) - last_order AS recency_days
    FROM records
)
SELECT customer_unique_id, recency_days, total_orders, total_payment,
       NTILE(4) OVER (ORDER BY recency_days DESC, customer_unique_id) AS r_score,  -- recent = 4
       NTILE(4) OVER (ORDER BY total_orders ASC,  customer_unique_id) AS f_score,
       NTILE(4) OVER (ORDER BY total_payment ASC, customer_unique_id) AS m_score
FROM r2
ORDER BY total_payment DESC;
