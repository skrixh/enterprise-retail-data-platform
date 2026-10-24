-- ============================================================
-- Sprint 2 | SILVER layer | Clean, standardise and de-duplicate
-- Source : bronze.stg_*   (loaded by the Sprint 1 Pentaho pipelines)
-- Target : silver.*
-- Re-runnable: every table is dropped and rebuilt.
-- Cleaning rules come from docs/Data_Quality_Report.md
-- ============================================================

-- Codes in the product columns that are NOT real products
-- (postage, manual adjustments, discounts, bank charges, carriage)
DROP TABLE IF EXISTS silver.non_product_codes;
CREATE TABLE silver.non_product_codes (code VARCHAR(20) PRIMARY KEY, meaning VARCHAR(50));
INSERT INTO silver.non_product_codes VALUES
    ('POST', 'Postage'), ('DOT', 'Dotcom postage'), ('C2', 'Carriage'),
    ('M', 'Manual adjustment'), ('D', 'Discount'), ('BANK CHARGES', 'Bank charges');


-- ------------------------------------------------------------
-- 1. Products  (source: inventory.xml)
--    Rules: trim/upper IDs, fill missing descriptions, flag non-products.
--    27 codes exist twice with different letter case (85123A / 85123a).
--    They are the same product -> merged into ONE row:
--      * attributes (description, price) from the UPPER-case record
--      * stock_quantity = stock of both records added together
--      * reorder_level  = the higher of the two
-- ------------------------------------------------------------
DROP TABLE IF EXISTS silver.products;
CREATE TABLE silver.products AS
WITH std AS (
    SELECT i.*,
           UPPER(TRIM(i.product_id))                                     AS std_id,
           SUM(i.stock_quantity) OVER (PARTITION BY UPPER(TRIM(i.product_id))) AS total_stock,
           MAX(i.reorder_level)  OVER (PARTITION BY UPPER(TRIM(i.product_id))) AS max_reorder,
           COUNT(*)              OVER (PARTITION BY UPPER(TRIM(i.product_id))) AS case_variants
    FROM bronze.stg_inventory i
)
SELECT DISTINCT ON (s.std_id)
    s.std_id                                                   AS product_id,
    COALESCE(NULLIF(TRIM(s.product_description), ''), 'UNKNOWN PRODUCT')
                                                               AS product_description,
    s.unit_price,
    s.total_stock                                              AS stock_quantity,
    s.max_reorder                                              AS reorder_level,
    (s.case_variants > 1)                                      AS was_case_merged,
    (n.code IS NOT NULL)                                       AS is_non_product,
    s.source_file,
    s.load_timestamp                                           AS bronze_load_timestamp
FROM std s
LEFT JOIN silver.non_product_codes n ON n.code = s.std_id
ORDER BY s.std_id,
         (TRIM(s.product_id) = s.std_id) DESC;   -- upper-case original first

ALTER TABLE silver.products ADD PRIMARY KEY (product_id);


-- ------------------------------------------------------------
-- 2. Customers  (source: customers.json)
--    Rules: '17850.0' -> 17850 (INTEGER), one row per customer
-- ------------------------------------------------------------
DROP TABLE IF EXISTS silver.customers;
CREATE TABLE silver.customers AS
SELECT DISTINCT ON (customer_id)
    CAST(CAST(TRIM(c.customer_id) AS NUMERIC) AS INTEGER)      AS customer_id,
    COALESCE(NULLIF(TRIM(c.country), ''), 'Unknown')           AS country,
    c.source_file,
    c.load_timestamp                                           AS bronze_load_timestamp
FROM bronze.stg_customers c
WHERE c.customer_id IS NOT NULL
ORDER BY customer_id;

ALTER TABLE silver.customers ADD PRIMARY KEY (customer_id);


-- ------------------------------------------------------------
-- 3. POS sales  (source: pos_transactions.csv)
--    Rules: remove exact duplicate rows, keep cancellations/returns
--    but FLAG them, fix customer IDs, fill missing descriptions.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS silver.sales_pos;
CREATE TABLE silver.sales_pos AS
WITH dedup AS (                       -- exact duplicates removed (196 rows)
    SELECT DISTINCT invoice_no, stock_code, description, quantity,
                    invoice_date, unit_price, customer_id, country, source_file
    FROM bronze.stg_pos_transactions
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.invoice_date, d.invoice_no, d.stock_code) AS pos_line_id,
    TRIM(d.invoice_no)                                         AS invoice_no,
    UPPER(TRIM(d.stock_code))                                  AS product_id,
    COALESCE(NULLIF(TRIM(d.description), ''), p.product_description, 'UNKNOWN PRODUCT')
                                                               AS description,
    d.quantity,
    d.unit_price,
    ROUND(d.quantity * d.unit_price, 2)                        AS line_amount,
    d.invoice_date,
    CAST(d.invoice_date AS DATE)                               AS sale_date,
    CAST(CAST(NULLIF(TRIM(d.customer_id), '') AS NUMERIC) AS INTEGER) AS customer_id,
    TRIM(d.country)                                            AS country,
    (d.invoice_no LIKE 'C%')                                   AS is_cancelled,
    (d.quantity < 0)                                           AS is_return,
    (d.unit_price = 0)                                         AS is_zero_price,
    (n.code IS NOT NULL)                                       AS is_non_product,
    d.source_file
