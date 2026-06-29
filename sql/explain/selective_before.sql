-- selective lookup BEFORE index
DROP INDEX IF EXISTS idx_fo_order_status;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_unique_id, payment_total FROM fact_orders WHERE order_status='canceled';


/*
			QUERY PLAN (example)
Seq Scan on fact_orders  (cost=0.00..4064.01 rows=570 width=72) (actual time=0.028..8.170 rows=625.00 loops=1)
  Filter: (order_status = 'canceled'::text)
  Rows Removed by Filter: 98816
  Buffers: shared hit=2821
Planning Time: 0.087 ms
Execution Time: 8.200 ms
*/
