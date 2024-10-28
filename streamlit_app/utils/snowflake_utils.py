import os
import logging
import snowflake.connector
import pandas as pd
from retry import retry

# Snowflake connection details (loaded from environment variables for security)
SNOWFLAKE_CONNECTION_DETAILS = {
    'user': os.getenv('SNOWFLAKE_USER'),
    'password': os.getenv('SNOWFLAKE_PASSWORD'),
    'account': os.getenv('SNOWFLAKE_ACCOUNT'),
    'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE'),
    'database': os.getenv('SNOWFLAKE_DATABASE'),
    'schema': os.getenv('SNOWFLAKE_SCHEMA')
}

# Retry logic for Snowflake connection
@retry(snowflake.connector.errors.OperationalError, tries=3, delay=2, backoff=2)
def create_snowflake_connection():
    try:
        logging.info("Attempting to connect to Snowflake...")
        connection = snowflake.connector.connect(**SNOWFLAKE_CONNECTION_DETAILS)
        logging.info("Successfully connected to Snowflake.")
        return connection
    except snowflake.connector.errors.Error as e:
        logging.error(f"Failed to connect to Snowflake: {e}")
        raise

# Fetch data from Snowflake with caching and error handling
def fetch_data(query: str):
    connection = None
    try:
        connection = create_snowflake_connection()
        with connection.cursor() as cursor:
            cursor.execute(query)
            logging.info("Data fetched successfully from Snowflake.")
            return pd.DataFrame.from_records(iter(cursor), columns=[x[0] for x in cursor.description])
    except snowflake.connector.errors.Error as e:
        logging.error(f"Query execution failed: {e}")
        raise
    finally:
        if connection:
            connection.close()
            logging.info("Snowflake connection closed.")
