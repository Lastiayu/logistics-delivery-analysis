-- =============================================================================
-- 01_data_exploration.sql
-- Data exploration queries for the delivery performance analysis (SQLite).
--
-- Labels (L1, L2, ...) match the row numbers in data_notes/exploration_log.md.
-- Labels starting with T relate to the minimum sample size and reporting
-- thresholds in docs/business_questions_and_kpis.md.
--
-- Before running:
--   1. Import the CSV files into SQLite (one table per file).
--   2. Run sql/00_setup_indexes.sql and sql/00_setup_translations.sql.
--
-- Run one query at a time. Results noted in "Result" comments were recorded
-- when the analysis was done and can be used to check a re-run.
-- =============================================================================


-- =============================================================================
-- SECTION A: TABLE INVENTORY
-- =============================================================================

-- A1: Row count per table
-- Result: orders 99,441 | customers 99,441 | order_items 112,650 |
--         order_reviews 99,224 | products 32,951 | sellers 3,095 |
--         product_category_translation 73
SELECT 'orders' AS table_name, COUNT(*) AS n FROM orders
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;

-- A2: Column list per table (repeat for each table)
PRAGMA table_info(orders);


-- =============================================================================
-- SECTION B: KEYS, DUPLICATES, AND DATA TYPES
-- =============================================================================

-- L1: Total orders
-- Result: 99,441
SELECT COUNT(*) AS total_orders FROM orders;

-- L2: Duplicate order_id
-- Result: 99,441 rows, 99,441 distinct order_id
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_order_id
FROM orders;

-- L9: Key of order_items (order_id + order_item_id)
-- Result: 112,650 rows, 112,650 distinct keys
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id || '-' || order_item_id) AS distinct_keys
FROM order_items;

-- L15: Uniqueness of review_id
-- Result: 99,224 rows, 98,410 distinct review_id, 98,673 distinct order_id
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT review_id) AS distinct_review_id,
       COUNT(DISTINCT order_id) AS distinct_order_id
FROM order_reviews;

-- L21: customer_id vs customer_unique_id
-- Result: 99,441 rows, 99,441 distinct customer_id, 96,096 distinct customer_unique_id
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS distinct_customer_id,
       COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_id
FROM customers;

-- L13: Stored data types of numeric columns
-- Result: price and freight_value are REAL; review_score is INTEGER
SELECT 'order_items.price' AS column_name, typeof(price) AS data_type, COUNT(*) AS n
FROM order_items GROUP BY typeof(price)
UNION ALL
SELECT 'order_items.freight_value', typeof(freight_value), COUNT(*)
FROM order_items GROUP BY typeof(freight_value)
UNION ALL
SELECT 'order_reviews.review_score', typeof(review_score), COUNT(*)
FROM order_reviews GROUP BY typeof(review_score);


-- =============================================================================
-- SECTION C: ORDER STATUS, DATES, AND DELIVERY TIMES
-- =============================================================================

-- L3: Orders by status
-- Result: delivered 96,478 | shipped 1,107 | canceled 625 | unavailable 609 |
--         invoiced 314 | processing 301 | created 5 | approved 2
SELECT order_status, COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- L4: Delivered orders without a delivery date
-- Result: 8
SELECT COUNT(*) AS delivered_without_date
FROM orders
WHERE order_status = 'delivered'
  AND TRIM(COALESCE(order_delivered_customer_date, '')) = '';

-- L26: Orders that have a delivery date, by status
-- Result: delivered 96,470 | canceled 6
SELECT order_status, COUNT(*) AS orders_with_delivery_date
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
GROUP BY order_status
ORDER BY orders_with_delivery_date DESC;

-- T0: Orders included in the analysis
-- Result: total 99,441 | status delivered 96,478 |
--         delivered with date 96,470 | delivered without date 8
SELECT COUNT(*) AS total_orders,
       SUM(order_status = 'delivered') AS status_delivered,
       SUM(order_status = 'delivered'
           AND TRIM(COALESCE(order_delivered_customer_date, '')) <> '') AS delivered_with_date,
       SUM(order_status = 'delivered'
           AND TRIM(COALESCE(order_delivered_customer_date, '')) = '') AS delivered_without_date
