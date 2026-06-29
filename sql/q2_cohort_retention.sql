-- q2 — Cohort retention: share of customers who return one month after their first purchase.
-- Cohort = first purchase month; month_number = months since. ~0.5% (97% buy once).
WITH first_order AS (
    SELECT customer_unique_id, purchase_month,
           MIN(purchase_month) OVER (PARTITION BY customer_unique_id) AS cohort_month
    FROM fact_orders
),
cohort AS (
    SELECT DISTINCT customer_unique_id,
        (EXTRACT(YEAR FROM purchase_month)*12 + EXTRACT(MONTH FROM purchase_month))
      - (EXTRACT(YEAR FROM cohort_month)*12   + EXTRACT(MONTH FROM cohort_month)) AS month_number
    FROM first_order
)
SELECT ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE month_number = 1)
                   / COUNT(DISTINCT customer_unique_id), 2) AS blended_m1_retention_pct
FROM cohort;