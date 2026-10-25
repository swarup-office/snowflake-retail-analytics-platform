-- ==============================================================================
-- 05_streams_and_tasks.sql
-- Northstar Retail: Incremental ELT with Change Data Capture (Streams) and Tasks
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_TRANSFORM_WH;

-- 1. Create Append-Only Stream on RAW_ORDERS
USE DATABASE RETAIL_RAW;
USE SCHEMA LANDING;

CREATE OR REPLACE STREAM RAW_ORDERS_STREAM
ON TABLE RAW_ORDERS
APPEND_ONLY = TRUE
COMMENT = 'Change Data Capture stream capturing new raw JSON order arrivals';

-- 2. Create Incremental Processing Task
-- This task is scheduled to run every 5 minutes and executes ONLY when new data is present in the stream.
CREATE OR REPLACE TASK RETAIL_ANALYTICS.CORE.PROCESS_NEW_ORDERS_TASK
  WAREHOUSE = RETAIL_TRANSFORM_WH
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('RETAIL_RAW.LANDING.RAW_ORDERS_STREAM')
AS
INSERT INTO RETAIL_ANALYTICS.CORE.FACT_ORDERS (
    order_id,
    customer_id,
    order_timestamp,
    payment_method,
    shipping_city,
    shipping_state,
    shipping_country,
    order_total,
    created_at
)
SELECT
    r.order_data:order_id::STRING AS order_id,
    r.order_data:customer_id::STRING AS customer_id,
    r.order_data:order_timestamp::TIMESTAMP_NTZ AS order_timestamp,
    r.order_data:payment_method::STRING AS payment_method,
    r.order_data:shipping_address.city::STRING AS shipping_city,
    r.order_data:shipping_address.state::STRING AS shipping_state,
    r.order_data:shipping_address.country::STRING AS shipping_country,
    SUM(f.value:quantity::NUMBER * f.value:unit_price::NUMBER(12,2)) AS order_total,
    CURRENT_TIMESTAMP() AS created_at
FROM RETAIL_RAW.LANDING.RAW_ORDERS_STREAM r,
LATERAL FLATTEN(input => r.order_data:items) f
GROUP BY
    r.order_data:order_id::STRING,
    r.order_data:customer_id::STRING,
    r.order_data:order_timestamp::TIMESTAMP_NTZ,
    r.order_data:payment_method::STRING,
    r.order_data:shipping_address.city::STRING,
    r.order_data:shipping_address.state::STRING,
    r.order_data:shipping_address.country::STRING;

-- 3. Also Create Child Task for Order Items (Task Directed Acyclic Graph - DAG)
CREATE OR REPLACE TASK RETAIL_ANALYTICS.CORE.PROCESS_NEW_ORDER_ITEMS_TASK
  WAREHOUSE = RETAIL_TRANSFORM_WH
  AFTER RETAIL_ANALYTICS.CORE.PROCESS_NEW_ORDERS_TASK
AS
INSERT INTO RETAIL_ANALYTICS.CORE.FACT_ORDER_ITEMS (
    order_id,
    line_number,
    product_id,
    quantity,
    unit_price,
    line_total
)
SELECT
    r.order_data:order_id::STRING AS order_id,
    f.index + 1 AS line_number,
    f.value:product_id::STRING AS product_id,
    f.value:quantity::INTEGER AS quantity,
    f.value:unit_price::NUMBER(12,2) AS unit_price,
    f.value:quantity::NUMBER * f.value:unit_price::NUMBER(12,2) AS line_total
FROM RETAIL_RAW.LANDING.RAW_ORDERS_STREAM r,
LATERAL FLATTEN(input => r.order_data:items) f;

-- 4. Enable Tasks (Child first, then Root)
ALTER TASK RETAIL_ANALYTICS.CORE.PROCESS_NEW_ORDER_ITEMS_TASK RESUME;
ALTER TASK RETAIL_ANALYTICS.CORE.PROCESS_NEW_ORDERS_TASK RESUME;

-- 5. Monitor Task History
SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'PROCESS_NEW_ORDERS_TASK',
        SCHEDULED_TIME_RANGE_START => DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
    )
)
ORDER BY SCHEDULED_TIME DESC;
