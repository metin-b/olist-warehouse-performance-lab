-- Selective lookup BEFORE the index: 625 of 99,441 rows = 0.6%.
DROP INDEX IF EXISTS idx_fo_order_status;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_unique_id, payment_total
FROM fact_orders
WHERE order_status = 'canceled';

/*
QUERY PLAN — captured 2026-09-12

 Seq Scan on fact_orders  (cost=0.00..4064.01 rows=653 width=72) (actual time=0.007..4.995 rows=625 loops=1)
   Filter: (order_status = 'canceled'::text)
   Rows Removed by Filter: 98816
   Buffers: shared hit=2821
 Planning Time: 0.068 ms
 Execution Time: 5.008 ms

The cost is reproducible from the planner's constants:
  2821 pages x 1.0 (seq_page_cost)
+ 99441 rows  x 0.01   (cpu_tuple_cost)
+ 99441 rows  x 0.0025 (cpu_operator_cost, one filter comparison)
= 4064.0
*/
