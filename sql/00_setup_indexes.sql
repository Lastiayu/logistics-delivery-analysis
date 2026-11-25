-- 00_setup_indexes.sql
-- Tables imported from CSV have no primary keys or indexes, so joins are very slow.
-- Run this once after importing the CSV files. Safe to run more than once.

CREATE INDEX IF NOT EXISTS idx_orders_order_id        ON orders(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id     ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_customer_id  ON customers(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller_id  ON order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_order_id ON order_reviews(order_id);
CREATE INDEX IF NOT EXISTS idx_products_product_id    ON products(product_id);
CREATE INDEX IF NOT EXISTS idx_sellers_seller_id      ON sellers(seller_id);
