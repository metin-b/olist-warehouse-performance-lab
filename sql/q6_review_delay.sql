-- q6 — Review score vs delivery delay.
-- Bucket delivered orders by how late they were, then average the review score.
SELECT
    CASE
        WHEN delivery_delay_days < 0  THEN '1_early'
        WHEN delivery_delay_days = 0  THEN '2_on_time'
        WHEN delivery_delay_days <= 5 THEN '3_late_1to5d'
        ELSE '4_late_5d_plus'
    END AS delay_bucket,
    COUNT(*)                  AS reviews,
    ROUND(AVG(review_score), 2) AS avg_score
FROM fact_reviews
WHERE delivery_delay_days IS NOT NULL   -- delivered orders only
GROUP BY 1
ORDER BY 1;