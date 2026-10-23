-- ==============================================================================
-- 01_environment_setup.sql
-- Northstar Retail: Snowflake Environment & Infrastructure Provisioning
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Create Dedicated Compute Warehouses
CREATE WAREHOUSE IF NOT EXISTS RETAIL_INGEST_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dedicated to data ingestion and staging';

CREATE WAREHOUSE IF NOT EXISTS RETAIL_TRANSFORM_WH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dedicated to ELT transformations and task orchestration';

CREATE WAREHOUSE IF NOT EXISTS RETAIL_ANALYTICS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dedicated to BI, analytics queries, and dashboards';

-- 2. Create Databases
CREATE DATABASE IF NOT EXISTS RETAIL_RAW
  COMMENT = 'Landing and raw staging zone for raw source data';

CREATE DATABASE IF NOT EXISTS RETAIL_ANALYTICS
  COMMENT = 'Curated dimensional warehouse and analytics data marts';

-- 3. Create Schemas
CREATE SCHEMA IF NOT EXISTS RETAIL_RAW.LANDING
  COMMENT = 'Raw untransformed landing tables';

CREATE SCHEMA IF NOT EXISTS RETAIL_RAW.STAGING
  COMMENT = 'Staging and transient intermediate processing';

CREATE SCHEMA IF NOT EXISTS RETAIL_ANALYTICS.CORE
  COMMENT = 'Core dimensional model (Facts and Dimensions)';

CREATE SCHEMA IF NOT EXISTS RETAIL_ANALYTICS.MARTS
  COMMENT = 'Aggregated data marts and reporting views';

CREATE SCHEMA IF NOT EXISTS RETAIL_ANALYTICS.GOVERNANCE
  COMMENT = 'Data masking policies and row access policies';
