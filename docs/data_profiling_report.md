# Data Profiling Report — Sprint 2

>> Enterprise Retail Data Platform (ERDP)

# 1. POS Transactions (10,000 rows)

* 130 records had negative quantities, which may be due to returns or cancellations.
* 46 records had zero or negative unit prices, which may be data entry errors.

# 2. Ecommerce Orders (5,000 rows)

* 1,141 records (22.8%) had missing customer_id, mainly due to guest checkouts.
* 65 records had negative quantities, which may represent returns.

# 3. Customers (323 rows)

* No major data quality issues were found.
* This table contains only a subset of customers referenced in the transaction data, as provided in the source.

# 4. Inventory (2,015 rows)

* No negative stock values were found.
* 261 items were below their reorder level and were flagged for replenishment.

# 5. Supplier Orders (2,000 rows)

* In Transit: 697
* Delivered: 661
* Pending: 642
* No missing or invalid values were found.

# 6. Referential Integrity Checks

* POS customer_ids not found in Customers: **0**
* Ecommerce customer_ids not found in Customers: **0**
* Supplier product_ids not found in Inventory: **0**

Summary

The five datasets were profiled using Python and pandas. Overall, the data was found to be in good condition, and all referential integrity checks passed. The main issues were missing customer IDs in ecommerce orders and a small number of negative quantity or price values. These issues were reviewed and the proposed handling rules are included in the Data Quality Report.
