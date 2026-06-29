-- 04_indexes.sql — indexes tested against the EXPLAIN plans (see optimization.md).
-- NOTE: q1 is a full-table aggregation, so the planner ignores its index.
-- The one that actually gets used is idx_fo_order_status, on a selective filter.

-- q1: filter on purchase_month (planner still prefers a Seq Scan — kept for the test).
CREATE INDEX IF NOT EXISTS idx_foi_purchase_month
    ON fact_order_items (purchase_month);

-- Selective lookups: this one IS used — order_status='canceled' hits 0.6% of rows,
-- so the plan flips Seq Scan -> Index Scan.
CREATE INDEX IF NOT EXISTS idx_fo_order_status
    ON fact_orders (order_status);