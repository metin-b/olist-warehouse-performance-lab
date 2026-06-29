DROP INDEX IF EXISTS idx_foi_purchase_month;

EXPLAIN (ANALYZE, BUFFERS)
WITH monthly AS (
    SELECT purchase_month, SUM(item_total_value) AS monthly_revenue
    FROM fact_order_items
    WHERE purchase_month >= '2017-01-01'
    GROUP BY purchase_month
)
SELECT purchase_month, monthly_revenue,
    ROUND(100.0*(monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY purchase_month))
          / LAG(monthly_revenue) OVER (ORDER BY purchase_month),2),
    ROUND(AVG(monthly_revenue) OVER (ORDER BY purchase_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2)
FROM monthly ORDER BY purchase_month;

/*
				QUERY PLAN (Example)
WindowAgg  (cost=5015.32..5016.26 rows=22 width=100) (actual time=20.718..20.748 rows=21.00 loops=1)
  Window: w2 AS (ORDER BY fact_order_items.purchase_month ROWS BETWEEN '2'::bigint PRECEDING AND CURRENT ROW)
  Storage: Memory  Maximum Storage: 17kB
  Buffers: shared hit=3045
  ->  WindowAgg  (cost=5015.29..5015.66 rows=22 width=68) (actual time=20.705..20.713 rows=21.00 loops=1)
        Window: w1 AS (ORDER BY fact_order_items.purchase_month)
        Storage: Memory  Maximum Storage: 17kB
        Buffers: shared hit=3045
        ->  Sort  (cost=5015.27..5015.33 rows=22 width=36) (actual time=20.694..20.695 rows=21.00 loops=1)
              Sort Key: fact_order_items.purchase_month
              Sort Method: quicksort  Memory: 25kB
              Buffers: shared hit=3045
              ->  HashAggregate  (cost=5014.50..5014.78 rows=22 width=36) (actual time=20.683..20.686 rows=21.00 loops=1)
                    Group Key: fact_order_items.purchase_month
                    Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=3045
                    ->  Seq Scan on fact_order_items  (cost=0.00..4453.12 rows=112276 width=10) (actual time=0.007..10.571 rows=112280.00 loops=1)
                          Filter: (purchase_month >= '2017-01-01'::date)
                          Rows Removed by Filter: 370
                          Buffers: shared hit=3045
Planning:
  Buffers: shared hit=7
Planning Time: 0.369 ms
Execution Time: 20.786 ms
*/