-- ============================================================
-- Sprint 3 | Validation & Reconciliation
-- Compares Bronze (raw source) -> Silver (clean) -> Gold (warehouse).
-- Every check returns PASS or FAIL with the numbers behind it.
-- Run after the master job (j_erdp_master) has finished.
-- ============================================================

WITH
-- ---------- expected values derived from the layer before ----------
pos_dups  AS (SELECT COUNT(*) - COUNT(DISTINCT (invoice_no, stock_code, description, quantity,
                     invoice_date, unit_price, customer_id, country)) AS n
              FROM bronze.stg_pos_transactions),
ecom_dups AS (SELECT COUNT(*) - COUNT(DISTINCT (order_id, customer_id, product_id, quantity,
                     unit_price, order_date, country)) AS n
              FROM bronze.stg_ecommerce_orders),
inv_case  AS (SELECT COUNT(*) - COUNT(DISTINCT UPPER(TRIM(product_id))) AS n FROM bronze.stg_inventory),

checks AS (
    -- 1. ROW COUNTS ------------------------------------------------------
    SELECT 1 AS id, 'Row count' AS category, 'POS: Bronze - duplicates = Silver' AS check_name,
           (SELECT COUNT(*) FROM bronze.stg_pos_transactions) - (SELECT n FROM pos_dups) AS expected,
           (SELECT COUNT(*) FROM silver.sales_pos) AS actual
    UNION ALL
    SELECT 2, 'Row count', 'E-commerce: Bronze - duplicates = Silver',
           (SELECT COUNT(*) FROM bronze.stg_ecommerce_orders) - (SELECT n FROM ecom_dups),
           (SELECT COUNT(*) FROM silver.sales_ecommerce)
    UNION ALL
    SELECT 3, 'Row count', 'Customers: Bronze = Silver',
           (SELECT COUNT(*) FROM bronze.stg_customers), (SELECT COUNT(*) FROM silver.customers)
    UNION ALL
    SELECT 4, 'Row count', 'Products: Bronze - case duplicates = Silver',
           (SELECT COUNT(*) FROM bronze.stg_inventory) - (SELECT n FROM inv_case),
           (SELECT COUNT(*) FROM silver.products)
    UNION ALL
    SELECT 5, 'Row count', 'Supplier orders: Bronze = Silver = Gold',
           (SELECT COUNT(*) FROM bronze.stg_supplier_orders), (SELECT COUNT(*) FROM gold.fact_supplier_orders)
    UNION ALL
    SELECT 6, 'Row count', 'Sales: Silver POS + E-com = Gold fact_sales',
           (SELECT COUNT(*) FROM silver.sales_pos) + (SELECT COUNT(*) FROM silver.sales_ecommerce),
           (SELECT COUNT(*) FROM gold.fact_sales)
    UNION ALL
    SELECT 7, 'Row count', 'Customers: Silver = Gold dim_customer (excl. Unknown)',
           (SELECT COUNT(*) FROM silver.customers), (SELECT COUNT(*) FROM gold.dim_customer WHERE customer_key <> -1)
    UNION ALL
    SELECT 8, 'Row count', 'Products: Silver = Gold dim_product (excl. Unknown)',
           (SELECT COUNT(*) FROM silver.products), (SELECT COUNT(*) FROM gold.dim_product WHERE product_key <> -1)
    UNION ALL
    SELECT 9, 'Row count', 'Inventory: Silver real products = Gold snapshot (latest)',
           (SELECT COUNT(*) FROM silver.products WHERE NOT is_non_product),
           (SELECT COUNT(*) FROM gold.fact_inventory_snapshot
             WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM gold.fact_inventory_snapshot))

    -- 2. SALES RECONCILIATION (money) ------------------------------------
    UNION ALL
    SELECT 10, 'Sales', 'POS sales value: Silver = Gold',
           (SELECT SUM(line_amount) FROM silver.sales_pos),
           (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 1)
    UNION ALL
    SELECT 11, 'Sales', 'E-com sales value: Silver = Gold',
           (SELECT SUM(line_amount) FROM silver.sales_ecommerce),
           (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 2)
    UNION ALL
    SELECT 12, 'Sales', 'POS units: Silver = Gold',
           (SELECT SUM(quantity) FROM silver.sales_pos),
           (SELECT SUM(quantity) FROM gold.fact_sales WHERE channel_key = 1)
    UNION ALL
    SELECT 13, 'Sales', 'E-com units: Silver = Gold',
           (SELECT SUM(quantity) FROM silver.sales_ecommerce),
           (SELECT SUM(quantity) FROM gold.fact_sales WHERE channel_key = 2)

    -- 3. INVENTORY RECONCILIATION ----------------------------------------
    UNION ALL
    SELECT 14, 'Inventory', 'Total stock units: Bronze (real products) = Gold',
           (SELECT SUM(i.stock_quantity) FROM bronze.stg_inventory i
             WHERE UPPER(TRIM(i.product_id)) NOT IN (SELECT code FROM silver.non_product_codes)),
           (SELECT SUM(stock_quantity) FROM gold.fact_inventory_snapshot
             WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM gold.fact_inventory_snapshot))

    -- 4. FINANCIAL RECONCILIATION (purchases) ----------------------------
    UNION ALL
    SELECT 15, 'Financial', 'Purchase value: Bronze qty x cost = Gold total_cost',
           (SELECT ROUND(SUM(quantity * unit_cost), 2) FROM bronze.stg_supplier_orders),
           (SELECT SUM(total_cost) FROM gold.fact_supplier_orders)

    -- 5. REFERENTIAL INTEGRITY (expected 0) ------------------------------
    UNION ALL
    SELECT 16, 'Integrity', 'fact_sales rows with unknown date', 0,
           (SELECT COUNT(*) FROM gold.fact_sales WHERE date_key = -1)
    UNION ALL
    SELECT 17, 'Integrity', 'fact_sales rows with unknown product', 0,
           (SELECT COUNT(*) FROM gold.fact_sales WHERE product_key = -1)
    UNION ALL
    SELECT 18, 'Integrity', 'fact_sales rows with known customer ID missing from dim_customer', 0,
           (SELECT COUNT(*) FROM silver.sales_pos s WHERE s.customer_id IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_id = s.customer_id))
         + (SELECT COUNT(*) FROM silver.sales_ecommerce s WHERE s.customer_id IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_id = s.customer_id))
    UNION ALL
    SELECT 19, 'Integrity', 'supplier orders with unknown supplier or product', 0,
           (SELECT COUNT(*) FROM gold.fact_supplier_orders WHERE supplier_key = -1 OR product_key = -1)

    -- 6. UNIQUENESS (expected 0) -----------------------------------------
    UNION ALL
    SELECT 20, 'Uniqueness', 'duplicate product_id in dim_product', 0,
           (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM gold.dim_product)
    UNION ALL
    SELECT 21, 'Uniqueness', 'duplicate customer_id in dim_customer', 0,
           (SELECT COUNT(customer_id) - COUNT(DISTINCT customer_id) FROM gold.dim_customer)
)
SELECT id, category, check_name, expected, actual,
       CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY id;


-- ------------------------------------------------------------
-- Explained difference: Bronze vs Gold sales value
-- (Gold is lower ONLY because exact duplicate rows were removed)
-- ------------------------------------------------------------
SELECT 'POS' AS channel,
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_pos_transactions) AS bronze_value,
       (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 1)          AS gold_value,
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_pos_transactions)
     - (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 1)          AS difference,
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_pos_transactions)
     - (SELECT ROUND(SUM(quantity * unit_price), 2) FROM
          (SELECT DISTINCT invoice_no, stock_code, description, quantity, invoice_date,
                           unit_price, customer_id, country FROM bronze.stg_pos_transactions) d)
                                                                                     AS value_of_duplicates_removed
UNION ALL
SELECT 'E-Commerce',
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_ecommerce_orders),
       (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 2),
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_ecommerce_orders)
     - (SELECT SUM(line_amount) FROM gold.fact_sales WHERE channel_key = 2),
       (SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze.stg_ecommerce_orders)
     - (SELECT ROUND(SUM(quantity * unit_price), 2) FROM
          (SELECT DISTINCT order_id, customer_id, product_id, quantity, order_date,
                           unit_price, country FROM bronze.stg_ecommerce_orders) d);
