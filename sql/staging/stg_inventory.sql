DROP TABLE IF EXISTS stg_inventory;

CREATE TABLE stg_inventory (
    product_id          VARCHAR(50),
    product_description VARCHAR(255),
    unit_price          NUMERIC(10,2),
    stock_quantity      INTEGER,
    reorder_level       INTEGER,

    source_file         VARCHAR(100) DEFAULT 'inventory.xml',
    load_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