FROM orders;

-- L5: Time of day of estimated delivery dates
-- Result: 0 exceptions (all estimated dates are at 00:00:00)
SELECT COUNT(*) AS total_orders,
       SUM(strftime('%H:%M:%S', order_estimated_delivery_date) <> '00:00:00') AS non_midnight
FROM orders;

-- L6: Delivery days (calendar dates, purchase to delivery)
-- Result: n 96,470 | min 0 | max 210 | average 12.5 | negative 0 | over 60 days 298
WITH d AS (
  SELECT julianday(date(order_delivered_customer_date))
         - julianday(date(order_purchase_timestamp)) AS delivery_days
  FROM orders
  WHERE order_status = 'delivered'
    AND TRIM(COALESCE(order_delivered_customer_date, '')) <> ''
)
SELECT COUNT(*) AS n,
       MIN(delivery_days) AS min_days,
       MAX(delivery_days) AS max_days,
       ROUND(AVG(delivery_days), 2) AS avg_days,
       SUM(delivery_days < 0) AS negative_days,
       SUM(delivery_days > 60) AS over_60_days
FROM d;

-- L7: Invalid date formats (date() returns NULL when the text cannot be parsed)
-- Result: 0 in all three columns
SELECT
  SUM(TRIM(COALESCE(order_purchase_timestamp, '')) <> ''
      AND date(order_purchase_timestamp) IS NULL) AS bad_purchase,
  SUM(TRIM(COALESCE(order_estimated_delivery_date, '')) <> ''
      AND date(order_estimated_delivery_date) IS NULL) AS bad_estimated,
  SUM(TRIM(COALESCE(order_delivered_customer_date, '')) <> ''
      AND date(order_delivered_customer_date) IS NULL) AS bad_delivered
FROM orders;

-- L8: Order of events (purchase, approval, carrier, customer) for delivered orders
-- Result: orders checked 96,455 | approved before purchase 0 |
--         carrier before approval 1,350 | delivered before carrier 23 |
--         delivered before purchase 0
SELECT COUNT(*) AS orders_checked,
       SUM(order_approved_at < order_purchase_timestamp) AS approved_before_purchase,
       SUM(order_delivered_carrier_date < order_approved_at) AS carrier_before_approved,
       SUM(order_delivered_customer_date < order_delivered_carrier_date) AS delivered_before_carrier,
       SUM(order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase
FROM orders
WHERE order_status = 'delivered'
  AND TRIM(COALESCE(order_approved_at, '')) <> ''
  AND TRIM(COALESCE(order_delivered_carrier_date, '')) <> ''
  AND TRIM(COALESCE(order_delivered_customer_date, '')) <> '';

-- T1: Overall late delivery rate (late = delivered date after estimated date,
--     comparing calendar dates only)
-- Result: 96,470 orders | 6,534 late | 6.77%
SELECT COUNT(*) AS delivered_with_date,
       SUM(date(order_delivered_customer_date) > date(order_estimated_delivery_date)) AS late_orders,
       ROUND(100.0 * SUM(date(order_delivered_customer_date) > date(order_estimated_delivery_date))
             / COUNT(*), 2) AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND TRIM(COALESCE(order_delivered_customer_date, '')) <> '';

-- T2: Sensitivity check for L8: late rate excluding the 23 orders whose
--     delivered date is before the carrier date
-- Result: 6.77% (same as T1)
SELECT ROUND(100.0 * SUM(date(order_delivered_customer_date) > date(order_estimated_delivery_date))
             / COUNT(*), 2) AS late_pct_excluding_23
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND NOT (order_delivered_carrier_date IS NOT NULL
           AND order_delivered_customer_date < order_delivered_carrier_date);


-- =============================================================================
-- SECTION D: ORDER ITEMS, SELLERS, AND PRODUCT CATEGORIES
-- =============================================================================

-- L10: Delivered orders with more than one seller
-- Result: 1,275 (about 1.32% of 96,478 delivered orders)
SELECT COUNT(*) AS multi_seller_delivered_orders
FROM (
  SELECT oi.order_id
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY oi.order_id
  HAVING COUNT(DISTINCT oi.seller_id) > 1
);

-- L11: Delivered orders with more than one product category
-- Result: 723 (about 0.75% of 96,478 delivered orders)
SELECT COUNT(*) AS multi_category_delivered_orders
FROM (
  SELECT oi.order_id
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN products p ON oi.product_id = p.product_id
  WHERE o.order_status = 'delivered'
  GROUP BY oi.order_id
  HAVING COUNT(DISTINCT p.product_category_name) > 1
);

-- L12: Price and freight ranges
-- Result: price 0.85 to 6,735.00 (average 120.65), no zero or negative prices |
--         freight 0.00 to 409.68, 383 items with zero freight
SELECT MIN(CAST(price AS REAL)) AS min_price,
       MAX(CAST(price AS REAL)) AS max_price,
       ROUND(AVG(CAST(price AS REAL)), 2) AS avg_price,
       SUM(CAST(price AS REAL) <= 0) AS zero_or_negative_price,
       MIN(CAST(freight_value AS REAL)) AS min_freight,
       MAX(CAST(freight_value AS REAL)) AS max_freight,
       SUM(CAST(freight_value AS REAL) = 0) AS zero_freight
FROM order_items;

-- L14: Delivered orders without any item
-- Result: 0
SELECT COUNT(*) AS delivered_orders_without_items
FROM orders o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id);

