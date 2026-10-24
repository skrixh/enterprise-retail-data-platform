# Validation & Reconciliation Report – ERDP

**Sprint 3 deliverable** · Script: `sql/07_validation_reconciliation.sql` · Run after: `pentaho/jobs/j_erdp_master.kjb`

## 1. Purpose
Prove that the data in the Gold warehouse is complete and correct compared with the five source files, and that every difference is explained by a documented cleaning rule.

## 2. Result summary

| Category | Checks | Passed | Failed |
|---|---|---|---|
| Row counts (Bronze → Silver → Gold) | 9 | 9 | 0 |
| Sales reconciliation (value and units) | 4 | 4 | 0 |
| Inventory reconciliation | 1 | 1 | 0 |
| Financial reconciliation (purchases) | 1 | 1 | 0 |
| Referential integrity | 4 | 4 | 0 |
| Uniqueness of dimension keys | 2 | 2 | 0 |
| **Total** | **21** | **21** | **0** |

## 3. Row-count reconciliation

| Source | Bronze (raw) | Removed in Silver | Silver | Gold | Reason for difference |
|---|---|---|---|---|---|
| POS | 10,000 | 196 | 9,804 | 9,804 (fact_sales, channel POS) | Exact duplicate rows |
| E-commerce | 5,000 | 49 | 4,951 | 4,951 (fact_sales, channel E-Commerce) | Exact duplicate rows |
| CRM | 323 | 0 | 323 | 323 (+1 Unknown) dim_customer | — |
| Inventory | 2,015 | 27 | 1,988 | 1,988 (+1 Unknown) dim_product; 1,982 in fact_inventory_snapshot | 27 upper/lower-case product codes merged; 6 non-product codes excluded from the stock snapshot |
| Supplier | 2,000 | 0 | 2,000 | 2,000 fact_supplier_orders | — |

## 4. Sales reconciliation

| Channel | Bronze value (£) | Gold value (£) | Difference (£) | Value of duplicates removed (£) | Status |
|---|---|---|---|---|---|
| POS | 180,667.75 | 179,948.55 | 719.20 | 719.20 | ✅ Explained |
| E-Commerce | 97,398.41 | 97,175.33 | 223.08 | 223.08 | ✅ Explained |

Silver → Gold: value and units match exactly (POS £179,948.55 / 77,896 units; E-com £97,175.33 / 45,239 units).

> Values include cancellations and returns (negative amounts), so they reconcile with the raw files. KPI queries exclude cancelled, returned, zero-price and non-product lines.

## 5. Inventory reconciliation
Total stock units of real products: **Bronze 500,713 = Gold 500,713** ✅. The 27 case-duplicate products were merged by adding their stock, so no units were lost.

## 6. Financial reconciliation (purchases)
Total purchase value (quantity × unit cost): **Bronze £918,846.09 = Gold £918,846.09** ✅.

## 7. Referential integrity and uniqueness
- 0 sales lines with an unknown date or product.
- 0 sales lines whose customer ID exists in the source but is missing from `dim_customer`.
- 0 supplier orders with an unknown supplier or product.
- 0 duplicate business keys in `dim_product` and `dim_customer`.
- Sales without a customer ID (2,291 POS + 1,141 e-commerce lines) are linked to the **Unknown customer (key −1)** by design, not lost.

## 8. Known data gaps (not errors)
| Gap | Impact | Recommendation |
|---|---|---|
| No actual delivery date in supplier orders | Supplier **on-time delivery %** cannot be calculated; only expected lead time and order status are available | Request goods-receipt dates from the supplier portal |
| No store or warehouse identifiers in the sources | No store-level or warehouse-fulfilment KPIs | Add WMS / store master data in a future release |
| Inventory has a single snapshot (no history) | Inventory turnover uses one stock level as the average | Schedule the master job daily to build snapshot history |

## 9. How to re-run
1. Run `j_erdp_master.kjb` in Spoon.
2. In pgAdmin, run `sql/07_validation_reconciliation.sql`.
3. All 21 rows must show **PASS**; the second result table explains the Bronze-vs-Gold sales difference.
