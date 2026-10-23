# Northstar Retail: Hands-On Snowflake Sales Analytics Platform

An end-to-end Snowflake data engineering and analytics platform implementing multi-cluster warehouse architectures, raw data staging and loading (CSV and semi-structured JSON), ELT transformations with Streams and Tasks, performance clustering, fine-grained data governance (RBAC, Dynamic Data Masking, Row Access Policies), zero-copy cloning, Time Travel recovery, Secure Data Sharing, and Snowpark Python workflows.

---

## 1. Architecture Overview

```text
       [ customers.csv / products.csv ]                [ orders.json ]
                      |                                       |
                      v                                       v
         +-------------------------------------------------------------+
         |                      INTERNAL STAGES                         |
         |         @CUSTOMER_STAGE  |  @PRODUCT_STAGE  |  @ORDER_STAGE |
         +-------------------------------------------------------------+
                                       |
                                       v (COPY INTO / Snowpipe)
         +-------------------------------------------------------------+
         |                    RETAIL_RAW DATABASE                      |
         |         RAW_CUSTOMERS  |  RAW_PRODUCTS  |  RAW_ORDERS        |
         +-------------------------------------------------------------+
                                       |
                       (Streams + Tasks / SQL MERGE & FLATTEN)
                                       v
         +-------------------------------------------------------------+
         |                 RETAIL_ANALYTICS (CORE)                     |
         |   DIM_CUSTOMERS  |  DIM_PRODUCTS  |  FACT_ORDERS  |  ITEMS   |
         +-------------------------------------------------------------+
                                       |
                                       v
         +-------------------------------------------------------------+
         |                 RETAIL_ANALYTICS (MARTS)                    |
         |  VW_DAILY_SALES | VW_CUSTOMER_LTV | HIGH_VALUE_CUSTOMERS    |
         +-------------------------------------------------------------+
                                       |
             +-------------------------+-------------------------+
             |                                                   |
             v                                                   v
   [ GOVERNANCE & ACCESS ]                              [ SECURE SHARING ]
   - Masking Policy (PII)                               - RETAIL_PARTNER_SHARE
   - Row Access Policy (State)                          - Zero-copy Dev Clone
```

---

## 2. Repository Structure

```text
├── data/
│   ├── customers.csv                   # Source CSV: Customer master data
│   ├── products.csv                    # Source CSV: Product catalog
│   └── orders.json                     # Source JSON: 15 multi-item sales transactions
├── sql/
│   ├── 01_environment_setup.sql        # Warehouses, databases, and schemas
│   ├── 02_file_formats_and_stages.sql  # Stages, file formats, raw tables, and COPY INTO
│   ├── 03_core_dimensional_model.sql   # Dims, Facts, MERGE upserts, VARIANT/FLATTEN
│   ├── 04_analytics_marts.sql          # Mart views: VW_DAILY_SALES, VW_CUSTOMER_LTV
│   ├── 05_streams_and_tasks.sql        # Incremental pipeline with Stream + Task DAG
│   ├── 06_snowpipe.sql                 # Automated Snowpipe continuous ingestion
│   ├── 07_time_travel_and_cloning.sql  # Time Travel recovery and zero-copy clone test
│   ├── 08_performance_optimization.sql # Clustering keys, query tags, profile analysis
│   ├── 09_security_and_governance.sql  # RBAC roles, Dynamic Masking & Row Access Policies
│   ├── 10_data_sharing.sql             # Secure outbound share for partner accounts
│   └── 11_snowpark_udf_and_sproc.sql   # Python UDF and Stored Procedure
├── snowpark/
│   └── high_value_customers.py         # Snowpark Python DataFrame transformation
└── README.md
```

---

## 3. Step-by-Step Execution Guide

### Step 1: Provision Environment
Run [`sql/01_environment_setup.sql`](sql/01_environment_setup.sql) as `ACCOUNTADMIN` to establish:
- **Compute Warehouses:** `RETAIL_INGEST_WH` (XS), `RETAIL_TRANSFORM_WH` (S), `RETAIL_ANALYTICS_WH` (XS).
- **Databases:** `RETAIL_RAW`, `RETAIL_ANALYTICS`.
- **Schemas:** `LANDING`, `STAGING`, `CORE`, `MARTS`, `GOVERNANCE`.

### Step 2: Ingest Sample Data
1. Upload local data files in [`data/`](data/) using Snowsight stage UI or SnowSQL:
   ```bash
   PUT file://data/customers.csv @RETAIL_RAW.LANDING.CUSTOMER_STAGE AUTO_COMPRESS=TRUE;
   PUT file://data/products.csv @RETAIL_RAW.LANDING.PRODUCT_STAGE AUTO_COMPRESS=TRUE;
   PUT file://data/orders.json @RETAIL_RAW.LANDING.ORDER_STAGE AUTO_COMPRESS=TRUE;
   ```
2. Execute [`sql/02_file_formats_and_stages.sql`](sql/02_file_formats_and_stages.sql) to define stages and execute `COPY INTO`.

### Step 3: Dimensional Modeling & JSON Parsing
Execute [`sql/03_core_dimensional_model.sql`](sql/03_core_dimensional_model.sql):
- Applies `MERGE` statements on `DIM_CUSTOMERS` and `DIM_PRODUCTS` with `QUALIFY ROW_NUMBER()`.
- Extracts `order_data` JSON keys into `FACT_ORDERS`.
- Flattens nested item arrays into `FACT_ORDER_ITEMS` with `LATERAL FLATTEN`.

### Step 4: Analytics Marts
Run [`sql/04_analytics_marts.sql`](sql/04_analytics_marts.sql) to deploy reporting views `VW_DAILY_SALES` and `VW_CUSTOMER_LTV`.

### Step 5: Incremental Processing with Streams & Tasks
Run [`sql/05_streams_and_tasks.sql`](sql/05_streams_and_tasks.sql):
- Defines `RAW_ORDERS_STREAM` (`APPEND_ONLY = TRUE`).
- Orchestrates `PROCESS_NEW_ORDERS_TASK` triggered conditionally on stream data with `SYSTEM$STREAM_HAS_DATA()`.

### Step 6: Security, Governance & Sharing
1. Run [`sql/09_security_and_governance.sql`](sql/09_security_and_governance.sql) for RBAC roles, Dynamic Masking of PII (email, phone), and State-based Row Access Policies.
2. Run [`sql/10_data_sharing.sql`](sql/10_data_sharing.sql) to create `RETAIL_PARTNER_SHARE`.

### Step 7: Snowpark Python & Advanced Extensions
1. Run [`snowpark/high_value_customers.py`](snowpark/high_value_customers.py) in Snowsight Python Worksheets or locally.
2. Deploy [`sql/11_snowpark_udf_and_sproc.sql`](sql/11_snowpark_udf_and_sproc.sql) for the Python segmentation UDF (`CUSTOMER_TIER`) and Python Stored Procedure (`REFRESH_CATEGORY_SALES`).
