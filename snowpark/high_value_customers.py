"""
Northstar Retail: Snowpark Python Data Transformation
Identifies high-value customers with lifetime spend >= $1,000 and persists to Marts.
"""

from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as sum_, count_distinct, max as max_

def process_high_value_customers(session: Session):
    print("Fetching FACT_ORDERS and DIM_CUSTOMERS tables...")
    orders = session.table("RETAIL_ANALYTICS.CORE.FACT_ORDERS")
    customers = session.table("RETAIL_ANALYTICS.CORE.DIM_CUSTOMERS")

    # Aggregate customer order metrics
    customer_metrics = (
        orders.group_by("CUSTOMER_ID")
        .agg(
            count_distinct(col("ORDER_ID")).alias("ORDER_COUNT"),
            sum_(col("ORDER_TOTAL")).alias("LIFETIME_VALUE"),
            max_(col("ORDER_TIMESTAMP")).alias("LAST_ORDER_TIMESTAMP")
        )
    )

    # Join with DIM_CUSTOMERS and filter for high-value segment (LTV >= 1000)
    high_value_customers = (
        customers.join(customer_metrics, "CUSTOMER_ID")
        .filter(col("LIFETIME_VALUE") >= 1000)
        .select(
            "CUSTOMER_ID",
            "FIRST_NAME",
            "LAST_NAME",
            "STATE",
            "ORDER_COUNT",
            "LIFETIME_VALUE",
            "LAST_ORDER_TIMESTAMP"
        )
    )

    # Persist the transformed DataFrame to RETAIL_ANALYTICS.MARTS.HIGH_VALUE_CUSTOMERS
    high_value_customers.write.mode("overwrite").save_as_table(
        "RETAIL_ANALYTICS.MARTS.HIGH_VALUE_CUSTOMERS"
    )
    print("Successfully populated RETAIL_ANALYTICS.MARTS.HIGH_VALUE_CUSTOMERS table.")

if __name__ == "__main__":
    # When running locally or in a worksheet
    import os
    # Connection parameters can be retrieved from environment variables or active worksheet session
    connection_params = {
        "account": os.environ.get("SNOWFLAKE_ACCOUNT", "my_account"),
        "user": os.environ.get("SNOWFLAKE_USER", "my_user"),
        "password": os.environ.get("SNOWFLAKE_PASSWORD", "my_password"),
        "role": "ACCOUNTADMIN",
        "warehouse": "RETAIL_TRANSFORM_WH",
        "database": "RETAIL_ANALYTICS",
        "schema": "MARTS"
    }
    try:
        session = Session.builder.configs(connection_params).create()
        process_high_value_customers(session)
    except Exception as e:
        print(f"To run as a Snowsight Python worksheet, use the handler function directly with the active session parameter: {e}")
