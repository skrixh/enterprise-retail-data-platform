# Star Schema – ERDP Gold Layer

**Sprint 2 deliverable** · Schema: `gold` · DDL: `sql/04_gold_star_schema.sql` · Load: `sql/05_gold_load_queries.sql`

## 1. Data flow (Medallion)

```mermaid
flowchart LR
    S1[pos_transactions.csv] --> B1[bronze.stg_pos_transactions]
    S2[ecommerce_orders.xlsx] --> B2[bronze.stg_ecommerce_orders]
    S3[customers.json] --> B3[bronze.stg_customers]
    S4[inventory.xml] --> B4[bronze.stg_inventory]
    S5[(supplier_orders.sql)] --> B5[bronze.stg_supplier_orders]

    B1 --> V1[silver.sales_pos]
    B2 --> V2[silver.sales_ecommerce]
    B3 --> V3[silver.customers]
    B4 --> V4[silver.products]
    B5 --> V5[silver.supplier_orders]

    V1 & V2 --> F1[gold.fact_sales]
    V3 --> D1[gold.dim_customer]
    V4 --> D2[gold.dim_product]
    V4 --> F2[gold.fact_inventory_snapshot]
    V5 --> D3[gold.dim_supplier]
    V5 --> F3[gold.fact_supplier_orders]
```

## 2. Star schema

```mermaid
erDiagram
    dim_date      ||--o{ fact_sales : "date_key"
    dim_customer  ||--o{ fact_sales : "customer_key"
    dim_product   ||--o{ fact_sales : "product_key"
    dim_channel   ||--o{ fact_sales : "channel_key"

    dim_date      ||--o{ fact_inventory_snapshot : "snapshot_date_key"
    dim_product   ||--o{ fact_inventory_snapshot : "product_key"

    dim_date      ||--o{ fact_supplier_orders : "order / expected_delivery date_key"
    dim_product   ||--o{ fact_supplier_orders : "product_key"
    dim_supplier  ||--o{ fact_supplier_orders : "supplier_key"

    fact_sales {
        bigint sales_key PK
        int date_key FK
        int customer_key FK
        int product_key FK
        smallint channel_key FK
        varchar transaction_ref
        int quantity
        numeric unit_price
        numeric line_amount
        boolean is_cancelled
        boolean is_return
        varchar source_system
    }
    fact_inventory_snapshot {
        bigint snapshot_key PK
        int snapshot_date_key FK
        int product_key FK
        int stock_quantity
        int reorder_level
        numeric stock_value
        boolean is_below_reorder
    }
    fact_supplier_orders {
        varchar purchase_order_id PK
        int supplier_key FK
        int product_key FK
        int order_date_key FK
        int expected_delivery_date_key FK
        int quantity
        numeric unit_cost
        numeric total_cost
        varchar order_status
    }
    dim_date {
        int date_key PK "YYYYMMDD"
        date full_date
        varchar day_name
        smallint month
        smallint quarter
        smallint year
    }
    dim_customer {
        serial customer_key PK
        int customer_id "business key"
        varchar country
    }
    dim_product {
        serial product_key PK
        varchar product_id "business key"
        varchar product_description
        numeric list_price
        int reorder_level
        boolean is_non_product
    }
    dim_supplier {
        serial supplier_key PK
        varchar supplier_id "business key"
    }
    dim_channel {
        smallint channel_key PK
        varchar channel_name "POS / E-Commerce"
    }
```

## 3. Tables

| Table | Type | Grain (one row = …) | Source (Silver) | Rows |
|---|---|---|---|---|
| dim_date | Dimension | one calendar day | generated from min–max dates in all sources | 5,806* |
| dim_customer | Dimension | one customer | silver.customers | 323 + Unknown |
| dim_product | Dimension | one product | silver.products | 1,988 + Unknown |
| dim_supplier | Dimension | one supplier | silver.supplier_orders | 80 + Unknown |
| dim_channel | Dimension | one sales channel | fixed values | 2 |
| fact_sales | Fact | one sales line (POS or online) | silver.sales_pos + silver.sales_ecommerce | 14,755 |
| fact_inventory_snapshot | Fact (periodic snapshot) | one product's stock on the load date | silver.products | 1,982 |
| fact_supplier_orders | Fact | one purchase order | silver.supplier_orders | 2,000 |

\* dim_date grows with the run date, because the snapshot date is "today".

## 4. Design decisions
- **Surrogate keys** (`*_key`) in every dimension; source IDs are kept as business keys for lineage.
- **Unknown member (key = -1)** in every dimension. Sales without a customer (2,291 POS + 1,141 online lines) point to customer −1 instead of NULL, so no fact row is lost.
- **One fact_sales for both channels** with `dim_channel`, so store and online sales can be compared directly.
- **Cancellations and returns are kept and flagged** (`is_cancelled`, `is_return`), not deleted, so refunds can be reported. KPI queries filter them out.
- **Non-product codes** (POST, DOT, C2, M, D, BANK CHARGES) are flagged `is_non_product` and excluded from product KPIs.
- **No store or warehouse dimension:** the UC3 source files do not contain store or warehouse identifiers.
- **Lineage columns:** `fact_sales.source_system` + `source_line_id` point back to the Silver row; Silver keeps `source_file`.
