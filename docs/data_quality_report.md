DATA QUALITY REPORT – SPRINT 2

1. Purpose

This report contains the data quality issues found while checking the retail datasets. The main purpose of this step is to understand the problems in the data and decide how they should be handled before using the data for the data warehouse and reporting.

2. Datasets Checked

The following five datasets were checked:

1. Customers
2. Inventory
3. POS Transactions
4. E-commerce Orders
5. Supplier Orders

3. Data Quality Findings

3.1 POS Transactions

Total records checked: 10,000

The following issues were found:

• 130 records have negative quantity.
• 46 records have zero or negative price.

Negative quantity can occur because of product returns or cancelled transactions. These records should not be deleted because they are still part of the original transaction data.

Records with zero or negative prices will be marked as invalid when calculating sales or revenue. The original records will still be retained.

3.2 E-commerce Orders

Total records checked: 5,000

The following issues were found:

• 1,141 records have a missing customer_id.
• 65 records have negative quantity.

The missing customer_id values can occur when the customer is not identified during an order. These records will be handled as guest or unknown customers during the warehouse preparation.

Negative quantities will be treated as returns or cancellations. The original order records will not be deleted.

3.3 Inventory

Total records checked: 2,015

The inventory data was checked for negative stock and products that are below their reorder level.

The results were:

• Negative stock quantity: 0
• Products below reorder level: 261

There are no negative stock values, so no correction is required for this issue.

The 261 products below the reorder level will not be removed or changed. They are useful for inventory analysis because they indicate products that may need to be reordered.

3.4 Supplier Orders

Total records checked: 2,000

The supplier order status distribution was:

• In Transit: 697
• Delivered: 661
• Pending: 642

The status values will be kept consistent when the data is prepared for the warehouse.

No supplier order will be removed based only on its order status.

3.5 Customer Data

Customer data was also checked along with the transaction datasets.

The customer IDs were checked against the transaction data to make sure that the referenced customers exist.

No unnecessary customer records will be removed. Any missing or inconsistent customer details will be considered during the standardization stage.

4. Referential Integrity Check

The following checks were performed:

POS customer_id → Customers: 0 mismatches

E-commerce customer_id → Customers: 0 mismatches

Supplier product_id → Inventory: 0 mismatches

All the above checks returned zero mismatches. This shows that the customer and product references checked between the datasets are matching correctly.

5. Data Quality Actions

POS negative quantity – 130 records: These will be treated as return or cancellation transactions.

POS zero or negative price – 46 records: These will be marked as invalid for revenue calculations.

E-commerce missing customer_id – 1,141 records: These will be handled as guest or unknown customers.

E-commerce negative quantity – 65 records: These will be treated as return or cancellation transactions.

Inventory negative stock – 0 records: No action is required.

Inventory below reorder level – 261 records: These records will be retained because they provide useful information for inventory analysis.

Supplier order status – 2,000 records: Status values will be kept consistent during the standardization stage.

6. Original Data Retention

The original staging data will be kept as it is. The identified issues will be handled during the data preparation and standardization stage instead of directly changing the original source data. This will help us keep the original data available for reference and checking.

7. Next Step

The next step is to apply the required data quality and standardization rules and prepare the datasets for the Star Schema and PostgreSQL data warehouse.s