FROM dedup d
LEFT JOIN silver.products p          ON p.product_id = UPPER(TRIM(d.stock_code))
LEFT JOIN silver.non_product_codes n ON n.code = UPPER(TRIM(d.stock_code));


-- ------------------------------------------------------------
-- 4. E-commerce sales  (source: ecommerce_orders.xlsx)
--    Same rules as POS. product_id '22752.0' -> '22752' if Excel added '.0'
-- ------------------------------------------------------------
DROP TABLE IF EXISTS silver.sales_ecommerce;
CREATE TABLE silver.sales_ecommerce AS
WITH dedup AS (                       -- exact duplicates removed (49 rows)
    SELECT DISTINCT order_id, customer_id, product_id, quantity,
                    unit_price, order_date, country, source_file
    FROM bronze.stg_ecommerce_orders
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.order_date, d.order_id, d.product_id) AS ecom_line_id,
    TRIM(d.order_id)                                           AS order_id,
    UPPER(REGEXP_REPLACE(TRIM(d.product_id), '\.0$', ''))      AS product_id,
    COALESCE(p.product_description, 'UNKNOWN PRODUCT')         AS description,
    d.quantity,
    d.unit_price,
    ROUND(d.quantity * d.unit_price, 2)                        AS line_amount,
    d.order_date,
    CAST(d.order_date AS DATE)                                 AS sale_date,
    CAST(CAST(NULLIF(TRIM(d.customer_id), '') AS NUMERIC) AS INTEGER) AS customer_id,
    TRIM(d.country)                                            AS country,
    FALSE                                                      AS is_cancelled,
    (d.quantity < 0)                                           AS is_return,
    (d.unit_price = 0)                                         AS is_zero_price,
    (n.code IS NOT NULL)                                       AS is_non_product,
    d.source_file
FROM dedup d
LEFT JOIN silver.products p          ON p.product_id = UPPER(REGEXP_REPLACE(TRIM(d.product_id), '\.0$', ''))
LEFT JOIN silver.non_product_codes n ON n.code = UPPER(REGEXP_REPLACE(TRIM(d.product_id), '\.0$', ''));


-- ------------------------------------------------------------
-- 5. Supplier purchase orders  (source: supplier_orders.sql)
--    Rules: trim IDs, flag non-products, add lead time
-- ------------------------------------------------------------
DROP TABLE IF EXISTS silver.supplier_orders;
CREATE TABLE silver.supplier_orders AS
SELECT DISTINCT ON (s.purchase_order_id)
    TRIM(s.purchase_order_id)                                  AS purchase_order_id,
    UPPER(TRIM(s.supplier_id))                                 AS supplier_id,
    UPPER(TRIM(s.product_id))                                  AS product_id,
    s.quantity,
    s.unit_cost,
    ROUND(s.quantity * s.unit_cost, 2)                         AS total_cost,
    s.order_date,
    s.expected_delivery_date,
    (s.expected_delivery_date - s.order_date)                  AS expected_lead_time_days,
    TRIM(s.order_status)                                       AS order_status,
    (n.code IS NOT NULL)                                       AS is_non_product,
    s.source_file
FROM bronze.stg_supplier_orders s
LEFT JOIN silver.non_product_codes n ON n.code = UPPER(TRIM(s.product_id))
ORDER BY s.purchase_order_id;

ALTER TABLE silver.supplier_orders ADD PRIMARY KEY (purchase_order_id);


-- ------------------------------------------------------------
-- Check: rows in Bronze vs Silver (difference = duplicates removed)
-- ------------------------------------------------------------
SELECT 'POS' AS source,
       (SELECT COUNT(*) FROM bronze.stg_pos_transactions) AS bronze_rows,
       (SELECT COUNT(*) FROM silver.sales_pos)            AS silver_rows
UNION ALL SELECT 'E-commerce', (SELECT COUNT(*) FROM bronze.stg_ecommerce_orders), (SELECT COUNT(*) FROM silver.sales_ecommerce)
UNION ALL SELECT 'CRM',        (SELECT COUNT(*) FROM bronze.stg_customers),        (SELECT COUNT(*) FROM silver.customers)
UNION ALL SELECT 'Inventory',  (SELECT COUNT(*) FROM bronze.stg_inventory),        (SELECT COUNT(*) FROM silver.products)  -- 27 case duplicates merged
UNION ALL SELECT 'Supplier',   (SELECT COUNT(*) FROM bronze.stg_supplier_orders),  (SELECT COUNT(*) FROM silver.supplier_orders);
