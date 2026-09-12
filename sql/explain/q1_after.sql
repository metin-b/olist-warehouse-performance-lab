-- q1 AFTER the index. The planner ignores it: the filter keeps 112,280 of
-- 112,650 rows, so a Seq Scan is cheaper than 112k random heap fetches.
CREATE INDEX IF NOT EXISTS idx_foi_purchase_month ON fact_order_items (purchase_month);

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
QUERY PLAN — captured 2026-09-12. Identical plan; the index is not used.

 WindowAgg  (cost=9813.01..9816.92 rows=22 width=100) (actual time=22.348..23.314 rows=20 loops=1)
   Buffers: shared hit=5891
   ->  WindowAgg  (cost=9813.01..9816.31 rows=22 width=68) (actual time=22.344..23.301 rows=20 loops=1)
         ->  Finalize GroupAggregate  (cost=9813.01..9815.98 rows=22 width=36) (actual time=22.340..23.294 rows=20 loops=1)
               Group Key: i.purchase_month
               ->  Gather Merge  (cost=9813.01..9815.54 rows=22 width=36) (actual time=22.337..23.283 rows=40 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     ->  Sort  (cost=8813.00..8813.06 rows=22 width=36) (actual time=21.493..21.494 rows=20 loops=2)
                           Sort Key: i.purchase_month
                           ->  Partial HashAggregate  (cost=8812.24..8812.51 rows=22 width=36) (actual time=21.479..21.481 rows=20 loops=2)
                                 Group Key: i.purchase_month
                                 Buffers: shared hit=5883
                                 ->  Parallel Hash Join  (cost=4273.93..8486.28 rows=65191 width=10) (actual time=7.793..18.141 rows=55876 loops=2)
                                       Hash Cond: (i.order_id = o.order_id)
                                       ->  Parallel Seq Scan on fact_order_items i  (cost=0.00..4038.97 rows=66044 width=43) (actual time=0.003..3.781 rows=56140 loops=2)
                                             Filter: ((purchase_month >= '2017-01-01'::date) AND (purchase_month <= '2018-08-01'::date))
                                             Rows Removed by Filter: 186
                                             Buffers: shared hit=3045
                                       ->  Parallel Hash  (cost=3552.18..3552.18 rows=57740 width=33) (actual time=7.722..7.722 rows=49104 loops=2)
                                             ->  Parallel Seq Scan on fact_orders o  (cost=0.00..3552.18 rows=57740 width=33) (actual time=0.003..4.656 rows=49104 loops=2)
                                                   Filter: (order_status <> ALL ('{canceled,unavailable}'::text[]))
                                                   Rows Removed by Filter: 617
                                                   Buffers: shared hit=2821
 Planning Time: 0.236 ms
 Execution Time: 23.337 ms

Same plan, same buffer counts (5,891 pages, all cache hits, no reads). The
execution-time difference is the second run finding everything warm, not the
index: the index appears nowhere in the plan.
*/
