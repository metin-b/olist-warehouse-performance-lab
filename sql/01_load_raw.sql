-- ================================================================
-- OLIST — LOAD RAW CSVs PostgreSQL / psql
-- ================================================================

SET client_encoding = 'UTF8';

TRUNCATE TABLE
    customers,
    geolocation,
    sellers,
    products,
    orders,
    order_items,
    order_payments,
    order_reviews,
    product_category_translation;

\copy customers FROM 'data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy geolocation FROM 'data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy sellers FROM 'data/raw/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy products FROM 'data/raw/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy orders FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy order_items FROM 'data/raw/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy order_payments FROM 'data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy order_reviews FROM 'data/raw/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy product_category_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, NULL '');