-- q1 — Monthly revenue with MoM % change and 3-month moving average.
-- Revenue = item_total_value, excluding canceled/unavailable orders (the rule in
-- schema_notes.md; q3 applies it too).
-- Window is 2017-01 .. 2018-08. Before that is pre-launch noise (4 orders in
-- 2016-09, 1 in 2016-12); after it the data thins out to 16 orders in 2018-09
-- and 4 in 2018-10, which would render as a revenue collapse.
WITH monthly AS (
    SELECT i.purchase_month, SUM(i.item_total_value) AS monthly_revenue
    FROM fact_order_items i
    JOIN fact_orders o ON i.order_id = o.order_id
    WHERE i.purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY i.purchase_month
)
SELECT
    purchase_month,
    monthly_revenue,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY purchase_month))
                / LAG(monthly_revenue) OVER (ORDER BY purchase_month), 2) AS mom_change_pct,
    ROUND(AVG(monthly_revenue) OVER (ORDER BY purchase_month
                                     ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3mo
FROM monthly
ORDER BY purchase_month;
