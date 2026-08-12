-- q2 — Cohort retention: % of each monthly cohort still ordering N months later.
-- Cohort = first purchase month; month 0 is 100% by definition. ~97% buy once.
WITH customer_cohort AS (
    SELECT customer_unique_id,
           MIN(purchase_month) cohort_month
    FROM fact_orders
    GROUP BY customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
),
activity AS (
    SELECT DISTINCT
        c.cohort_month,
        o.customer_unique_id,
        (EXTRACT(YEAR FROM o.purchase_month)*12 + EXTRACT(MONTH FROM o.purchase_month))
      - (EXTRACT(YEAR FROM c.cohort_month)*12   + EXTRACT(MONTH FROM c.cohort_month)) month_number
    FROM fact_orders o
    JOIN customer_cohort c USING (customer_unique_id)
)
SELECT
    a.cohort_month,
    s.cohort_size,
    a.month_number,
    COUNT(*) retained_customers,
    ROUND(100.0 * COUNT(*) / s.cohort_size, 2) retention_pct
FROM activity a
JOIN cohort_size s USING (cohort_month)
GROUP BY a.cohort_month, s.cohort_size, a.month_number
ORDER BY a.cohort_month, a.month_number;