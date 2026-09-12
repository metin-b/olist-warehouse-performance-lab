-- Selective lookup AFTER the index. Plan flips to an Index Scan.
DROP INDEX IF EXISTS idx_fo_order_status;
CREATE INDEX idx_fo_order_status ON fact_orders (order_status);

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_unique_id, payment_total
FROM fact_orders
WHERE order_status = 'canceled';

/*
QUERY PLAN — captured 2026-09-12

 Index Scan using idx_fo_order_status on fact_orders  (cost=0.29..309.21 rows=653 width=72) (actual time=0.009..0.230 rows=625 loops=1)
   Index Cond: (order_status = 'canceled'::text)
   Buffers: shared hit=552 read=2
 Planning Time: 0.071 ms
 Execution Time: 0.245 ms

5.008 ms -> 0.245 ms, about 20x, and the buffer counts say why: 554 pages
touched instead of 2,821, and no filter evaluated against the 98,816
non-matching rows.

554 is close to what scattered rows predict: 625 matches spread over 2,821
pages should touch 2821 * (1 - (1 - 1/2821)^625) = ~561 distinct pages. Rows
sharing a page are not clustered together, so the index is doing random
fetches, not a compact range read.
*/
