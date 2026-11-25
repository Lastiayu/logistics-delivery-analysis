# Problem Statement: Delivery Performance Analysis

## 1. Business Context

The company is an online marketplace that connects independent sellers with
customers. Orders are shipped from sellers to customers through logistics
partners, so delivery performance is a key part of the customer experience.
Each order is given an estimated delivery date at purchase, and customers
expect to receive their order by that date.

## 2. Problem

Some orders are delivered after their estimated delivery date. In this
analysis, an order is defined as **late** when its delivered date is later
than its estimated delivery date, comparing calendar dates only. In the data
analyzed, 6.77% of delivered orders (6,534 of 96,470) arrived late. Late
deliveries may reduce customer satisfaction and increase the risk of negative
reviews, but the relationship with review scores has not yet been measured.

The business currently lacks a clear view of where delays are concentrated
and which factors are associated with them. Without this, it is difficult to
decide where to focus improvement efforts.

## 3. Stakeholder

The primary stakeholder is the Operations Manager (a hypothetical role for
this case study), who needs to decide which regions, sellers, or product
categories should be prioritized for delivery improvement.

## 4. Goal and Scope

**Goal:** Measure the late delivery rate, identify where delays are most
concentrated, and assess how late delivery relates to customer review scores,
in order to provide data-backed recommendations for prioritizing improvements.

**In scope:**
- Delivery performance of delivered orders only
- Late delivery patterns by customer state, seller, and product category
- Relationship between late delivery and review scores
- Change in the late delivery rate over time

**Out of scope:**
- Orders that are not delivered, and delivered orders without a recorded
  delivery date (lateness cannot be determined)
- Carrier-level analysis (carrier information is not available in the data)
- Payment analysis (not needed to answer the core delivery questions)
- Predictive modeling (this analysis is descriptive)

## 5. Data Source

The analysis uses the Olist Brazilian E-Commerce Public Dataset from Kaggle,
a public and anonymized dataset of orders placed on a Brazilian marketplace.
Orders were placed between September 2016 and October 2018 across all
statuses; delivered orders cover September 2016 to August 2018.

Seven of the nine tables are used: `orders`, `customers`, `order_items`,
`order_reviews`, `products`, `sellers`, and `product_category_translation`.
Two tables are excluded in this version:
- `geolocation`: not needed for the core questions and contains many
  duplicate zip code entries
- `order_payments`: payment data is outside the scope of the delivery
  analysis

Two product categories had no English translation in the original data and
were translated manually.

**Note:** Because the data comes from a Brazilian marketplace, findings
describe this dataset and may not generalize to other markets.