-- L19a: Delivered orders with at least one product without a category name
-- Result: 1,392 (about 1.4%)
SELECT COUNT(DISTINCT o.order_id) AS delivered_orders_uncategorized
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
  AND TRIM(COALESCE(p.product_category_name, '')) = '';

-- L19b: NULL vs empty category in the products table
-- Result: 610 NULL, 0 empty, 32,951 products
SELECT SUM(product_category_name IS NULL) AS null_category,
       SUM(TRIM(COALESCE(product_category_name, '')) = ''
           AND product_category_name IS NOT NULL) AS empty_category,
       COUNT(*) AS total_products
FROM products;

-- L19c: Products missing all four attributes (category, name length,
--       description length, photo count)
-- Result: 610 (the same products are missing all four)
SELECT COUNT(*) AS products_missing_all_four
FROM products
WHERE product_category_name IS NULL
  AND product_name_lenght IS NULL
  AND product_description_lenght IS NULL
  AND product_photos_qty IS NULL;

-- L20a: Categories without an English translation (after the manual fix)
-- Result: no rows. Before the fix, two categories were returned:
--         pc_gamer and portateis_cozinha_e_preparadores_de_alimentos
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_translation t
  ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND TRIM(COALESCE(p.product_category_name, '')) <> '';

-- L20b: Translation table has no duplicate category names
-- Result: 73 rows, 73 distinct names
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_category_name) AS distinct_names
FROM product_category_translation;


-- =============================================================================
-- SECTION E: REVIEWS
-- =============================================================================

-- L16: Number of reviews per delivered order (orders with at least one review)
-- Result: 1 review 95,307 orders | 2 reviews 521 | 3 reviews 4
SELECT n_reviews, COUNT(*) AS orders
FROM (
  SELECT o.order_id, COUNT(*) AS n_reviews
  FROM orders o
  JOIN order_reviews r ON r.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY o.order_id
)
GROUP BY n_reviews
ORDER BY n_reviews;

-- L16b: Delivered orders with more than one review
-- Result: 525 (521 + 4)
SELECT COUNT(*) AS delivered_orders_with_multiple_reviews
FROM (
  SELECT o.order_id
  FROM orders o
  JOIN order_reviews r ON r.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY o.order_id
  HAVING COUNT(*) > 1
);

