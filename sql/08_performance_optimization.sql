-- ==============================================================================
-- 08_performance_optimization.sql
-- Northstar Retail: Performance Tuning, Workload Tagging, and Micro-Partition Clustering
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA CORE;

-- 1. Enable Query Tagging for Workload Attribution & Cost Tracking
ALTER SESSION SET QUERY_TAG = 'retail_sales_dashboard';

-- Run a representative analytical query
SELECT
    DATE(o.order_timestamp) AS order_date,
    o.shipping_state,
    SUM(o.order_total) AS total_sales,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM RETAIL_ANALYTICS.CORE.FACT_ORDERS o
WHERE o.order_timestamp >= '2026-01-01'
GROUP BY 1, 2
ORDER BY total_sales DESC;

-- Reset Query Tag
ALTER SESSION UNSET QUERY_TAG;

-- 2. Inspect Query History via SNOWFLAKE.ACCOUNT_USAGE
SELECT
    query_id,
    query_text,
    warehouse_name,
    warehouse_size,
    total_elapsed_time / 1000 AS execution_seconds,
    bytes_scanned,
    rows_produced,
    compilation_time,
    execution_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag = 'retail_sales_dashboard'
ORDER BY start_time DESC
LIMIT 10;

-- 3. Define Explicit Clustering Keys on Large Fact Tables
-- Co-locating data by date and shipping_state maximizes micro-partition pruning.
ALTER TABLE RETAIL_ANALYTICS.CORE.FACT_ORDERS
CLUSTER BY (TO_DATE(order_timestamp), shipping_state);

-- Evaluate clustering depth and partition distribution
SELECT SYSTEM$CLUSTERING_INFORMATION('RETAIL_ANALYTICS.CORE.FACT_ORDERS');

-- 4. Warehouse Sizing & Query Benchmark Test
-- Benchmark on XSMALL
USE WAREHOUSE RETAIL_ANALYTICS_WH; -- XSMALL
SELECT 
    p.category, 
    SUM(i.line_total) AS category_revenue, 
    AVG(i.quantity) AS avg_qty_per_order
FROM RETAIL_ANALYTICS.CORE.FACT_ORDER_ITEMS i
JOIN RETAIL_ANALYTICS.CORE.DIM_PRODUCTS p ON i.product_id = p.product_id
JOIN RETAIL_ANALYTICS.CORE.FACT_ORDERS o ON i.order_id = o.order_id
WHERE o.order_timestamp >= '2026-01-01'
GROUP BY p.category;

-- Benchmark on SMALL
USE WAREHOUSE RETAIL_TRANSFORM_WH; -- SMALL
SELECT 
    p.category, 
    SUM(i.line_total) AS category_revenue, 
    AVG(i.quantity) AS avg_qty_per_order
FROM RETAIL_ANALYTICS.CORE.FACT_ORDER_ITEMS i
JOIN RETAIL_ANALYTICS.CORE.DIM_PRODUCTS p ON i.product_id = p.product_id
JOIN RETAIL_ANALYTICS.CORE.FACT_ORDERS o ON i.order_id = o.order_id
WHERE o.order_timestamp >= '2026-01-01'
GROUP BY p.category;
