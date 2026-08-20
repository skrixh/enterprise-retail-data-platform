DROP TABLE IF EXISTS stg_customers;

CREATE TABLE stg_customers (
    customer_id     VARCHAR(50),      
    country         VARCHAR(100),
    source_note     TEXT,

    source_file     VARCHAR(100) DEFAULT 'customers.json',
    load_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

