-- ============================================================
-- Sprint 2 | GOLD load | Silver -> star schema
--
-- HOW TO USE WITH PENTAHO
--   Each block below = one Pentaho transformation:
--      [Table input]  (paste the SELECT)  -->  [Table output]  (target table)
--   The SELECT already looks up the surrogate keys with joins, so
--   no "Database lookup" steps are needed.
--   Load ORDER matters: all dimensions first, then the facts.
--   In Table output tick "Truncate table" for the FACT tables.
--   Dimensions use "WHERE NOT EXISTS" so they are safe to re-run.
--
-- You can also run this whole file in pgAdmin to load Gold in one go.
-- ============================================================


-- ---------- t_load_dim_date  ->  gold.dim_date ----------
-- Every day from the first to the last date found in any source, plus today
INSERT INTO gold.dim_date
SELECT CAST(TO_CHAR(d, 'YYYYMMDD') AS INTEGER)      AS date_key,
       d::date                                      AS full_date,
       EXTRACT(DAY FROM d)                          AS day,
       TRIM(TO_CHAR(d, 'Day'))                      AS day_name,
       EXTRACT(WEEK FROM d)                         AS week_of_year,
       EXTRACT(MONTH FROM d)                        AS month,
       TRIM(TO_CHAR(d, 'Month'))                    AS month_name,
       EXTRACT(QUARTER FROM d)                      AS quarter,
       EXTRACT(YEAR FROM d)                         AS year,
       EXTRACT(ISODOW FROM d) IN (6, 7)             AS is_weekend
FROM GENERATE_SERIES(
        LEAST((SELECT MIN(sale_date)  FROM silver.sales_pos),
              (SELECT MIN(sale_date)  FROM silver.sales_ecommerce),
              (SELECT MIN(order_date) FROM silver.supplier_orders)),
        GREATEST((SELECT MAX(expected_delivery_date) FROM silver.supplier_orders),
                 CURRENT_DATE),
        INTERVAL '1 day') AS d
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date x WHERE x.full_date = d::date);


-- ---------- t_load_dim_customer  ->  gold.dim_customer ----------
INSERT INTO gold.dim_customer (customer_id, country)
SELECT c.customer_id, c.country
FROM silver.customers c
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customer x WHERE x.customer_id = c.customer_id);


-- ---------- t_load_dim_product  ->  gold.dim_product ----------
INSERT INTO gold.dim_product (product_id, product_description, list_price, reorder_level, is_non_product)
SELECT p.product_id, p.product_description, p.unit_price, p.reorder_level, p.is_non_product
FROM silver.products p
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_product x WHERE x.product_id = p.product_id);


-- ---------- t_load_dim_supplier  ->  gold.dim_supplier ----------
INSERT INTO gold.dim_supplier (supplier_id)
SELECT DISTINCT s.supplier_id
FROM silver.supplier_orders s
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_supplier x WHERE x.supplier_id = s.supplier_id);


-- ---------- t_load_fact_sales  ->  gold.fact_sales  (Truncate = ON) ----------
TRUNCATE gold.fact_sales;
INSERT INTO gold.fact_sales (date_key, customer_key, product_key, channel_key, transaction_ref,
                             sale_timestamp, country, quantity, unit_price, line_amount,
                             is_cancelled, is_return, is_zero_price, source_system, source_line_id)
SELECT COALESCE(dd.date_key, -1),
       COALESCE(dc.customer_key, -1),
       COALESCE(dp.product_key, -1),
       1,                                   -- POS
       s.invoice_no, s.invoice_date, s.country, s.quantity, s.unit_price, s.line_amount,
       s.is_cancelled, s.is_return, s.is_zero_price,
       'POS', s.pos_line_id
FROM silver.sales_pos s
LEFT JOIN gold.dim_date     dd ON dd.full_date   = s.sale_date
LEFT JOIN gold.dim_customer dc ON dc.customer_id = s.customer_id
LEFT JOIN gold.dim_product  dp ON dp.product_id  = s.product_id
UNION ALL
SELECT COALESCE(dd.date_key, -1),
       COALESCE(dc.customer_key, -1),
       COALESCE(dp.product_key, -1),
       2,                                   -- E-Commerce
       s.order_id, s.order_date, s.country, s.quantity, s.unit_price, s.line_amount,
       s.is_cancelled, s.is_return, s.is_zero_price,
       'E-Commerce', s.ecom_line_id
FROM silver.sales_ecommerce s
LEFT JOIN gold.dim_date     dd ON dd.full_date   = s.sale_date
LEFT JOIN gold.dim_customer dc ON dc.customer_id = s.customer_id
LEFT JOIN gold.dim_product  dp ON dp.product_id  = s.product_id;


-- ---------- t_load_fact_inventory  ->  gold.fact_inventory_snapshot ----------
-- Snapshot dated today; re-running on the same day replaces that day's snapshot
DELETE FROM gold.fact_inventory_snapshot
WHERE snapshot_date_key = CAST(TO_CHAR(CURRENT_DATE, 'YYYYMMDD') AS INTEGER);
INSERT INTO gold.fact_inventory_snapshot (snapshot_date_key, product_key, stock_quantity,
                                          reorder_level, stock_value, is_below_reorder)
SELECT CAST(TO_CHAR(CURRENT_DATE, 'YYYYMMDD') AS INTEGER),
       COALESCE(dp.product_key, -1),
       p.stock_quantity,
       p.reorder_level,
       ROUND(p.stock_quantity * p.unit_price, 2),
       (p.stock_quantity < p.reorder_level)
FROM silver.products p
LEFT JOIN gold.dim_product dp ON dp.product_id = p.product_id
WHERE NOT p.is_non_product;


-- ---------- t_load_fact_supplier_orders  ->  gold.fact_supplier_orders  (Truncate = ON) ----------
TRUNCATE gold.fact_supplier_orders;
INSERT INTO gold.fact_supplier_orders
SELECT s.purchase_order_id,
       COALESCE(ds.supplier_key, -1),
       COALESCE(dp.product_key, -1),
       COALESCE(d1.date_key, -1),
       COALESCE(d2.date_key, -1),
       s.quantity, s.unit_cost, s.total_cost, s.expected_lead_time_days, s.order_status
FROM silver.supplier_orders s
LEFT JOIN gold.dim_supplier ds ON ds.supplier_id = s.supplier_id
LEFT JOIN gold.dim_product  dp ON dp.product_id  = s.product_id
LEFT JOIN gold.dim_date     d1 ON d1.full_date   = s.order_date
LEFT JOIN gold.dim_date     d2 ON d2.full_date   = s.expected_delivery_date;
