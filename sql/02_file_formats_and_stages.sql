-- ==============================================================================
-- 02_file_formats_and_stages.sql
-- Northstar Retail: File Formats, Stages, Raw Landing Tables, and Ingestion
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_INGEST_WH;
USE DATABASE RETAIL_RAW;
USE SCHEMA LANDING;

-- 1. Create File Formats
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('NULL', 'null', '');

CREATE OR REPLACE FILE FORMAT JSON_FORMAT
  TYPE = JSON
  STRIP_OUTER_ARRAY = FALSE;

-- 2. Create Internal Stages
CREATE OR REPLACE STAGE CUSTOMER_STAGE
  FILE_FORMAT = CSV_FORMAT;

CREATE OR REPLACE STAGE PRODUCT_STAGE
  FILE_FORMAT = CSV_FORMAT;

CREATE OR REPLACE STAGE ORDER_STAGE
  FILE_FORMAT = JSON_FORMAT;

-- 3. Create Raw Landing Tables
CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    customer_id STRING,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    city STRING,
    state STRING,
    country STRING,
    signup_date DATE,
    source_file STRING,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_PRODUCTS (
    product_id STRING,
    product_name STRING,
    category STRING,
    unit_price NUMBER(12,2),
    stock_quantity INTEGER,
    source_file STRING,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_ORDERS (
    order_data VARIANT,
    source_file STRING,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 4. Load Data with COPY INTO
-- Note: Stage the local files prior to running these commands via Snowsight (+ Files) or SnowSQL PUT:
-- PUT file://customers.csv @CUSTOMER_STAGE AUTO_COMPRESS=TRUE;
-- PUT file://products.csv @PRODUCT_STAGE AUTO_COMPRESS=TRUE;
-- PUT file://orders.json @ORDER_STAGE AUTO_COMPRESS=TRUE;

COPY INTO RAW_CUSTOMERS
FROM (
    SELECT
        $1, $2, $3, $4, $5, $6, $7, $8,
        TRY_TO_DATE($9),
        METADATA$FILENAME,
        CURRENT_TIMESTAMP()
    FROM @CUSTOMER_STAGE
)
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT)
ON_ERROR = 'CONTINUE';

COPY INTO RAW_PRODUCTS
FROM (
    SELECT
        $1, $2, $3,
        TRY_TO_DECIMAL($4, 12, 2),
        TRY_TO_NUMBER($5),
        METADATA$FILENAME,
        CURRENT_TIMESTAMP()
    FROM @PRODUCT_STAGE
)
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT)
ON_ERROR = 'CONTINUE';

COPY INTO RAW_ORDERS (order_data, source_file, loaded_at)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        CURRENT_TIMESTAMP()
    FROM @ORDER_STAGE
)
FILE_FORMAT = (FORMAT_NAME = JSON_FORMAT)
ON_ERROR = 'CONTINUE';

-- 5. Validation Queries
SELECT 'RAW_CUSTOMERS' AS tbl_name, COUNT(*) AS row_cnt FROM RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_PRODUCTS', COUNT(*) FROM RAW_PRODUCTS
UNION ALL
SELECT 'RAW_ORDERS', COUNT(*) FROM RAW_ORDERS;
