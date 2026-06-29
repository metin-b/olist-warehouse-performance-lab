-- q4 — Late delivery rate by customer state (delivered orders only).
-- state lives on dim_customers, so join fact_orders -> dim_customers.
SELECT
    c.customer_state,
    ROUND(SUM(CASE WHEN o.is_delivered_late = 'true' THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2) AS late_pct        -- late orders / delivered orders
FROM fact_orders o
JOIN dim_customers c ON o.customer_unique_id = c.customer_unique_id
WHERE o.order_status = 'delivered'          -- only delivered orders can be late
GROUP BY 1
ORDER BY late_pct DESC;