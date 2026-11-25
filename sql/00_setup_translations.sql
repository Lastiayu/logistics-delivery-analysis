-- 00_setup_translations.sql
-- Two product categories are missing from the original translation table.
-- The English names below were added manually by the analyst and are not part of the original dataset.
-- Run this once after importing the CSV files. Safe to run more than once.

-- The unique index prevents duplicate category names, which would duplicate rows in joins.
CREATE UNIQUE INDEX IF NOT EXISTS idx_translation_unique
ON product_category_translation(product_category_name);

INSERT OR IGNORE INTO product_category_translation
    (product_category_name, product_category_name_english)
VALUES
    ('pc_gamer', 'gaming_pc'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers');