-- L17: Delivered orders without a review
-- Result: 646 (about 0.67%)
SELECT COUNT(*) AS delivered_without_review
FROM orders o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM order_reviews r WHERE r.order_id = o.order_id);

-- L18: Review score values
-- Result: 1 = 11,424 | 2 = 3,151 | 3 = 8,179 | 4 = 19,142 | 5 = 57,328
--         (total 99,224)
SELECT review_score, COUNT(*) AS reviews
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- =============================================================================
-- SECTION F: CUSTOMERS, SELLERS, AND REFERENTIAL INTEGRITY
-- =============================================================================

-- L22: State codes in customers and sellers
-- Result: customers 27 distinct states | sellers 23 distinct states |
--         all codes are two uppercase letters
SELECT 'customers' AS tbl,
       COUNT(DISTINCT customer_state) AS distinct_states,
       MIN(LENGTH(customer_state)) AS min_len,
       MAX(LENGTH(customer_state)) AS max_len,
       SUM(customer_state <> UPPER(customer_state)) AS not_uppercase
FROM customers
UNION ALL
SELECT 'sellers',
       COUNT(DISTINCT seller_state),
       MIN(LENGTH(seller_state)),
       MAX(LENGTH(seller_state)),
       SUM(seller_state <> UPPER(seller_state))
FROM sellers;

-- L23: Orphan rows (rows that refer to a parent row that does not exist)
-- Result: 0 in all five checks
SELECT
  (SELECT COUNT(*) FROM orders o
   LEFT JOIN customers c ON o.customer_id = c.customer_id
   WHERE c.customer_id IS NULL) AS orders_without_customer,
  (SELECT COUNT(*) FROM order_items oi
   LEFT JOIN orders o ON oi.order_id = o.order_id
   WHERE o.order_id IS NULL) AS items_without_order,
  (SELECT COUNT(*) FROM order_items oi
   LEFT JOIN products p ON oi.product_id = p.product_id
   WHERE p.product_id IS NULL) AS items_without_product,
  (SELECT COUNT(*) FROM order_items oi
   LEFT JOIN sellers s ON oi.seller_id = s.seller_id
   WHERE s.seller_id IS NULL) AS items_without_seller,
  (SELECT COUNT(*) FROM order_reviews r
   LEFT JOIN orders o ON r.order_id = o.order_id
   WHERE o.order_id IS NULL) AS reviews_without_order;


-- =============================================================================
-- SECTION G: MISSING VALUES AND INDEXES
-- =============================================================================

-- L24: Missing values per column
-- Calculated for all columns of all tables with a Python script (pandas and
-- sqlite3) because the table has many columns. Result: 13 columns in 3 tables
-- have missing values; all missing values are NULL, none are empty strings.
-- The two checks below support the findings for the columns that are used.

-- L24a: Number of NULL delivery dates (also see L4 and L26)
-- Result: 2,965 (2.98% of orders)
SELECT SUM(order_delivered_customer_date IS NULL) AS null_delivery_dates,
       COUNT(*) AS total_orders
FROM orders;

-- L27: Indexes that exist in the database
-- Result: indexes from sql/00_setup_indexes.sql and idx_translation_unique
SELECT name AS index_name, tbl_name AS table_name
FROM sqlite_master
WHERE type = 'index' AND name LIKE 'idx_%'
ORDER BY tbl_name, name;


-- =============================================================================
-- SECTION H: TIME COVERAGE
-- =============================================================================

-- L25a: Monthly volume of delivered orders (by purchase month)
-- Result: 23 months from 2016-09 to 2018-08; 2016-09: 1, 2016-10: 265,
--         2016-12: 1, none in 2016-11; 750 to 7,289 per month from 2017-01
SELECT strftime('%Y-%m', order_purchase_timestamp) AS month, COUNT(*) AS orders
FROM orders
WHERE order_status = 'delivered'
GROUP BY month
ORDER BY month;

