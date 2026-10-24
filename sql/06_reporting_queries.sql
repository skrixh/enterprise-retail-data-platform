-- ============================================================
-- Sprint 2 | Retail reporting queries on the GOLD star schema
-- These answer the UC3 KPIs and are reused in Power BI (Sprint 3).
-- "Valid sale" = not cancelled, not a return, price > 0, real product.
-- ============================================================

-- 1. Daily Sales Revenue (by channel)
SELECT d.full_date, c.channel_name,
       SUM(f.line_amount)                  AS revenue,
       COUNT(DISTINCT f.transaction_ref)   AS orders
FROM gold.fact_sales f
JOIN gold.dim_date d    ON d.date_key = f.date_key
JOIN gold.dim_channel c ON c.channel_key = f.channel_key
JOIN gold.dim_product p ON p.product_key = f.product_key
WHERE NOT f.is_cancelled AND NOT f.is_return AND NOT f.is_zero_price AND NOT p.is_non_product
GROUP BY d.full_date, c.channel_name
ORDER BY d.full_date, c.channel_name;

-- 2. Top 10 Selling Products (by revenue)
SELECT p.product_id, p.product_description,
       SUM(f.quantity)    AS units_sold,
       SUM(f.line_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_product p ON p.product_key = f.product_key
WHERE NOT f.is_cancelled AND NOT f.is_return AND NOT f.is_zero_price AND NOT p.is_non_product
GROUP BY p.product_id, p.product_description
ORDER BY revenue DESC
LIMIT 10;

-- 3. Average Order Value (by channel)
SELECT c.channel_name,
       ROUND(SUM(f.line_amount) / COUNT(DISTINCT f.transaction_ref), 2) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_channel c ON c.channel_key = f.channel_key
JOIN gold.dim_product p ON p.product_key = f.product_key
WHERE NOT f.is_cancelled AND NOT f.is_return AND NOT f.is_zero_price AND NOT p.is_non_product
GROUP BY c.channel_name;

-- 4. Regional Sales Performance (by country)
SELECT f.country,
       SUM(f.line_amount)                 AS revenue,
       COUNT(DISTINCT f.transaction_ref)  AS orders,
       COUNT(DISTINCT NULLIF(f.customer_key, -1)) AS customers
FROM gold.fact_sales f
JOIN gold.dim_product p ON p.product_key = f.product_key
WHERE NOT f.is_cancelled AND NOT f.is_return AND NOT f.is_zero_price AND NOT p.is_non_product
GROUP BY f.country
ORDER BY revenue DESC;

-- 5. Return & Refund Analysis
SELECT c.channel_name,
       COUNT(*) FILTER (WHERE f.is_return)                    AS return_lines,
       COUNT(*) FILTER (WHERE f.is_cancelled)                 AS cancelled_lines,
       -SUM(f.line_amount) FILTER (WHERE f.is_return)         AS refund_value,
       ROUND(100.0 * COUNT(*) FILTER (WHERE f.is_return) / COUNT(*), 2) AS return_rate_pct
FROM gold.fact_sales f
JOIN gold.dim_channel c ON c.channel_key = f.channel_key
GROUP BY c.channel_name;

-- 6. Customer Retention (customers who bought on more than one day)
SELECT COUNT(*)                                        AS known_customers,
       COUNT(*) FILTER (WHERE active_days > 1)         AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_days > 1) / COUNT(*), 2) AS retention_rate_pct
FROM (SELECT customer_key, COUNT(DISTINCT date_key) AS active_days
      FROM gold.fact_sales
      WHERE customer_key <> -1 AND NOT is_cancelled AND NOT is_return
      GROUP BY customer_key) t;

-- 7. Stock Availability (latest snapshot)
SELECT COUNT(*)                                          AS products,
       COUNT(*) FILTER (WHERE stock_quantity > 0)        AS in_stock,
       COUNT(*) FILTER (WHERE is_below_reorder)          AS below_reorder,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_below_reorder) / COUNT(*), 2) AS availability_pct
FROM gold.fact_inventory_snapshot
WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM gold.fact_inventory_snapshot);

-- 8. Reorder alert list (products below reorder level)
SELECT p.product_id, p.product_description, i.stock_quantity, i.reorder_level,
       i.reorder_level - i.stock_quantity AS shortfall
FROM gold.fact_inventory_snapshot i
JOIN gold.dim_product p ON p.product_key = i.product_key
WHERE i.is_below_reorder
  AND i.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM gold.fact_inventory_snapshot)
ORDER BY shortfall DESC;

-- 9. Inventory Turnover Ratio (units sold / average stock on hand)
--    Only one stock snapshot exists, so average stock = snapshot stock.
SELECT ROUND(SUM(s.units_sold)::NUMERIC / NULLIF(SUM(i.stock_quantity), 0), 3) AS inventory_turnover
FROM gold.fact_inventory_snapshot i
LEFT JOIN (SELECT product_key, SUM(quantity) AS units_sold
           FROM gold.fact_sales
           WHERE NOT is_cancelled AND NOT is_return
           GROUP BY product_key) s ON s.product_key = i.product_key
WHERE i.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM gold.fact_inventory_snapshot);

-- 10. Supplier performance (status mix, value, expected lead time)
SELECT s.supplier_id,
       COUNT(*)                                             AS purchase_orders,
       SUM(f.total_cost)                                    AS purchase_value,
       ROUND(AVG(f.expected_lead_time_days), 1)             AS avg_lead_time_days,
       COUNT(*) FILTER (WHERE f.order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE f.order_status = 'In Transit') AS in_transit,
       COUNT(*) FILTER (WHERE f.order_status = 'Pending')   AS pending
FROM gold.fact_supplier_orders f
JOIN gold.dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_id
ORDER BY purchase_value DESC;
-- Note: Supplier On-Time Delivery % needs an ACTUAL delivery date, which the
-- source does not have. Document this as a data gap in the Sprint 3 report.

-- 11. Data-quality check on the warehouse (all should be 0)
SELECT 'fact_sales with unknown date'     AS check, COUNT(*) FROM gold.fact_sales WHERE date_key = -1
UNION ALL SELECT 'fact_sales with unknown product', COUNT(*) FROM gold.fact_sales WHERE product_key = -1
UNION ALL SELECT 'supplier orders with unknown product', COUNT(*) FROM gold.fact_supplier_orders WHERE product_key = -1
UNION ALL SELECT 'inventory rows with unknown product',  COUNT(*) FROM gold.fact_inventory_snapshot WHERE product_key = -1;
