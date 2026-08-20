# Project Charter

## 1. Project Overview

| Field | Details |
|---|---|
| Project Name | Enterprise Retail Data Platform (ERDP) |
| Project Code | UC3 |
| Organization | ABC Retail Ltd. |
| Project Type | Enterprise Data Engineering Capstone Project |
| Methodology | Agile Scrum |
| Team Size | 3 Members |
| Primary Technologies | Pentaho, PostgreSQL, Python (Pandas), Git & GitHub, Power BI |

## 2. Project Purpose

The purpose of the Enterprise Retail Data Platform is to integrate heterogeneous retail and e-commerce data sources into a structured enterprise data platform.

The platform will progressively ingest, validate, cleanse, transform, store, govern, and analyze retail data to support sales analytics, inventory optimization, customer insights, and executive reporting.

## 3. Project Objectives

The project aims to:

1. Collect retail and e-commerce data from multiple heterogeneous enterprise systems.
2. Clean, validate, and standardize transactional and customer data.
3. Store curated datasets in a PostgreSQL Data Warehouse.
4. Maintain metadata, audit logs, and end-to-end data lineage.
5. Support sales analytics, inventory optimization, customer insights, and executive reporting.
6. Use Git and GitHub for collaborative version control.
7. Produce enterprise-standard technical documentation and sprint deliverables.

## 4. Project Scope

### In Scope

- Business requirements analysis
- Source system analysis
- Data source inventory
- Data Dictionary
- Multi-format data ingestion
- Pentaho ETL development
- PostgreSQL staging
- Data profiling and quality assessment
- Data cleansing and standardization
- Data warehouse development
- Metadata and lineage
- Power BI analytics
- Technical documentation
- Git/GitHub collaboration

### Out of Scope

- Production integration with ABC Retail's actual systems
- Real-time production data streaming
- Processing of enterprise-scale production volumes
- Confidential enterprise data
- Production cloud deployment
- Customer-facing application development

## 5. Key Stakeholders

- Store Managers
- Supply Chain Team
- Inventory Team
- Marketing Team
- Finance Team
- Executive Management
- Project Team

## 6. Major Deliverables

### Sprint 0

- Business Requirements Document
- Solution Architecture
- Git Repository
- Project Charter
- Product/Sprint Backlog

### Sprint 1

- Source Inventory
- Data Dictionary
- Raw Data Landing Zone
- Multi-format ingestion pipelines
- PostgreSQL staging tables
- Ingestion logging
- Exception handling

### Sprint 2

- Data profiling
- Data quality assessment
- Cleansing and standardization
- PostgreSQL warehouse
- Dimensional model
- SQL reporting

### Sprint 3

- Data lineage
- Metadata
- ETL orchestration
- Data validation
- Power BI dashboards
- Final documentation

## 7. Project Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Difficulty obtaining suitable datasets | High | Use manageable public and synthetic datasets |
| Inconsistent source formats | Medium | Define source schemas and Data Dictionary before ingestion |
| Data quality issues | High | Implement validation, profiling, and cleansing |
| ETL failures | High | Implement logging and exception handling |
| Team coordination issues | Medium | Use GitHub and clearly assigned sprint tasks |
| Limited development time | High | Prioritize sprint deliverables and maintain a backlog |

## 8. Team Responsibilities

The three team members will divide development responsibilities across source analysis, data preparation, ETL, database development, documentation, testing, and analytics.

Each team member will maintain their own GitHub contributions and be able to explain the tasks they completed during individual project reviews.

## 9. Definition of Done

A project task will be considered complete when:

- The required implementation or documentation is completed.
- The work is tested or reviewed by the team.
- Relevant files are committed to GitHub.
- The implementation follows the agreed repository structure.
- Required documentation is updated.
- The responsible team member can explain the work performed.

## 10. Project Success

The project will be considered successful when the required sprint deliverables are completed and the platform demonstrates a working flow from heterogeneous source data through ingestion and PostgreSQL staging toward curated analytical data.
