-- ==============================================================================
-- 06_snowpipe.sql
-- Northstar Retail: Automated Continuous Ingestion via Snowpipe
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_RAW;
USE SCHEMA LANDING;

-- Note: In a production cloud deployment (AWS S3, Azure Blob, or GCP GCS),
-- a Storage Integration and External Stage are configured as follows:

/*
CREATE OR REPLACE STORAGE INTEGRATION S3_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake_s3_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://northstar-retail-data-lake/landing/');

CREATE OR REPLACE STAGE EXT_ORDER_STAGE
  URL = 's3://northstar-retail-data-lake/landing/orders/'
  STORAGE_INTEGRATION = S3_INTEGRATION
  FILE_FORMAT = JSON_FORMAT;
*/

-- 1. Create Snowpipe for Continuous Auto-Ingestion
-- Snowflake Snowpipe uses serverless compute to continuously load files as they land in cloud storage.
CREATE OR REPLACE PIPE RETAIL_RAW.LANDING.ORDERS_PIPE
  AUTO_INGEST = TRUE
  COMMENT = 'Snowpipe auto-ingesting continuous streaming JSON orders'
AS
COPY INTO RETAIL_RAW.LANDING.RAW_ORDERS (order_data, source_file, loaded_at)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        CURRENT_TIMESTAMP()
    FROM @RETAIL_RAW.LANDING.ORDER_STAGE
)
FILE_FORMAT = (FORMAT_NAME = RETAIL_RAW.LANDING.JSON_FORMAT);

-- 2. Inspect Snowpipe Status and History
SELECT SYSTEM$PIPE_STATUS('RETAIL_RAW.LANDING.ORDERS_PIPE');

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RAW_ORDERS',
        START_TIME => DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
    )
)
ORDER BY LAST_LOAD_TIME DESC;
