# Business Questions and KPIs

## 1. Business Questions

| # | Question | KPIs | Decision it informs |
|---|---|---|---|
| Q1 | What share of delivered orders arrive after the estimated delivery date? | KPI 1, 2, 3, 4 | Whether late delivery is large enough to prioritize |
| Q2 | Which customer states have the highest late delivery rate? | KPI 1, 4 | Which regions to prioritize for delivery improvement |
| Q3 | Which sellers and product categories are most associated with late delivery? | KPI 1, 4 | Which sellers and categories to review first |
| Q4 | Are late deliveries associated with lower review scores? | KPI 5 | How much customer satisfaction is at stake |
| Q5 | How has the late delivery rate changed over time? | KPI 1, 3 | Whether the situation is improving or worsening, and whether it is seasonal |

## 2. KPI Definitions

All KPIs follow the definition of "late" and the calculation rules in Section 3.

**KPI 1: Late Delivery Rate**

| Field | Description |
|---|---|
| Definition | Share of delivered orders that arrived after the estimated delivery date |
| Formula | Late delivered orders ÷ delivered orders with a delivery date × 100 |
| Unit | Percentage (%) |
| Source columns | `orders.order_delivered_customer_date`, `orders.order_estimated_delivery_date`, `orders.order_status` |
| Filter | Only orders with status `delivered` and a non-null delivery date |
| Notes | "Late" is defined in Section 3.2 |

**KPI 2: On-Time Delivery Rate**

| Field | Description |
|---|---|
| Definition | Share of delivered orders that arrived on or before the estimated delivery date |
| Formula | On-time delivered orders ÷ delivered orders with a delivery date × 100 |
| Unit | Percentage (%) |
| Source columns | Same as KPI 1 |
| Filter | Same as KPI 1 |
| Notes | Always equals 100% − Late Delivery Rate, so the two must add up |

**KPI 3: Average Delivery Days**

| Field | Description |
|---|---|
| Definition | Average time from purchase to delivery |
| Formula | Average of (delivered date − purchase date), in whole calendar days |
| Unit | Days |
| Source columns | `orders.order_purchase_timestamp`, `orders.order_delivered_customer_date` |
| Filter | Delivered orders with a non-null delivery date |
| Notes | Extreme values are retained; see Section 3.3 |

**KPI 4: Average Delay Days**

| Field | Description |
|---|---|
| Definition | Average number of days late, among late orders only |
| Formula | Average of (delivered date − estimated date), in whole calendar days, for late orders |
| Unit | Days |
| Source columns | `orders.order_delivered_customer_date`, `orders.order_estimated_delivery_date` |
| Filter | Late delivered orders only |
| Notes | On-time orders are excluded; otherwise early deliveries would offset the real delays |

**KPI 5: Average Review Score**

| Field | Description |
|---|---|
| Definition | Average customer rating on a 1 to 5 scale, compared between late and on-time orders |
| Formula | Average of `review_score`, calculated separately for late and on-time orders |
| Unit | Score (1 to 5) |
| Source columns | `order_reviews.review_score`, joined to `orders` by `order_id` |
| Filter | Delivered orders that have a review, using one review per order (Section 3.5) |
| Notes | Not every order has a review, and some have more than one |

## 3. Analytical Decisions and Assumptions

### 3.1 Orders Included
The dataset has 99,441 orders. Of these, 96,478 have status `delivered`, and
96,470 of them have a recorded delivery date. Only these 96,470 orders are
used to calculate delivery metrics. The remaining 2,971 orders (about 3.0%)
are excluded: 2,963 orders that are not delivered and 8 delivered orders with
no delivery date. Six canceled orders do have a delivery date; they are also
excluded because their status is not `delivered`. Monthly analysis is based
on the order purchase date.

### 3.2 Definition of "Late"
An order is late when its delivered date is after its estimated delivery date,
comparing calendar dates only; time of day is ignored. An order delivered on
the estimated date is on time.

- **Reason:** all estimated delivery dates are recorded at 00:00:00 (verified:
  0 exceptions), so comparing full timestamps would classify orders delivered
  later in the day as late, even though they met the promised date.
- **Implementation:** `DATE(order_delivered_customer_date) >
  DATE(order_estimated_delivery_date)`
- **Result:** 6,534 of 96,470 orders are late (6.77%).

### 3.3 Delivery Days and Delay Days
Both are calculated as whole calendar days between dates, consistent with the
date-based definition of "late". Delivery times range from 0 to 210 days, with
no negative values. 298 orders (about 0.31%) took more than 60 days. These
are retained because they are valid recorded deliveries and part of the late
delivery problem.

