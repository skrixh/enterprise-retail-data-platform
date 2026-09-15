-- ============================================================
-- Sprint 2 | Reporting SQL Scripts
-- Queries run against the Star Schema (fact_sales, fact_supplier_orders,
-- dim_customer, dim_product, dim_supplier, dim_date)
-- ============================================================

-- 1. Daily Sales Revenue
SELECT d.full_date, SUM(f.total_amount) AS daily_revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE f.transaction_type = 'Sale'
GROUP BY d.full_date
ORDER BY d.full_date;

-- 2. Monthly Revenue Trend
SELECT d.year, d.month, SUM(f.total_amount) AS revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE f.transaction_type = 'Sale'
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- 3. Top 10 Selling Products (by quantity)
SELECT p.product_desc, SUM(f.quantity) AS total_sold
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
WHERE f.transaction_type = 'Sale'
GROUP BY p.product_desc
ORDER BY total_sold DESC
LIMIT 10;

-- 4. Top 10 Products by Revenue
SELECT p.product_desc, SUM(f.total_amount) AS revenue
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
WHERE f.transaction_type = 'Sale'
GROUP BY p.product_desc
ORDER BY revenue DESC
LIMIT 10;

-- 5. Inventory Turnover Indicator (units sold vs current stock, per product)
SELECT p.product_desc, p.stock_qty, SUM(f.quantity) AS units_sold,
       ROUND(SUM(f.quantity)::numeric / NULLIF(p.stock_qty, 0), 2) AS turnover_ratio
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
WHERE f.transaction_type = 'Sale'
GROUP BY p.product_desc, p.stock_qty
ORDER BY turnover_ratio DESC
LIMIT 20;

-- 6. Stock Availability — understocked products (below reorder level)
SELECT product_id, product_desc, stock_qty, reorder_level
FROM dim_product
WHERE stock_qty < reorder_level
ORDER BY (reorder_level - stock_qty) DESC;

-- 7. Customer Retention — repeat vs one-time customers
SELECT
    CASE WHEN order_count > 1 THEN 'Repeat Customer' ELSE 'One-Time Customer' END AS customer_type,
    COUNT(*) AS num_customers
FROM (
    SELECT customer_key, COUNT(DISTINCT invoice_no) AS order_count
    FROM fact_sales
    WHERE transaction_type = 'Sale' AND customer_key IS NOT NULL
    GROUP BY customer_key
) sub
GROUP BY customer_type;

-- 8. Average Order Value (AOV)
SELECT source_channel, ROUND(AVG(order_total)::numeric, 2) AS avg_order_value
FROM (
    SELECT source_channel, invoice_no, SUM(total_amount) AS order_total
    FROM fact_sales
    WHERE transaction_type = 'Sale'
    GROUP BY source_channel, invoice_no
) orders
GROUP BY source_channel;

-- 9. Supplier On-Time Delivery Rate
SELECT s.supplier_id,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN fo.order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
       ROUND(100.0 * SUM(CASE WHEN fo.order_status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*), 1) AS delivery_rate_pct
FROM fact_supplier_orders fo
JOIN dim_supplier s ON fo.supplier_key = s.supplier_key
GROUP BY s.supplier_id
ORDER BY delivery_rate_pct DESC;

-- 10. Regional Sales Performance (by country)
SELECT c.country, SUM(f.total_amount) AS revenue
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.transaction_type = 'Sale'
GROUP BY c.country
ORDER BY revenue DESC;

-- 11. Return & Refund Analysis
SELECT source_channel,
       COUNT(*) AS return_count,
       SUM(ABS(total_amount)) AS return_value
FROM fact_sales
WHERE transaction_type = 'Return'
GROUP BY source_channel;

-- 12. Sales by Channel (POS vs Ecommerce)
SELECT source_channel, COUNT(*) AS transactions, SUM(total_amount) AS revenue
FROM fact_sales
WHERE transaction_type = 'Sale'
GROUP BY source_channel;

-- 13. Pending Supplier Orders (operational check)
SELECT fo.purchase_order_id, s.supplier_id, p.product_desc, fo.quantity,
       fo.expected_delivery_date, fo.order_status
FROM fact_supplier_orders fo
JOIN dim_supplier s ON fo.supplier_key = s.supplier_key
JOIN dim_product p ON fo.product_key = p.product_key
WHERE fo.order_status = 'Pending'
ORDER BY fo.expected_delivery_date;
