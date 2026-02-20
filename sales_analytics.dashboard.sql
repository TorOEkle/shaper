SELECT 'Ekles shaper test'::SECTION;
CREATE TEMP TABLE customers AS (
    SELECT * FROM delta_scan('/home/toekle/delta-demo-data/customers')
);

CREATE TEMP TABLE orders AS (
    SELECT * FROM delta_scan('/home/toekle/delta-demo-data/orders')
);

CREATE TEMP TABLE sales AS (
    SELECT
        o.*,
        c.region,
        c.segment,
        c.state,
        c.city
    FROM orders o
    JOIN customers c USING (customer_id)
);

-- filters --
SELECT
    min(order_date::DATE)::DATE::DATEPICKER_FROM AS order_date,
    max(order_date::DATE)::DATE::DATEPICKER_TO   AS order_date
FROM sales;

SELECT 'Region'::LABEL;
SELECT region::DROPDOWN_MULTI AS region
FROM sales GROUP BY region ORDER BY region;

SELECT 'Segment'::LABEL;
SELECT segment::DROPDOWN_MULTI AS segment
FROM sales GROUP BY segment ORDER BY segment;

SELECT 'Category'::LABEL;
SELECT category::DROPDOWN_MULTI AS category
FROM sales GROUP BY category ORDER BY category;

SELECT 'Order Status'::LABEL;
SELECT status::DROPDOWN_MULTI AS status
FROM sales GROUP BY status ORDER BY status;




CREATE TEMP TABLE dataset AS
WITH bounds AS (
    SELECT
        min(order_date::DATE) AS min_date,
        max(order_date::DATE) AS max_date
    FROM sales
)
SELECT s.*
FROM sales s
CROSS JOIN bounds b
WHERE s.region   IN getvariable('region')
  AND s.segment  IN getvariable('segment')
  AND s.category IN getvariable('category')
  AND s.status   IN getvariable('status')
  AND s.order_date::DATE BETWEEN
      coalesce(getvariable('order_date_from'), b.min_date)
  AND coalesce(getvariable('order_date_to'),   b.max_date);

SELECT ''::SECTION;

SELECT round(sum(revenue), 0)                             AS "Total Revenue ($)"  FROM dataset;
SELECT round(sum(profit),  0)                             AS "Total Profit ($)"   FROM dataset;
SELECT round(sum(profit) / sum(revenue) * 100, 1)         AS "Profit Margin (%)"  FROM dataset;
SELECT count(DISTINCT order_id)                           AS "Total Orders"       FROM dataset;
SELECT count(DISTINCT customer_id)                        AS "Unique Customers"   FROM dataset;
SELECT round(avg(discount) * 100, 1)                      AS "Avg Discount (%)"   FROM dataset;


-- ── Revenue & Profit over time ────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Monthly Revenue & Profit'::LABEL;
SELECT
    date_trunc('month', order_date::DATE)::XAXIS AS "Month",
    round(sum(revenue), 2)::LINECHART            AS "Revenue",
    round(sum(profit),  2)::LINECHART            AS "Profit",
FROM dataset GROUP BY ALL ORDER BY ALL;

-- ── Revenue by Region & Segment ───────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Revenue by Region'::LABEL;
SELECT
    region::XAXIS                    AS "Region",
    round(sum(revenue), 2)::BARCHART AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY "Revenue" DESC;

SELECT 'Revenue by Segment'::LABEL;
SELECT
    segment::XAXIS                   AS "Segment",
    round(sum(revenue), 2)::BARCHART AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY "Revenue" DESC;

-- ── Revenue by Category & Subcategory ────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Revenue by Category'::LABEL;
SELECT
    category::XAXIS                  AS "Category",
    round(sum(revenue), 2)::BARCHART AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY "Revenue" DESC;

SELECT 'Revenue by Subcategory'::LABEL;
SELECT
    subcategory::XAXIS               AS "Subcategory",
    round(sum(revenue), 2)::BARCHART AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY "Revenue" DESC;

-- ── Stacked over time ─────────────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Quarterly Revenue by Category'::LABEL;
SELECT
    date_trunc('quarter', order_date::DATE)::XAXIS AS "Quarter",
    category::CATEGORY,
    round(sum(revenue), 2)::BARCHART_STACKED       AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY ALL;

SELECT 'Quarterly Revenue by Segment'::LABEL;
SELECT
    date_trunc('quarter', order_date::DATE)::XAXIS AS "Quarter",
    segment::CATEGORY,
    round(sum(revenue), 2)::BARCHART_STACKED       AS "Revenue",
FROM dataset GROUP BY ALL ORDER BY ALL;

-- ── Discount analysis ─────────────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Avg Discount by Category Over Time'::LABEL;
SELECT
    date_trunc('quarter', order_date::DATE)::XAXIS AS "Quarter",
    category::CATEGORY,
    round(avg(discount) * 100, 1)::LINECHART       AS "Avg Discount (%)",
FROM dataset GROUP BY ALL ORDER BY ALL;

SELECT 'Revenue vs Discount Rate by Subcategory'::LABEL;
SELECT
    subcategory                                         AS "Subcategory",
    round(sum(revenue), 2)                              AS "Revenue ($)",
    round(avg(discount) * 100, 1)                       AS "Avg Discount (%)",
    round(sum(profit) / sum(revenue) * 100, 1)          AS "Profit Margin (%)",
FROM dataset
GROUP BY ALL
ORDER BY "Revenue ($)" DESC;

-- ── Order status ──────────────────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Orders by Status'::LABEL;
SELECT
    status::XAXIS                       AS "Status",
    count(DISTINCT order_id)::BARCHART  AS "Orders",
FROM dataset GROUP BY ALL ORDER BY "Orders" DESC;

SELECT 'Revenue by Order Status'::LABEL;
SELECT
    status::XAXIS                    AS "Status",
    round(sum(revenue), 2)::BARCHART AS "Revenue ($)",
FROM dataset GROUP BY ALL ORDER BY "Revenue ($)" DESC;

-- ── Top states ────────────────────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Top 20 States by Revenue'::LABEL;
SELECT
    state                        AS "State",
    round(sum(revenue), 2)       AS "Revenue ($)",
    round(sum(profit),  2)       AS "Profit ($)",
    count(DISTINCT customer_id)  AS "Customers",
    count(DISTINCT order_id)     AS "Orders",
FROM dataset
GROUP BY ALL
ORDER BY "Revenue ($)" DESC
LIMIT 20;

-- ── Full summary table ────────────────────────────────────────────────────────

SELECT ''::SECTION;

SELECT 'Summary by Category & Subcategory'::LABEL;
SELECT
    category                                            AS "Category",
    subcategory                                         AS "Subcategory",
    count(DISTINCT order_id)                            AS "Orders",
    round(sum(quantity), 0)                             AS "Units Sold",
    round(sum(revenue), 2)                              AS "Revenue ($)",
    round(sum(profit),  2)                              AS "Profit ($)",
    round(sum(profit) / sum(revenue) * 100, 1)          AS "Margin (%)",
    round(avg(discount) * 100, 1)                       AS "Avg Discount (%)",
FROM dataset
GROUP BY ALL
ORDER BY "Revenue ($)" DESC;

-- ── Export ────────────────────────────────────────────────────────────────────

SELECT ('sales-export-' || today())::DOWNLOAD_CSV AS "Export to CSV";
SELECT * FROM dataset;