-- L25b: Date range of orders across all statuses
-- Result: 2016-09-04 21:15:19 to 2018-10-17 17:30:18
SELECT MIN(order_purchase_timestamp) AS first_purchase_all,
       MAX(order_purchase_timestamp) AS last_purchase_all
FROM orders;


-- =============================================================================
-- SECTION I: MINIMUM SAMPLE SIZE (supports docs/business_questions_and_kpis.md)
-- =============================================================================

-- T3: Orders per customer state (delivered orders), smallest first
-- Result: RR 41 | AP 67 | AC 80 | AM 145 | all other states 200 or more;
--         maximum SP 40,501
SELECT c.customer_state, COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY orders;

-- T4: Orders per product category (delivered orders), smallest first
-- Result: 73 named categories plus 1,392 orders without a category;
--         22 categories below 100 orders (837 orders in total)
SELECT p.product_category_name, COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name
ORDER BY orders;

-- T5: Sensitivity of the seller threshold (30, 50, 100 delivered orders)
-- Result: 2,970 sellers | 627 at 30 or more | 425 at 50 or more | 210 at 100 or more |
--         orders covered: 81,651 | 73,980 | 58,945
--         (approximate: orders with several sellers are counted under each seller)
WITH seller_orders AS (
  SELECT oi.seller_id, COUNT(DISTINCT o.order_id) AS orders
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY oi.seller_id
)
SELECT
  COUNT(*) AS sellers_total,
  SUM(CASE WHEN orders >= 30  THEN 1 ELSE 0 END) AS sellers_ge_30,
  SUM(CASE WHEN orders >= 50  THEN 1 ELSE 0 END) AS sellers_ge_50,
  SUM(CASE WHEN orders >= 100 THEN 1 ELSE 0 END) AS sellers_ge_100,
  SUM(CASE WHEN orders >= 30  THEN orders ELSE 0 END) AS orders_covered_30,
  SUM(CASE WHEN orders >= 50  THEN orders ELSE 0 END) AS orders_covered_50,
  SUM(CASE WHEN orders >= 100 THEN orders ELSE 0 END) AS orders_covered_100
FROM seller_orders;

-- T6: Total number of states and named categories among delivered orders
-- Result: 27 states | 73 named categories
SELECT COUNT(DISTINCT c.customer_state) AS total_states_delivered
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';

SELECT COUNT(DISTINCT p.product_category_name) AS total_named_categories_delivered
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
  AND p.product_category_name IS NOT NULL;

-- T7: Groups meeting the minimum sample size
--     (states 100, categories 100, months 500; delivered orders)
-- Result: states 24 of 27 | categories 51 of 73 | months 20 of 23
WITH s AS (
  SELECT c.customer_state AS g, COUNT(DISTINCT o.order_id) AS n
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_state
),
cat AS (
  SELECT p.product_category_name AS g, COUNT(DISTINCT o.order_id) AS n
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN products p ON oi.product_id = p.product_id
  WHERE o.order_status = 'delivered'
    AND p.product_category_name IS NOT NULL
  GROUP BY p.product_category_name
),
m AS (
  SELECT strftime('%Y-%m', order_purchase_timestamp) AS g, COUNT(*) AS n
  FROM orders
  WHERE order_status = 'delivered'
  GROUP BY g
)
SELECT 'state (>=100)' AS dimension, COUNT(*) AS total_groups,
       SUM(n >= 100) AS groups_meeting_threshold,
       SUM(CASE WHEN n >= 100 THEN n ELSE 0 END) AS orders_covered
FROM s
UNION ALL
SELECT 'category (>=100)', COUNT(*), SUM(n >= 100),
       SUM(CASE WHEN n >= 100 THEN n ELSE 0 END)
FROM cat
UNION ALL
SELECT 'month (>=500)', COUNT(*), SUM(n >= 500),
       SUM(CASE WHEN n >= 500 THEN n ELSE 0 END)
FROM m;
