-- ==============================================================================
-- 03_core_dimensional_model.sql
-- Northstar Retail: Dimensional Modeling (Facts & Dims) and JSON Transformation
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE RETAIL_TRANSFORM_WH;
USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA CORE;

-- 1. Create Dimension Tables
CREATE OR REPLACE TABLE DIM_CUSTOMERS (
    customer_id STRING PRIMARY KEY,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    city STRING,
    state STRING,
    country STRING,
    signup_date DATE,
    updated_at TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_PRODUCTS (
    product_id STRING PRIMARY KEY,
    product_name STRING,
    category STRING,
    unit_price NUMBER(12,2),
    stock_quantity INTEGER,
    updated_at TIMESTAMP_NTZ
);

-- 2. Create Fact Tables
CREATE OR REPLACE TABLE FACT_ORDERS (
    order_id STRING PRIMARY KEY,
    customer_id STRING,
    order_timestamp TIMESTAMP_NTZ,
    payment_method STRING,
    shipping_city STRING,
    shipping_state STRING,
    shipping_country STRING,
    order_total NUMBER(12,2),
    created_at TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE FACT_ORDER_ITEMS (
    order_id STRING,
    line_number INTEGER,
    product_id STRING,
    quantity INTEGER,
    unit_price NUMBER(12,2),
    line_total NUMBER(12,2),
    PRIMARY KEY (order_id, line_number)
);

-- 3. Transform and Upsert Customers using MERGE (SCD Type 1)
MERGE INTO DIM_CUSTOMERS target
USING (
    SELECT
        customer_id,
        first_name,
        last_name,
        email,
        phone,
        city,
        state,
        country,
        signup_date,
        loaded_at
    FROM RETAIL_RAW.LANDING.RAW_CUSTOMERS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY loaded_at DESC
    ) = 1
) source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE SET
    first_name = source.first_name,
    last_name = source.last_name,
    email = source.email,
    phone = source.phone,
    city = source.city,
    state = source.state,
    country = source.country,
    signup_date = source.signup_date,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, first_name, last_name, email, phone,
    city, state, country, signup_date, updated_at
)
VALUES (
    source.customer_id, source.first_name, source.last_name,
    source.email, source.phone, source.city, source.state,
    source.country, source.signup_date, CURRENT_TIMESTAMP()
);

-- 4. Transform and Upsert Products using MERGE
MERGE INTO DIM_PRODUCTS target
USING (
    SELECT
        product_id,
        product_name,
        category,
        unit_price,
        stock_quantity,
        loaded_at
    FROM RETAIL_RAW.LANDING.RAW_PRODUCTS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_id
        ORDER BY loaded_at DESC
    ) = 1
) source
ON target.product_id = source.product_id
WHEN MATCHED THEN UPDATE SET
    product_name = source.product_name,
    category = source.category,
    unit_price = source.unit_price,
    stock_quantity = source.stock_quantity,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    product_id, product_name, category, unit_price, stock_quantity, updated_at
)
VALUES (
    source.product_id, source.product_name, source.category, source.unit_price, source.stock_quantity, CURRENT_TIMESTAMP()
);

-- 5. Parse JSON Orders into FACT_ORDERS
INSERT INTO FACT_ORDERS (
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
FROM RETAIL_RAW.LANDING.RAW_ORDERS r,
LATERAL FLATTEN(input => r.order_data:items) f
GROUP BY
    r.order_data:order_id::STRING,
    r.order_data:customer_id::STRING,
    r.order_data:order_timestamp::TIMESTAMP_NTZ,
    r.order_data:payment_method::STRING,
    r.order_data:shipping_address.city::STRING,
    r.order_data:shipping_address.state::STRING,
    r.order_data:shipping_address.country::STRING;

-- 6. Parse and Flatten Nested Items into FACT_ORDER_ITEMS
INSERT INTO FACT_ORDER_ITEMS (
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
FROM RETAIL_RAW.LANDING.RAW_ORDERS r,
LATERAL FLATTEN(input => r.order_data:items) f;

-- 7. Verification Queries
SELECT * FROM DIM_CUSTOMERS;
SELECT * FROM DIM_PRODUCTS;
SELECT * FROM FACT_ORDERS;
SELECT * FROM FACT_ORDER_ITEMS;
