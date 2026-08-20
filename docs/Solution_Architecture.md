# Solution Architecture

## 1. Architecture Overview

The Enterprise Retail Data Platform (ERDP) will provide a structured data engineering pipeline for integrating heterogeneous retail data sources, ingesting raw data, storing it in PostgreSQL staging, and progressively transforming it into curated datasets for analytics.

The architecture follows a layered approach aligned with the project's Bronze–Silver–Gold repository organization.

## 2. High-Level Architecture

```text
                         ENTERPRISE SOURCE SYSTEMS
                                    |
             +----------------------+----------------------+
             |          |            |          |           |
             v          v            v          v           v
            POS    E-Commerce       CRM     Inventory    Supplier
            CSV       Excel         JSON       XML          SQL
             |          |            |          |           |
             +----------+------------+----------+-----------+
                                    |
                                    v
                         PENTAHO DATA INTEGRATION
                              (Spoon / ETL)
                                    |
                    +---------------+---------------+
                    |                               |
                    v                               v
              Ingestion Logs                 Exception Handling
                    |                               |
                    +---------------+---------------+
                                    |
                                    v
                          BRONZE / RAW LAYER
                                    |
                                    v
                         POSTGRESQL STAGING
                                    |
                                    v
                    +---------------+---------------+
                    |                               |
                    v                               v
             Python / Pandas                 Data Validation
                    |
                    v
             Data Profiling &
             Data Quality Assessment
                    |
                    v
                       SILVER / CURATED LAYER
                    |
                    v
              Cleansing & Transformations
                    |
                    v
                         GOLD LAYER
                    |
             +------+--------+------+
             |               |      |
             v               v      v
         Warehouse       Data Marts Analytics
             |               |      |
             +---------------+------+
                             |
                             v
                          POWER BI
                    Retail Analytics &
                    Executive Reporting
```

## 3. Source Layer

The source layer represents the heterogeneous enterprise systems identified for the project.

The initial implementation will represent the following sources:

| Source System                          | Format |
| -------------------------------------- | ------ |
| Point of Sale (POS)                    | CSV    |
| E-Commerce                             | Excel  |
| Customer Relationship Management (CRM) | JSON   |
| Inventory Management System            | XML    |
| Supplier Portal                        | SQL    |

These source systems represent the retail systems identified in the project scenario.

## 4. Ingestion Layer

Pentaho Data Integration (Spoon) will form the primary ingestion and ETL layer.

The ingestion layer will:

* Read data from the supported source formats.
* Extract data from the identified source systems.
* Perform required ingestion-level processing.
* Load raw data into the staging environment.
* Record ingestion activity through logging.
* Handle ingestion failures through exception handling.
* Support successful ingestion workflows for CSV, Excel, JSON, XML, and SQL sources.

## 5. Bronze / Raw Layer

The Bronze layer represents the raw data landing area.

Raw data received from the source systems will be retained in an ingestion-oriented structure before subsequent profiling, cleansing, and transformation activities.

The project repository contains:

```text
bronze/
├── ingestion/
└── staging/
```

## 6. PostgreSQL Staging Layer

PostgreSQL will be used to store the ingested raw data in staging tables.

Example staging tables include:

```text
stg_pos_transactions
stg_ecommerce_orders
stg_customers
stg_inventory
stg_supplier_orders
```

The exact table structures will be finalized after the source datasets and Data Dictionary are prepared.

## 7. Silver / Transformation Layer

The Silver layer will contain progressively processed and trusted data.

Activities planned for later sprints include:

* Data profiling
* Data quality assessment
* Data cleansing
* Data validation
* Standardization
* Transformations

Python with Pandas will be used for data profiling and data quality activities.

## 8. Gold / Analytics Layer

The Gold layer will contain curated datasets designed for business analytics.

The repository structure provides:

```text
gold/
├── warehouse/
├── datamarts/
└── analytics/
```

Later project activities will include designing the PostgreSQL data warehouse, creating fact and dimension tables, and preparing datasets for retail reporting.

## 9. Reporting Layer

Power BI will be used in later sprints to develop retail analytics and executive dashboards.

Potential business metrics identified in the project include:

* Daily Sales Revenue
* Top Selling Products
* Inventory Turnover Ratio
* Stock Availability
* Customer Retention Rate
* Average Order Value
* Supplier On-Time Delivery
* Regional Sales Performance
* Return & Refund Analysis
* Warehouse Fulfillment Efficiency

## 10. Governance and Version Control

Git and GitHub will be used throughout the project for collaborative development and version control.

The project will progressively maintain:

* Metadata
* Data lineage
* Source-to-target mappings
* Audit information
* Technical documentation
* Git commit history

## 11. Technology Mapping

| Architecture Component | Technology                       |
| ---------------------- | -------------------------------- |
| Data Ingestion / ETL   | Pentaho Data Integration (Spoon) |
| Database / Staging     | PostgreSQL                       |
| Data Profiling         | Python / Pandas                  |
| Version Control        | Git / GitHub                     |
| Reporting              | Power BI                         |
| Documentation          | Markdown / MS Word               |
| Project Methodology    | Agile Scrum                      |

## 12. Sprint Implementation

### Sprint 0

Sprint 0 establishes the business requirements, project scope, high-level architecture, repository structure, Git repository, project charter, and product/sprint backlog.

### Sprint 1

Sprint 1 implements the Retail Raw Data Landing Zone by analyzing source systems, preparing the Data Dictionary, developing ingestion pipelines for CSV, Excel, JSON, XML, and SQL data, loading raw data into PostgreSQL staging, implementing logging and exception handling, and committing the work to Git.

### Sprint 2

Sprint 2 will focus on data profiling, data quality, standardization, PostgreSQL warehouse design, dimensional modeling, and SQL-based reporting.

### Sprint 3

Sprint 3 will focus on data lineage, metadata, ETL orchestration, validation, Power BI dashboards, and final project documentation.

## 13. Architecture Outcome

The proposed architecture provides an end-to-end path from heterogeneous retail source systems to a curated analytics platform:

```text
Sources
   ↓
Pentaho Ingestion
   ↓
Bronze / Raw
   ↓
PostgreSQL Staging
   ↓
Profiling / Quality / Transformation
   ↓
Silver
   ↓
Warehouse / Data Marts
   ↓
Gold
   ↓
Power BI Analytics
```

This architecture will be progressively implemented across the project sprints rather than completed entirely during Sprint 0.

