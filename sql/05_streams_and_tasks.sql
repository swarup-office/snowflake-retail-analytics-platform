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
    order_data:order_id::STRING,
    order_data:customer_id::STRING,
    order_data:order_timestamp::TIMESTAMP_NTZ,
    order_data:payment_method::STRING,
    order_data:shipping_address.city::STRING,
    order_data:shipping_address.state::STRING,
    order_data:shipping_address.country::STRING,
    (
        SELECT SUM(
            item.value:quantity::NUMBER * item.value:unit_price::NUMBER(12,2)
        )
        FROM TABLE(FLATTEN(input => order_data:items)) item
    ),
    CURRENT_TIMESTAMP()
FROM RETAIL_RAW.LANDING.RAW_ORDERS_STREAM;

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
