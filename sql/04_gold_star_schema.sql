-- ============================================================
-- Sprint 2 | GOLD layer | Star schema (data warehouse)
-- 5 dimensions + 3 facts. Run once to create the empty tables.
-- Every dimension has an "Unknown" row with key = -1 so a fact row
-- never has an empty key (e.g. sales with no customer).
-- ============================================================

DROP TABLE IF EXISTS gold.fact_sales, gold.fact_inventory_snapshot, gold.fact_supplier_orders CASCADE;
DROP TABLE IF EXISTS gold.dim_date, gold.dim_customer, gold.dim_product,
                     gold.dim_supplier, gold.dim_channel CASCADE;

-- ---------------- DIMENSIONS ----------------

-- Date: one row per calendar day. date_key = YYYYMMDD (e.g. 20101201)
CREATE TABLE gold.dim_date (
    date_key      INTEGER PRIMARY KEY,
    full_date     DATE UNIQUE NOT NULL,
    day           SMALLINT,
    day_name      VARCHAR(10),
    week_of_year  SMALLINT,
    month         SMALLINT,
    month_name    VARCHAR(10),
    quarter       SMALLINT,
    year          SMALLINT,
    is_weekend    BOOLEAN
);

-- Customer: from CRM (customers.json)
CREATE TABLE gold.dim_customer (
    customer_key  SERIAL PRIMARY KEY,
    customer_id   INTEGER UNIQUE,          -- business key from the source
    country       VARCHAR(100)
);

-- Product: from inventory.xml (product master)
CREATE TABLE gold.dim_product (
    product_key          SERIAL PRIMARY KEY,
    product_id           VARCHAR(20) UNIQUE,
    product_description  VARCHAR(255),
    list_price           NUMERIC(12,2),
    reorder_level        INTEGER,
    is_non_product       BOOLEAN           -- postage, discounts, fees
);

-- Supplier: from supplier_orders.sql
CREATE TABLE gold.dim_supplier (
    supplier_key  SERIAL PRIMARY KEY,
    supplier_id   VARCHAR(20) UNIQUE
);

-- Sales channel: store (POS) or online (E-commerce)
CREATE TABLE gold.dim_channel (
    channel_key   SMALLINT PRIMARY KEY,
    channel_name  VARCHAR(20) UNIQUE
);

-- "Unknown" members (key -1) and the two fixed channels
INSERT INTO gold.dim_date     VALUES (-1, '1900-01-01', NULL, 'Unknown', NULL, NULL, 'Unknown', NULL, NULL, NULL);
INSERT INTO gold.dim_customer (customer_key, customer_id, country) VALUES (-1, NULL, 'Unknown');
INSERT INTO gold.dim_product  (product_key, product_id, product_description, is_non_product)
                       VALUES (-1, 'UNKNOWN', 'UNKNOWN PRODUCT', FALSE);
INSERT INTO gold.dim_supplier (supplier_key, supplier_id) VALUES (-1, 'UNKNOWN');
INSERT INTO gold.dim_channel  VALUES (1, 'POS'), (2, 'E-Commerce');


-- ---------------- FACTS ----------------

-- Sales: one row per sales line, from both channels
CREATE TABLE gold.fact_sales (
    sales_key        BIGSERIAL PRIMARY KEY,
    date_key         INTEGER  NOT NULL REFERENCES gold.dim_date(date_key),
    customer_key     INTEGER  NOT NULL REFERENCES gold.dim_customer(customer_key),
    product_key      INTEGER  NOT NULL REFERENCES gold.dim_product(product_key),
    channel_key      SMALLINT NOT NULL REFERENCES gold.dim_channel(channel_key),
    transaction_ref  VARCHAR(20),        -- invoice_no (POS) or order_id (E-com)
    sale_timestamp   TIMESTAMP,
    country          VARCHAR(100),
    quantity         INTEGER,
    unit_price       NUMERIC(12,2),
    line_amount      NUMERIC(14,2),      -- quantity * unit_price (negative for returns)
    is_cancelled     BOOLEAN,
    is_return        BOOLEAN,
    is_zero_price    BOOLEAN,
    source_system    VARCHAR(20),        -- lineage: which source the row came from
    source_line_id   BIGINT              -- lineage: silver row id
);

-- Inventory snapshot: stock level of each product on the load date
CREATE TABLE gold.fact_inventory_snapshot (
    snapshot_key       BIGSERIAL PRIMARY KEY,
    snapshot_date_key  INTEGER NOT NULL REFERENCES gold.dim_date(date_key),
    product_key        INTEGER NOT NULL REFERENCES gold.dim_product(product_key),
    stock_quantity     INTEGER,
    reorder_level      INTEGER,
    stock_value        NUMERIC(14,2),    -- stock_quantity * unit_price
    is_below_reorder   BOOLEAN,
    UNIQUE (snapshot_date_key, product_key)
);

-- Supplier purchase orders
CREATE TABLE gold.fact_supplier_orders (
    purchase_order_id            VARCHAR(20) PRIMARY KEY,
    supplier_key                 INTEGER NOT NULL REFERENCES gold.dim_supplier(supplier_key),
    product_key                  INTEGER NOT NULL REFERENCES gold.dim_product(product_key),
    order_date_key               INTEGER NOT NULL REFERENCES gold.dim_date(date_key),
    expected_delivery_date_key   INTEGER NOT NULL REFERENCES gold.dim_date(date_key),
    quantity                     INTEGER,
    unit_cost                    NUMERIC(10,2),
    total_cost                   NUMERIC(14,2),
    expected_lead_time_days      INTEGER,
    order_status                 VARCHAR(30)
);

-- Indexes on the keys used for joins in reports / Power BI
CREATE INDEX ix_fs_date     ON gold.fact_sales(date_key);
CREATE INDEX ix_fs_product  ON gold.fact_sales(product_key);
CREATE INDEX ix_fs_customer ON gold.fact_sales(customer_key);
CREATE INDEX ix_fso_supplier ON gold.fact_supplier_orders(supplier_key);
