# Data Exploration Summary

## 1. Overview
The analysis uses the Olist Brazilian E-Commerce Public Dataset. Seven of the
nine tables are used. Across all order statuses, order dates range from
September 2016 to October 2018, but delivered orders end in August 2018.
After exclusions, 96,470 delivered orders with a recorded delivery date are
analyzed.

## 2. Table Inventory
| Table | Rows | Key columns | Used in analysis |
|---|---|---|---|
| orders | 99,441 | order_id | Yes: delivery dates, status |
| customers | 99,441 | customer_id | Yes: customer state |
| order_items | 112,650 | order_id + order_item_id | Yes: link to seller and product |
| order_reviews | 99,224 | order_id (review_id is not unique) | Yes: review score |
| products | 32,951 | product_id | Yes: product category |
| sellers | 3,095 | seller_id | Yes: seller identification |
| product_category_translation | 73 | product_category_name | Yes: English category names |
| geolocation | not loaded | | No: not needed for the core questions |
| order_payments | not loaded | | No: outside the scope of the delivery analysis |

## 3. Data Quality Findings
| # | Finding | Impact on analysis | Decision |
|---|---|---|---|
| 1 | 2,963 orders are not delivered, and 8 delivered orders have no delivery date; 6 canceled orders do have one | Cannot be classified reliably as late or on time | Filter on delivered status and a non-null delivery date |
| 2 | Estimated delivery dates are recorded at midnight | Comparing full timestamps would overstate late orders | "Late" is based on calendar dates |
| 3 | 298 orders took more than 60 days to deliver (maximum 210) | Can pull the average delivery time upward | Kept as valid; median reported alongside the average |
| 4 | 525 delivered orders have more than one review; review_id is not unique | Joining would duplicate order rows | order_id is the key; latest review kept, one row per order |
| 5 | 1,275 orders involve more than one seller and 723 more than one category | Seller and category groups overlap slightly | Counted once per group; overlap documented |
| 6 | 1,392 delivered orders have products without a category name | Cannot be assigned to a category | Reported as "Uncategorized" |
| 7 | Two categories had no English translation | Raw Portuguese names would appear in reports | Translated manually; duplicates created by mistake were removed |
| 8 | Delivered orders are almost absent before 2017 and end in August 2018 | Monthly trends are unreliable outside this window | Trend analysis covers January 2017 to August 2018 |
| 9 | 1,350 orders have a carrier date before the approval date, and 23 have a delivered date before the carrier date | None: these dates are not used in any KPI | Documented only; excluding the 23 orders does not change the late rate (6.77%) |
| 10 | The imported tables have no keys or indexes | Joins were very slow | Indexes created on join columns |

## 4. Implications for the Analysis
- Delivery metrics are calculated on delivered orders with a delivery date only.
- Seller and category analysis covers all delivered orders, because every
  delivered order has at least one item and all joins are free of orphan rows.
- Seller and category results describe association, not cause, because
  delivery dates exist only at the order level.

## 5. Columns Not Used
- Product dimensions and weight, product description fields, and review
  comment text: not needed to answer the business questions.
- Approval and carrier dates: not used in any KPI.
- City and zip code columns: the analysis is done at state level.
