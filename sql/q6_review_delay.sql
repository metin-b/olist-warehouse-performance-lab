-- q6 — Review score vs delivery delay.
-- delivery_delay_days is whole days between the estimated and actual delivery
-- date, so 0 means delivered on the estimated day (see 03_build_facts_dims.sql).
-- Counts reviews, not orders: an order can carry more than one review.
SELECT
    CASE
        WHEN delivery_delay_days < 0  THEN '1_early'
        WHEN delivery_delay_days = 0  THEN '2_on_estimated_day'
        WHEN delivery_delay_days <= 5 THEN '3_late_1to5d'
        ELSE '4_late_over_5d'
    END AS delay_bucket,
    COUNT(*)                    AS reviews,
    ROUND(AVG(review_score), 2) AS avg_score
FROM fact_reviews
WHERE delivery_delay_days IS NOT NULL   -- delivered orders only
GROUP BY 1
ORDER BY 1;
