-- 05_checks.sql — read-only checks behind the claims in schema_notes.md and
-- decisions.md. Run after 03_build_facts_dims.sql. Each query should return
-- what its comment says.

-- 1. No orphans from facts to dims. Expect 0 in every column.
SELECT
    (SELECT count(*) FROM fact_orders WHERE customer_unique_id IS NULL)          AS orders_no_customer,
    (SELECT count(*) FROM fact_order_items i
       LEFT JOIN dim_products p ON i.product_id = p.product_id
      WHERE p.product_id IS NULL)                                                AS items_no_product,
    (SELECT count(*) FROM fact_order_items i
       LEFT JOIN dim_sellers s ON i.seller_id = s.seller_id
      WHERE s.seller_id IS NULL)                                                 AS items_no_seller,
    (SELECT count(*) FROM fact_reviews r
       LEFT JOIN fact_orders o ON r.order_id = o.order_id
      WHERE o.order_id IS NULL)                                                  AS reviews_no_order;

-- 2. fact_reviews has no unique single-column natural key, but (review_id,
--    order_id) is unique. Expect the two numbers to be equal.
SELECT count(*) AS rows, count(DISTINCT (review_id, order_id)) AS distinct_pairs
FROM order_reviews;

-- 3. Estimated delivery dates carry no time of day, which is why lateness is
--    compared by calendar day. Expect 0.
SELECT count(*) AS estimates_with_time_of_day
FROM orders
WHERE order_estimated_delivery_date::time <> '00:00:00';

-- 4. Zip prefixes kept their leading zeros. Expect 0.
SELECT count(*) AS bad_zip_prefixes
FROM dim_customers
WHERE length(customer_zip_code_prefix) <> 5;

-- 5. Both revenue bases reconcile to raw. Expect 0 and 0.
SELECT
    (SELECT SUM(payment_value) FROM order_payments)
  - (SELECT SUM(payment_total) FROM fact_orders)                                 AS payment_diff,
    (SELECT SUM(price + freight_value) FROM order_items)
  - (SELECT SUM(item_total_value) FROM fact_order_items)                         AS item_diff;

-- 6. Row counts: raw vs warehouse. Expect orders = fact_orders,
--    distinct people = dim_customers, items = fact_order_items,
--    reviews = fact_reviews.
SELECT
    (SELECT count(*) FROM orders)                              AS raw_orders,
    (SELECT count(*) FROM fact_orders)                         AS fact_orders,
    (SELECT count(DISTINCT customer_unique_id) FROM customers) AS raw_people,
    (SELECT count(*) FROM dim_customers)                       AS dim_customers,
    (SELECT count(*) FROM order_items)                         AS raw_items,
    (SELECT count(*) FROM fact_order_items)                    AS fact_order_items,
    (SELECT count(*) FROM order_reviews)                       AS raw_reviews,
    (SELECT count(*) FROM fact_reviews)                        AS fact_reviews;

-- 7. Categories with no English translation. q3 shows these by Portuguese name.
SELECT product_category_name, count(*) AS products
FROM dim_products
WHERE product_category_name IS NOT NULL
  AND product_category_name_english IS NULL
GROUP BY 1
ORDER BY 1;

-- 8. Orders per month outside q1's window, i.e. why it stops at 2018-08.
SELECT purchase_month, count(*) AS orders
FROM fact_orders
WHERE purchase_month < '2017-01-01' OR purchase_month > '2018-08-01'
GROUP BY 1
ORDER BY 1;

-- 9. What the Type 1 customer dimension costs: people with several customer_id
--    values, and how many of those ever shipped to a different state. The second
--    number bounds q4's misattribution (expect 2997 and 39).
SELECT
    count(*)                                                     AS people_with_many_ids,
    count(*) FILTER (WHERE states > 1)                           AS people_who_changed_state
FROM (
    SELECT customer_unique_id, count(DISTINCT customer_state) AS states
    FROM customers
    GROUP BY 1
    HAVING count(*) > 1
) t;
