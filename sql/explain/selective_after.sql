-- selective lookup AFTER index
DROP INDEX IF EXISTS idx_fo_order_status;
CREATE INDEX IF NOT EXISTS idx_fo_order_status ON fact_orders (order_status);

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_unique_id, payment_total
FROM fact_orders
WHERE order_status = 'canceled';


/*
Execution time: 8.200 ms -> 0.487 ms (~17x faster)

Index Scan using idx_fo_order_status on fact_orders  (cost=0.29..249.60 rows=570 width=72) (actual time=0.030..0.457 rows=625.00 loops=1)
  Index Cond: (order_status = 'canceled'::text)
  Index Searches: 1
  Buffers: shared hit=552 read=2
Planning:
  Buffers: shared hit=4 read=1
Planning Time: 0.823 ms
Execution Time: 0.487 ms
*/