### 3.4 Unit of Analysis
One row = one order for all metrics. For seller and category analysis, orders
are counted using distinct order IDs.

- **Reason:** a single definition of Late Delivery Rate keeps all results
  comparable.
- **Consequence:** an order involving more than one seller or product category
  is counted once under each of them, so groups overlap slightly. Among the
  96,478 delivered orders, 1,275 (about 1.32%) involve more than one seller
  and 723 (about 0.75%) involve more than one product category, so the
  impact is limited.

### 3.5 Reviews
- **Multiple reviews per order:** 525 of 96,478 delivered orders (about 0.54%)
  have more than one review (521 with two reviews, 4 with three). To keep one
  row per order, the most recent review is used (by review creation date, then
  answer timestamp).
  Reason: the latest review best reflects the customer's final impression.
- **Orders without reviews:** 646 delivered orders (about 0.67%) have no
  review and are excluded from review score analysis only. Late Delivery
  Rate is calculated on all delivered orders.

### 3.6 Product Categories
- Orders whose products have no category name (1,392 orders, about 1.4%) are
  reported separately as "Uncategorized".
- Category names are translated to English using the translation table. Two
  categories, `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos`,
  are missing from it. They were translated manually and are marked as such;
  both have fewer than 100 delivered orders (7 and 13) and are therefore not
  ranked.

### 3.7 Minimum Sample Size
Rates calculated from small groups are unstable: a few late orders can change
the result significantly. Rates are therefore ranked or compared only for
groups with a minimum number of delivered orders. Thresholds differ by
dimension because the groups differ greatly in size.

| Dimension | Minimum delivered orders | Groups meeting the threshold | Coverage of delivered orders | Handling of smaller groups |
|---|---|---|---|---|
| Seller | 50 | 425 of 2,970 sellers | about 77% (73,980 of 96,478)* | Not ranked; reported separately |
| Customer state | 100 | 24 of 27 states | about 99.8% (RR, AP, AC excluded: 188 orders) | Shown as "low sample", not ranked |
| Product category | 100 | 51 of 73 categories | about 97.7% (22 small categories: 837 orders; uncategorized: 1,392 orders)* | Not ranked; reported separately |
| Month (trend) | 500 | 20 of 23 months | about 99.7% (96,211 of 96,478) | Excluded from trend charts, kept in overall metrics |

*Approximate: an order involving more than one seller or product category is
counted under each of them (see Section 3.4).

**Rationale**
- **Sellers (50):** most sellers are small. At a threshold of 30, 627 sellers
  remain (about 85% coverage), but rates are too unstable; at 100, only 210
  sellers remain (about 61% coverage). A threshold of 50 keeps a usable list
  of sellers while covering most orders.
- **States (100):** only four states have fewer than 200 delivered orders
  (RR: 41, AP: 67, AC: 80, AM: 145). Excluding RR, AP, and AC from rankings
  costs about 0.2% of orders.
- **Product categories (100):** category sizes are concentrated, so the
  threshold removes 22 small categories at a cost of under 1% of orders.
- **Months (500):** the first months of the dataset have very low volume
  (2016-09: 1 order, 2016-10: 265, 2016-12: 1) and there are no delivered
  orders in November 2016, so monthly trend analysis starts in January 2017.
  Delivered orders end in August 2018, although order dates across all
  statuses extend to October 2018. The trend therefore covers January 2017
  to August 2018 (20 months).

**Statistical note:** the uncertainty of a rate depends on group size. As a
rough guide, the margin of error of a proportion is about
1.96 × √(p × (1 − p) / n), where p is the rate and n is the number of orders.
With the overall late rate of 6.77%, a group of 50 orders has a margin of
error of about 7.0 percentage points and a group of 100 orders about 4.9
percentage points. This is an approximation and is less reliable for very
small groups or rare events.

**Reporting rules**
- Groups below the threshold are never hidden silently: the number of
  excluded groups and orders is reported next to each ranking.
- Rankings by late rate are shown together with order counts, so readers can
  see the size behind each rate.

## 4. Known Limitations
- Results show association, not cause: the data cannot show why a delivery
  was late.
- Delivery dates are recorded at the order level, so for orders with multiple
  sellers the data cannot show which seller caused a delay.
- Review analysis covers delivered orders that have a review (about 99.3% of
  delivered orders); the small share without a review is not represented.
- Groups below the minimum sample size are not ranked, so very small sellers,
  states, and categories are not covered by the rankings.
- Trends before January 2017 are not analyzed because of very low order
  volume, and delivered orders are available only until August 2018.
- The data comes from a Brazilian marketplace between 2016 and 2018 and may
  not generalize to other markets or periods.
