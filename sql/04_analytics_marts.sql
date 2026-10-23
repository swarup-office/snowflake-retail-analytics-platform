-- ==============================================================================
-- 04_analytics_marts.sql
-- Northstar Retail: Business Analytics Data Marts & Reporting Views
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA MARTS;

-- 1. Daily Sales Summary View
CREATE OR REPLACE VIEW VW_DAILY_SALES AS
SELECT
    DATE(o.order_timestamp) AS order_date,
    o.shipping_state,
    p.category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(i.quantity) AS units_sold,
    SUM(i.line_total) AS revenue
FROM RETAIL_ANALYTICS.CORE.FACT_ORDERS o
JOIN RETAIL_ANALYTICS.CORE.FACT_ORDER_ITEMS i
    ON o.order_id = i.order_id
JOIN RETAIL_ANALYTICS.CORE.DIM_PRODUCTS p
    ON i.product_id = p.product_id
GROUP BY 1, 2, 3;

-- 2. Customer Lifetime Value (LTV) View
CREATE OR REPLACE VIEW VW_CUSTOMER_LTV AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.state,
    COUNT(DISTINCT o.order_id) AS order_count,
    COALESCE(SUM(o.order_total), 0) AS lifetime_value,
    MAX(o.order_timestamp) AS most_recent_order
FROM RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS c
LEFT JOIN RETAIL_ANALYTICS.CORE.FACT_ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY 1, 2, 3, 4;

-- 3. Practice and Validation Analytics Queries

-- Top Daily Sales Performance
SELECT 
    order_date,
    shipping_state,
    category,
    total_orders,
    units_sold,
    revenue
FROM VW_DAILY_SALES
ORDER BY revenue DESC;

-- High-Value Customers by LTV
SELECT 
    customer_id,
    first_name,
    last_name,
    state,
    order_count,
    lifetime_value,
    most_recent_order
FROM VW_CUSTOMER_LTV
ORDER BY lifetime_value DESC;

-- Regional Sales Summary
SELECT 
    shipping_state,
    SUM(revenue) AS total_state_revenue,
    SUM(units_sold) AS total_units_sold
FROM VW_DAILY_SALES
GROUP BY shipping_state
ORDER BY total_state_revenue DESC;
