-- ==============================================================================
-- 07_time_travel_and_cloning.sql
-- Northstar Retail: Time Travel Data Recovery and Zero-Copy Environment Cloning
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_TRANSFORM_WH;
USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA CORE;

-- ==============================================================================
-- Part 1: Time Travel Data Recovery
-- ==============================================================================

-- 1. Simulate an accidental deletion of a customer record
DELETE FROM RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS
WHERE customer_id = 'C001';

-- Verify the customer is deleted
SELECT * FROM RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS WHERE customer_id = 'C001';

-- 2. Recover the deleted customer using Snowflake Time Travel (OFFSET in seconds)
INSERT INTO RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS
SELECT *
FROM RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS
AT (OFFSET => -60 * 5)
WHERE customer_id = 'C001';

-- Verify recovery
SELECT * FROM RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS WHERE customer_id = 'C001';

-- ==============================================================================
-- Part 2: Zero-Copy Cloning for Dev/Test Sandboxing
-- ==============================================================================

-- 1. Create a zero-copy instant database clone of the entire production analytics database
CREATE OR REPLACE DATABASE RETAIL_ANALYTICS_DEV
CLONE RETAIL_ANALYTICS
COMMENT = 'Zero-copy development sandbox cloned from RETAIL_ANALYTICS';

-- 2. Test schema evolution and modifications in DEV without affecting PROD
USE DATABASE RETAIL_ANALYTICS_DEV;
USE SCHEMA CORE;

ALTER TABLE DIM_PRODUCTS
ADD COLUMN supplier_name STRING DEFAULT 'Direct Sourcing';

UPDATE DIM_PRODUCTS
SET supplier_name = 'Global Tech Supply'
WHERE category = 'Electronics';

-- Inspect DEV table with changes
SELECT * FROM RETAIL_ANALYTICS_DEV.CORE.DIM_PRODUCTS;

-- Confirm PROD table is completely unchanged
SELECT * FROM RETAIL_ANALYTICS.CORE.DIM_PRODUCTS;
