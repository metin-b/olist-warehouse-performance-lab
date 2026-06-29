-- q1 — Monthly revenue with MoM % change and 3-month moving average.
-- Revenue = item_total_value; scoped to 2017-01+ (earlier = pre-launch noise).
WITH monthly AS (
    SELECT purchase_month, SUM(item_total_value) AS monthly_revenue
    FROM fact_order_items
    WHERE purchase_month >= '2017-01-01'
    GROUP BY purchase_month
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