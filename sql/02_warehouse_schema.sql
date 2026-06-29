-- ================================================================
-- OLIST — WAREHOUSE SCHEMA
-- Star-style warehouse
-- ================================================================

DROP TABLE IF EXISTS fact_reviews;
DROP TABLE IF EXISTS fact_order_items;
DROP TABLE IF EXISTS fact_orders;

DROP TABLE IF EXISTS dim_customers;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_sellers;

-- ================================================================
-- DIMENSIONS
-- ================================================================

CREATE TABLE dim_customers (
    customer_unique_id       TEXT PRIMARY KEY,
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           TEXT
);

CREATE TABLE dim_products (
    product_id                    TEXT PRIMARY KEY,
    product_category_name         TEXT,
    product_category_name_english TEXT,
    product_name_length           INTEGER,
    product_description_length    INTEGER,
    product_photos_qty            INTEGER,
    product_weight_g              INTEGER,
    product_length_cm             INTEGER,
    product_height_cm             INTEGER,
    product_width_cm              INTEGER
);

CREATE TABLE dim_sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

-- ================================================================
-- FACTS
-- ================================================================

CREATE TABLE fact_orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT,
    customer_unique_id            TEXT,
    order_status                  TEXT,

    order_purchase_timestamp      TIMESTAMP,
    purchase_date                 DATE,
    purchase_month                DATE,

    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,

    delivery_days                 NUMERIC,
    estimated_delivery_days       NUMERIC,
    late_delivery_days            NUMERIC,
    is_delivered_late             BOOLEAN,

    payment_total                 NUMERIC,
    payment_count                 INTEGER,
    max_payment_installments      INTEGER
);

CREATE TABLE fact_order_items (
    order_id                 TEXT,
    order_item_id            INTEGER,
    product_id               TEXT,
    seller_id                TEXT,
    customer_unique_id       TEXT,

    order_purchase_timestamp TIMESTAMP,
    purchase_date            DATE,
    purchase_month           DATE,

    shipping_limit_date      TIMESTAMP,
    price                    NUMERIC,
    freight_value            NUMERIC,
    item_total_value         NUMERIC,

    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE fact_reviews (
    review_sk                     BIGSERIAL PRIMARY KEY,
    review_id                     TEXT,
    order_id                      TEXT,
    customer_unique_id            TEXT,

    review_score                  INTEGER,
    review_comment_title          TEXT,
    review_comment_message        TEXT,
    review_creation_date          TIMESTAMP,
    review_answer_timestamp       TIMESTAMP,

    order_purchase_timestamp      TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,

    delivery_delay_days           NUMERIC,
    is_delivered_late             BOOLEAN
);