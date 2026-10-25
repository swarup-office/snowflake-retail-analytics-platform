"""
Northstar Retail: Snowpark Python Data Transformation
Identifies high-value customers with lifetime spend >= $1,000 and persists to Marts.
Designed to run directly inside a Snowsight Python Worksheet.
"""

import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, sum as sum_, count_distinct, max as max_

def main(session: snowpark.Session):
    # 1. Load Core Tables
    orders = session.table("RETAIL_ANALYTICS.CORE.FACT_ORDERS")
    customers = session.table("RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS")

    # 2. Aggregate customer order metrics
    customer_metrics = (
        orders.group_by("CUSTOMER_ID")
        .agg(
            count_distinct(col("ORDER_ID")).alias("ORDER_COUNT"),
            sum_(col("ORDER_TOTAL")).alias("LIFETIME_VALUE"),
            max_(col("ORDER_TIMESTAMP")).alias("LAST_ORDER_TIMESTAMP")
        )
    )

    # 3. Join with DIM_CUSTOMERS and filter for high-value segment (LTV >= $1,000)
    high_value_customers = (
        customers.join(customer_metrics, "CUSTOMER_ID")
        .filter(col("LIFETIME_VALUE") >= 1000)
        .select(
            col("CUSTOMER_ID"),
            col("FIRST_NAME"),
            col("LAST_NAME"),
            col("STATE"),
            col("ORDER_COUNT"),
            col("LIFETIME_VALUE"),
            col("LAST_ORDER_TIMESTAMP")
        )
    )

    # 4. Save results to RETAIL_ANALYTICS.MARTS.HIGH_VALUE_CUSTOMERS
    high_value_customers.write.mode("overwrite").save_as_table(
        "RETAIL_ANALYTICS.MARTS.HIGH_VALUE_CUSTOMERS"
    )

    # 5. Return DataFrame to display results in Snowsight UI
    return high_value_customers
