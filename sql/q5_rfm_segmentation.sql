-- q5 — RFM segmentation. Score each customer 1-4 on Recency, Frequency, Monetary.
-- Snapshot = last order date + 1 (data ends 2018, so "now" is in-dataset).
-- Note: ~97% order once, so the F score barely separates customers.
WITH records AS (
    SELECT customer_unique_id,
           MAX(purchase_date)              AS last_order,
           COUNT(*)                        AS total_orders,
           COALESCE(SUM(payment_total), 0) AS total_payment   -- NULL spend -> 0 (scores low)
    FROM fact_orders
    GROUP BY 1
),
anchor AS (SELECT MAX(purchase_date) + 1 AS snapshot FROM fact_orders),
r2 AS (
    SELECT customer_unique_id, total_orders, total_payment,
           (SELECT snapshot FROM anchor) - last_order AS recency_days
    FROM records
)
SELECT customer_unique_id, recency_days, total_orders, total_payment,
       NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,  -- recent = 4
       NTILE(4) OVER (ORDER BY total_orders ASC)  AS f_score,
       NTILE(4) OVER (ORDER BY total_payment ASC) AS m_score
FROM r2
ORDER BY total_payment DESC;