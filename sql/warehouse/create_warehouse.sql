-- ============================================
-- ERDP STAR SCHEMA
-- ============================================

-- DIMENSION: CUSTOMER
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(150),
    email VARCHAR(150),
    city VARCHAR(100),
    country VARCHAR(100),
    loyalty_segment VARCHAR(50)
);

-- DIMENSION: PRODUCT
CREATE TABLE IF NOT EXISTS dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL
);

-- DIMENSION: DATE
CREATE TABLE IF NOT EXISTS dim_date (
    date_key SERIAL PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    day INTEGER,
    month INTEGER,
    quarter INTEGER,
    year INTEGER
);

-- DIMENSION: STORE
CREATE TABLE IF NOT EXISTS dim_store (
    store_key SERIAL PRIMARY KEY,
    store_id VARCHAR(50) UNIQUE NOT NULL
);

-- DIMENSION: WAREHOUSE
CREATE TABLE IF NOT EXISTS dim_warehouse (
    warehouse_key SERIAL PRIMARY KEY,
    warehouse_id VARCHAR(50) UNIQUE NOT NULL
);

-- DIMENSION: SUPPLIER
CREATE TABLE IF NOT EXISTS dim_supplier (
    supplier_key SERIAL PRIMARY KEY,
    supplier_id VARCHAR(50) UNIQUE NOT NULL
);


-- ============================================
-- FACT: SALES
-- ============================================

CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key SERIAL PRIMARY KEY,

    date_key INTEGER REFERENCES dim_date(date_key),
    customer_key INTEGER REFERENCES dim_customer(customer_key),
    product_key INTEGER REFERENCES dim_product(product_key),
    store_key INTEGER REFERENCES dim_store(store_key),

    transaction_id VARCHAR(100),
    order_id VARCHAR(100),

    sales_channel VARCHAR(30),

    quantity INTEGER,
    unit_price NUMERIC(12,2),
    total_amount NUMERIC(14,2),

    payment_method VARCHAR(50),
    shipping_city VARCHAR(100),
    order_status VARCHAR(50)
);


-- ============================================
-- FACT: INVENTORY
-- ============================================

CREATE TABLE IF NOT EXISTS fact_inventory (
    inventory_key SERIAL PRIMARY KEY,

    inventory_id VARCHAR(100),
    product_key INTEGER REFERENCES dim_product(product_key),
    warehouse_key INTEGER REFERENCES dim_warehouse(warehouse_key),
    date_key INTEGER REFERENCES dim_date(date_key),

    stock_quantity INTEGER,
    reorder_level INTEGER
);


-- ============================================
-- FACT: SUPPLIER ORDERS
-- ============================================

CREATE TABLE IF NOT EXISTS fact_supplier_orders (
    supplier_order_key SERIAL PRIMARY KEY,

    purchase_order_id VARCHAR(100),

    supplier_key INTEGER REFERENCES dim_supplier(supplier_key),

    order_date_key INTEGER REFERENCES dim_date(date_key),

    quantity INTEGER,
    unit_cost NUMERIC(12,2),
    total_cost NUMERIC(14,2),

    expected_delivery_date DATE,
    order_status VARCHAR(50)
);
