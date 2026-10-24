# Source-to-Target Mapping – ERDP

**Sprint 3 deliverable** · Shows, column by column, how each source field travels Bronze → Silver → Gold and which rule changes it.

Pentaho objects: Bronze = `t_ingest_*.ktr` · Silver = SQL entry *Silver cleaning* (`sql/03_silver_cleaning.sql`) · Gold = `t_gold_*.ktr` · all orchestrated by `j_erdp_master.kjb`.

---

## 1. POS – `pos_transactions.csv`
Pipelines: `t_ingest_pos` → Silver cleaning → `t_gold_fact_sales`

| Source field | Bronze `stg_pos_transactions` | Silver `sales_pos` | Rule | Gold |
|---|---|---|---|---|
| InvoiceNo | invoice_no (text) | invoice_no | TRIM | fact_sales.transaction_ref |
| InvoiceNo | — | is_cancelled | TRUE if starts with "C" | fact_sales.is_cancelled |
| StockCode | stock_code | product_id | TRIM + UPPER | lookup → fact_sales.product_key |
| Description | description | description | If empty, fill from inventory description | via dim_product.product_description |
| Quantity | quantity | quantity, is_return | is_return = quantity < 0 | fact_sales.quantity, is_return |
| InvoiceDate | invoice_date | invoice_date, sale_date | sale_date = date part | fact_sales.sale_timestamp; lookup → date_key |
| UnitPrice | unit_price | unit_price, is_zero_price | is_zero_price = price = 0 | fact_sales.unit_price, is_zero_price |
| Quantity × UnitPrice | — | line_amount | ROUND(qty × price, 2) | fact_sales.line_amount |
| CustomerID | customer_id ("17850.0") | customer_id (17850) | Cast to INTEGER; NULL stays NULL | lookup → fact_sales.customer_key (NULL → −1 Unknown) |
| Country | country | country | TRIM | fact_sales.country |
| (whole row) | — | — | Exact duplicate rows removed (196) | — |
| — | source_file, load_timestamp | source_file, pos_line_id | Audit / lineage | fact_sales.source_system = 'POS', source_line_id |
| — | — | — | Fixed value | fact_sales.channel_key = 1 (POS) |

## 2. E-commerce – `ecommerce_orders.xlsx` (Sheet1)
Pipelines: `t_ingest_ecommerce` → Silver cleaning → `t_gold_fact_sales`

| Source field | Bronze `stg_ecommerce_orders` | Silver `sales_ecommerce` | Rule | Gold |
|---|---|---|---|---|
| order_id | order_id | order_id | TRIM | fact_sales.transaction_ref |
| customer_id | customer_id | customer_id | Cast to INTEGER | lookup → customer_key (NULL → −1) |
| product_id | product_id | product_id | TRIM, UPPER, strip trailing ".0" | lookup → product_key |
| quantity | quantity | quantity, is_return | is_return = quantity < 0 | fact_sales.quantity, is_return |
| unit_price | unit_price | unit_price, is_zero_price | — | fact_sales.unit_price |
| quantity × unit_price | — | line_amount | ROUND(qty × price, 2) | fact_sales.line_amount |
| order_date | order_date | order_date, sale_date | sale_date = date part | sale_timestamp; lookup → date_key |
| country | country | country | TRIM | fact_sales.country |
| (whole row) | — | — | Exact duplicate rows removed (49) | — |
| — | — | is_cancelled | Always FALSE (no cancellation flag in source) | fact_sales.is_cancelled |
| — | source_file | source_file, ecom_line_id | Lineage | source_system = 'E-Commerce', source_line_id |
| — | — | — | Fixed value | fact_sales.channel_key = 2 |

## 3. CRM – `customers.json`
Pipelines: `t_ingest_customers` → Silver cleaning → `t_gold_dim_customer`

| Source field (JSON path) | Bronze `stg_customers` | Silver `customers` | Rule | Gold `dim_customer` |
|---|---|---|---|---|
| $[*].customer_id | customer_id ("17850.0") | customer_id (17850) | Cast to INTEGER, one row per ID | customer_id (business key) |
| $[*].country | country | country | Empty → "Unknown" | country |
| $[*].source_note | source_note | — | Not used (same text on every row) | — |
| — | — | — | Surrogate key generated | customer_key (SERIAL); −1 = Unknown |

## 4. Inventory – `inventory.xml`
Pipelines: `t_ingest_inventory` → Silver cleaning → `t_gold_dim_product`, `t_gold_fact_inventory`

| Source field (XPath /inventory/item) | Bronze `stg_inventory` | Silver `products` | Rule | Gold |
|---|---|---|---|---|
| product_id | product_id | product_id | TRIM + UPPER; upper/lower-case pairs merged | dim_product.product_id; lookup → product_key |
| product_description | product_description | product_description | Empty → "UNKNOWN PRODUCT"; taken from upper-case record | dim_product.product_description |
| unit_price | unit_price | unit_price | Taken from upper-case record | dim_product.list_price; used in stock_value |
| stock_quantity | stock_quantity | stock_quantity | SUM over merged case variants | fact_inventory_snapshot.stock_quantity |
| reorder_level | reorder_level | reorder_level | MAX over merged case variants | dim_product.reorder_level, fact_inventory_snapshot.reorder_level |
| — | — | is_non_product | TRUE for POST, DOT, C2, M, D, BANK CHARGES | dim_product.is_non_product; excluded from snapshot |
| — | — | — | stock_quantity < reorder_level | fact_inventory_snapshot.is_below_reorder |
| — | — | — | stock_quantity × unit_price | fact_inventory_snapshot.stock_value |
| — | — | — | Load date | fact_inventory_snapshot.snapshot_date_key |

## 5. Supplier portal – `supplier_orders.sql`
Pipelines: run script into `src_supplier.supplier_orders` → `t_ingest_supplier_orders` (Table input) → Silver cleaning → `t_gold_dim_supplier`, `t_gold_fact_supplier_orders`

| Source column | Bronze `stg_supplier_orders` | Silver `supplier_orders` | Rule | Gold |
|---|---|---|---|---|
| purchase_order_id | purchase_order_id | purchase_order_id | TRIM, one row per PO | fact_supplier_orders.purchase_order_id (PK) |
| supplier_id | supplier_id | supplier_id | TRIM + UPPER | dim_supplier.supplier_id; lookup → supplier_key |
| product_id | product_id | product_id, is_non_product | TRIM + UPPER | lookup → product_key |
| quantity | quantity | quantity | — | quantity |
| unit_cost | unit_cost | unit_cost | — | unit_cost |
| quantity × unit_cost | — | total_cost | ROUND(qty × cost, 2) | total_cost |
| order_date | order_date | order_date | — | lookup → order_date_key |
| expected_delivery_date | expected_delivery_date | expected_delivery_date | — | lookup → expected_delivery_date_key |
| (both dates) | — | expected_lead_time_days | expected_delivery_date − order_date | expected_lead_time_days |
| order_status | order_status | order_status | TRIM | order_status |

## 6. Generated dimensions
| Gold table | Built from | Rule |
|---|---|---|
| dim_date | Min and max dates across all Silver tables, plus today | One row per day; date_key = YYYYMMDD; −1 = Unknown |
| dim_channel | Fixed values | 1 = POS, 2 = E-Commerce |
