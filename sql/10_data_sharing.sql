-- ==============================================================================
-- 10_data_sharing.sql
-- Northstar Retail: Secure Data Sharing with External Partners
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Create a Secure Outbound Share
CREATE OR REPLACE SHARE RETAIL_PARTNER_SHARE
  COMMENT = 'Secure data share providing aggregated sales metrics to authorized external retail partners';

-- 2. Ensure View is SECURE (Required for Snowflake Data Shares)
ALTER VIEW RETAIL_ANALYTICS.MARTS.VW_DAILY_SALES SET SECURE;

-- 3. Grant Database and Schema Privileges to the Share
GRANT USAGE ON DATABASE RETAIL_ANALYTICS TO SHARE RETAIL_PARTNER_SHARE;
GRANT USAGE ON SCHEMA RETAIL_ANALYTICS.MARTS TO SHARE RETAIL_PARTNER_SHARE;

-- 4. Grant Select Privileges on the SECURE View (Zero PII Exposure)
GRANT SELECT ON VIEW RETAIL_ANALYTICS.MARTS.VW_DAILY_SALES TO SHARE RETAIL_PARTNER_SHARE;

-- 4. Inspect Share Configuration
SHOW SHARES LIKE 'RETAIL_PARTNER_SHARE';
DESCRIBE SHARE RETAIL_PARTNER_SHARE;

-- 5. Add Consumer Account (Example syntax - replace placeholder with partner locator)
-- ALTER SHARE RETAIL_PARTNER_SHARE ADD ACCOUNTS = <PARTNER_ACCOUNT_LOCATOR>;
