-- q3 — Top 3 sellers by revenue within each product category.
-- Completed orders only; missing categories bucketed as 'unknown'.
WITH records AS (
    SELECT
        COALESCE(p.product_category_name_english, 'unknown') AS category,
        r.seller_id,
        SUM(r.item_total_value) AS total_sold
    FROM fact_order_items r
    JOIN dim_products p ON r.product_id = p.product_id
    JOIN fact_orders  o ON r.order_id  = o.order_id          -- for order_status
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
),
ranking AS (
    SELECT category, seller_id, total_sold,
           RANK() OVER (PARTITION BY category ORDER BY total_sold DESC) AS the_rank
    FROM records
)
SELECT category, seller_id, ROUND(total_sold, 2) AS total_sold, the_rank
FROM ranking
WHERE the_rank <= 3
ORDER BY category, the_rank;