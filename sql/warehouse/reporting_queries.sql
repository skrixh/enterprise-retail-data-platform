-- ============================================
-- ERDP WAREHOUSE REPORTING QUERIES
-- ============================================


-- ============================================
-- 1. TOTAL SALES
-- ============================================

SELECT
    SUM(total_amount) AS total_sales
FROM warehouse.fact_sales;


-- ============================================
-- 2. SALES BY MONTH
-- ============================================

SELECT
    d.year,
    d.month,
    SUM(f.total_amount) AS monthly_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month
ORDER BY
    d.year,
    d.month;


-- ============================================
-- 3. SALES BY PRODUCT
-- ============================================

SELECT
    p.product_id,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.product_id
ORDER BY
    total_sales DESC
LIMIT 10;


-- ============================================
-- 4. SALES BY CUSTOMER
-- ============================================

SELECT
    c.customer_id,
    c.customer_name,
    SUM(f.total_amount) AS total_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY
    total_sales DESC
LIMIT 10;


-- ============================================
-- 5. SALES BY STORE
-- ============================================

SELECT
    s.store_id,
    SUM(f.total_amount) AS total_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_store s
    ON f.store_key = s.store_key
WHERE f.store_key IS NOT NULL
GROUP BY
    s.store_id
ORDER BY
    total_sales DESC;


-- ============================================
-- 6. INVENTORY BELOW REORDER LEVEL
-- ============================================

SELECT
    p.product_id,
    w.warehouse_id,
    f.stock_quantity,
    f.reorder_level
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
JOIN warehouse.dim_warehouse w
    ON f.warehouse_key = w.warehouse_key
WHERE f.stock_quantity < f.reorder_level
ORDER BY
    f.stock_quantity;


-- ============================================
-- 7. SUPPLIER ORDER COST
-- ============================================

SELECT
    s.supplier_id,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_cost) AS total_order_cost
FROM warehouse.fact_supplier_orders f
JOIN warehouse.dim_supplier s
    ON f.supplier_key = s.supplier_key
GROUP BY
    s.supplier_id
ORDER BY
    total_order_cost DESC;


-- ============================================
-- 8. SUPPLIER ORDER STATUS
-- ============================================

SELECT
    s.supplier_id,
    f.order_status,
    COUNT(*) AS order_count
FROM warehouse.fact_supplier_orders f
JOIN warehouse.dim_supplier s
    ON f.supplier_key = s.supplier_key
GROUP BY
    s.supplier_id,
    f.order_status
ORDER BY
    s.supplier_id,
    order_count DESC;
