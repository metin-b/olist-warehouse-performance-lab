-- q1 BEFORE the index. Run from the repo root.
DROP INDEX IF EXISTS idx_foi_purchase_month;

EXPLAIN (ANALYZE, BUFFERS)
WITH monthly AS (
    SELECT i.purchase_month, SUM(i.item_total_value) AS monthly_revenue
    FROM fact_order_items i
    JOIN fact_orders o ON i.order_id = o.order_id
    WHERE i.purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY i.purchase_month
)
SELECT purchase_month, monthly_revenue,
    ROUND(100.0*(monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY purchase_month))
          / LAG(monthly_revenue) OVER (ORDER BY purchase_month),2),
    ROUND(AVG(monthly_revenue) OVER (ORDER BY purchase_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2)
FROM monthly ORDER BY purchase_month;

/*
QUERY PLAN — captured 2026-09-12

 WindowAgg  (cost=9813.01..9816.92 rows=22 width=100) (actual time=49.911..51.151 rows=20 loops=1)
   Buffers: shared hit=5891
   ->  WindowAgg  (cost=9813.01..9816.31 rows=22 width=68) (actual time=49.899..51.124 rows=20 loops=1)
         ->  Finalize GroupAggregate  (cost=9813.01..9815.98 rows=22 width=36) (actual time=49.891..51.110 rows=20 loops=1)
               Group Key: i.purchase_month
               ->  Gather Merge  (cost=9813.01..9815.54 rows=22 width=36) (actual time=49.885..51.090 rows=40 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     ->  Sort  (cost=8813.00..8813.06 rows=22 width=36) (actual time=47.204..47.205 rows=20 loops=2)
                           Sort Key: i.purchase_month
                           Sort Method: quicksort  Memory: 26kB
                           ->  Partial HashAggregate  (cost=8812.24..8812.51 rows=22 width=36) (actual time=47.168..47.172 rows=20 loops=2)
                                 Group Key: i.purchase_month
                                 Buffers: shared hit=5883
                                 ->  Parallel Hash Join  (cost=4273.93..8486.28 rows=65191 width=10) (actual time=20.679..40.807 rows=55876 loops=2)
                                       Hash Cond: (i.order_id = o.order_id)
                                       ->  Parallel Seq Scan on fact_order_items i  (cost=0.00..4038.97 rows=66044 width=43) (actual time=0.009..7.666 rows=56140 loops=2)
                                             Filter: ((purchase_month >= '2017-01-01'::date) AND (purchase_month <= '2018-08-01'::date))
                                             Rows Removed by Filter: 186
                                             Buffers: shared hit=3045
                                       ->  Parallel Hash  (cost=3552.18..3552.18 rows=57740 width=33) (actual time=20.497..20.497 rows=49104 loops=2)
                                             Buckets: 131072  Batches: 1  Memory Usage: 7968kB
                                             ->  Parallel Seq Scan on fact_orders o  (cost=0.00..3552.18 rows=57740 width=33) (actual time=0.013..11.667 rows=49104 loops=2)
                                                   Filter: (order_status <> ALL ('{canceled,unavailable}'::text[]))
                                                   Rows Removed by Filter: 617
                                                   Buffers: shared hit=2821
 Planning Time: 1.766 ms
 Execution Time: 51.286 ms
*/
