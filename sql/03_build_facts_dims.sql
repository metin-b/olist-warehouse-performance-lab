-- ================================================================
-- OLIST — BUILD FACTS & DIMENSIONS  (Phase 6)
-- Populate the star-schema warehouse from the raw layer.
--
-- Key modeling decisions:
--   * Customer identity uses customer_unique_id (the person), NOT
--     customer_id (which is regenerated per order). dim_customers
--     is keyed on customer_unique_id
--   * Derived measures (delivery_days, is_delivered_late,
--     payment_total, item_total_value, purchase_month) are
--     pre-computed here so the analytical queries stay simple.
--   * Misspelled raw columns (product_*_lenght) are corrected to
--     *_length in dim_products.
--   * Lateness is compared by calendar day. order_estimated_delivery_date
--     has no time of day (verified: 0 rows with a non-midnight time), so a
--     timestamp comparison would count a delivery on the estimated day as
--     late. The delay columns are therefore whole days.
-- ================================================================

BEGIN;

-- clear warehouse tables (facts first, then dims).
TRUNCATE fact_reviews, fact_order_items, fact_orders,
         dim_customers, dim_products, dim_sellers
RESTART IDENTITY;

-- ----------------------------------------------------------------
-- DIM: customers  (one row per real person = customer_unique_id)
-- A customer_unique_id can appear under many customer_id values
-- (one per order).
-- ----------------------------------------------------------------
INSERT INTO dim_customers (
    customer_unique_id,
    customer_zip_code_prefix, customer_city, customer_state
)
SELECT DISTINCT ON (customer_unique_id)
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM customers
ORDER BY customer_unique_id, customer_id;

-- ----------------------------------------------------------------
-- DIM: products  (+ English category, corrected *_length columns)
-- LEFT JOIN keeps products whose category is NULL or untranslated.
-- ----------------------------------------------------------------
INSERT INTO dim_products (
    product_id, product_category_name, product_category_name_english,
    product_name_length, product_description_length, product_photos_qty,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
SELECT
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM products p
LEFT JOIN product_category_translation t
       ON p.product_category_name = t.product_category_name;

-- ----------------------------------------------------------------
-- DIM: sellers
-- ----------------------------------------------------------------
INSERT INTO dim_sellers (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
)
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM sellers;

-- ----------------------------------------------------------------
-- FACT: orders  (one row per order)
-- Resolves customer_unique_id; pre-computes delivery + payment
-- late_delivery_days = delivered date - estimated date, in whole days.
-- ----------------------------------------------------------------
INSERT INTO fact_orders (
    order_id, customer_id, customer_unique_id, order_status,
    order_purchase_timestamp, purchase_date, purchase_month,
    order_approved_at, order_delivered_carrier_date,
    order_delivered_customer_date, order_estimated_delivery_date,
    delivery_days, estimated_delivery_days, late_delivery_days, is_delivered_late,
    payment_total, payment_count, max_payment_installments
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date                              AS purchase_date,
    date_trunc('month', o.order_purchase_timestamp)::date         AS purchase_month,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0, 2)     AS delivery_days,
    ROUND(EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400.0, 2)     AS estimated_delivery_days,
    (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date)                             AS late_delivery_days,
    (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)                             AS is_delivered_late,
    pay.payment_total,
    pay.payment_count,
    pay.max_payment_installments
FROM orders o
LEFT JOIN customers c
       ON o.customer_id = c.customer_id
LEFT JOIN (
    SELECT
        order_id,
        SUM(payment_value)        AS payment_total,
        COUNT(*)                  AS payment_count,
        MAX(payment_installments) AS max_payment_installments
    FROM order_payments
    GROUP BY order_id
) pay ON o.order_id = pay.order_id;

-- ----------------------------------------------------------------
-- FACT: order_items  (one row per line item)
-- Carries purchase date + customer identity down to item grain so
-- revenue queries never need to re-join orders/customers.
-- ----------------------------------------------------------------
INSERT INTO fact_order_items (
    order_id, order_item_id, product_id, seller_id, customer_unique_id,
    order_purchase_timestamp, purchase_date, purchase_month,
    shipping_limit_date, price, freight_value, item_total_value
)
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    c.customer_unique_id,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date                      AS purchase_date,
    date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    (oi.price + oi.freight_value)                         AS item_total_value
FROM order_items oi
JOIN orders o         ON oi.order_id = o.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id;

-- ----------------------------------------------------------------
-- FACT: reviews  (one row per review; surrogate key review_sk)
-- delivery_delay_days = delivered date - estimated date, in whole days
-- (negative = early, 0 = on the estimated day, positive = late).
-- ----------------------------------------------------------------
INSERT INTO fact_reviews (
    review_id, order_id, customer_unique_id,
    review_score, review_comment_title, review_comment_message,
    review_creation_date, review_answer_timestamp,
    order_purchase_timestamp, order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_delay_days, is_delivered_late
)
SELECT
    r.review_id,
    r.order_id,
    c.customer_unique_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date)                             AS delivery_delay_days,
    (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)                             AS is_delivered_late
FROM order_reviews r
JOIN orders o         ON r.order_id = o.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id;

COMMIT;