-- ==============================================================================
-- 11_snowpark_udf_and_sproc.sql
-- Northstar Retail: Snowpark Python User Defined Function (UDF) & Stored Procedure
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_TRANSFORM_WH;
USE DATABASE RETAIL_ANALYTICS;

-- ==============================================================================
-- Part 1: Python UDF for Customer Spending Tier Segmentation
-- ==============================================================================

CREATE OR REPLACE FUNCTION RETAIL_ANALYTICS.CORE.CUSTOMER_TIER(
    lifetime_value FLOAT
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'customer_tier'
COMMENT = 'Categorizes customers into Platinum, Gold, Silver, Bronze tiers based on LTV'
AS
$$
def customer_tier(lifetime_value):
    if lifetime_value is None:
        return "NO_PURCHASES"
    elif lifetime_value >= 5000:
        return "PLATINUM"
    elif lifetime_value >= 2000:
        return "GOLD"
    elif lifetime_value >= 500:
        return "SILVER"
    else:
        return "BRONZE"
$$;

-- Test the Python UDF
SELECT
    customer_id,
    first_name,
    last_name,
    state,
    lifetime_value,
    RETAIL_ANALYTICS.CORE.CUSTOMER_TIER(lifetime_value) AS customer_segment
FROM RETAIL_ANALYTICS.MARTS.VW_CUSTOMER_LTV
ORDER BY lifetime_value DESC;

-- ==============================================================================
-- Part 2: Snowpark Stored Procedure for Automated Table Refresh
-- ==============================================================================

CREATE OR REPLACE PROCEDURE RETAIL_ANALYTICS.MARTS.REFRESH_CATEGORY_SALES()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
COMMENT = 'Stored procedure to refresh category level aggregated sales summary table'
AS
$$
from snowflake.snowpark import Session

def main(session: Session) -> str:
    session.sql("""
        CREATE OR REPLACE TABLE RETAIL_ANALYTICS.MARTS.CATEGORY_SALES_SUMMARY AS
        SELECT
            p.category,
            COUNT(DISTINCT o.order_id) AS total_orders,
            SUM(i.quantity) AS units_sold,
            SUM(i.line_total) AS total_revenue
        FROM RETAIL_ANALYTICS.CORE.FACT_ORDERS o
        JOIN RETAIL_ANALYTICS.CORE.FACT_ORDER_ITEMS i
            ON o.order_id = i.order_id
        JOIN RETAIL_ANALYTICS.CORE.DIM_PRODUCTS p
            ON i.product_id = p.product_id
        GROUP BY p.category
    """).collect()
    return "CATEGORY_SALES_SUMMARY refreshed successfully."
$$;

-- Execute the Stored Procedure
CALL RETAIL_ANALYTICS.MARTS.REFRESH_CATEGORY_SALES();

-- Query the Resulting Aggregated Table
SELECT *
FROM RETAIL_ANALYTICS.MARTS.CATEGORY_SALES_SUMMARY
ORDER BY total_revenue DESC;
