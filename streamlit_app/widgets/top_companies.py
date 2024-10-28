import logging
import streamlit as st
import pandas as pd
from utils.snowflake_utils import fetch_data

class TopCompaniesWidget:
    def render(self):
        with st.spinner('Loading Top Companies...'):
            try:
                query = """
                    SELECT 
                        t.TICKER, 
                        c.SECTOR_NAME, 
                        p.SHARES, 
                        pr.CLOSE_USD AS LAST_CLOSE_PRICE_USD, 
                        t.AVG_POSITION_USD
                    FROM top_25_percent t
                    JOIN POSITION p ON t.COMPANY_ID = p.COMPANY_ID
                    JOIN COMPANY c ON t.COMPANY_ID = c.ID
                    JOIN PRICE pr ON p.COMPANY_ID = pr.COMPANY_ID AND p.DATE = pr.DATE
                    WHERE p.DATE = (SELECT MAX(DATE) FROM POSITION)
                    ORDER BY t.AVG_POSITION_USD DESC;
                """
                top_companies_df = fetch_data(query)
                if top_companies_df.empty:
                    st.warning("No data available for Top Companies.")
                    return
                top_companies_df.columns = [
                    "Ticker",
                    "Sector Name",
                    "Shares",
                    "Last Close Price (USD)",
                    "Average Position of Last Year (Billion USD)"
                ]
                top_companies_df['Shares'] = top_companies_df['Shares'].apply(lambda x: f"{x:,.0f}")
                top_companies_df['Last Close Price (USD)'] = top_companies_df['Last Close Price (USD)'].apply(lambda x: f"${x:,.2f}")
                top_companies_df['Average Position of Last Year (Billion USD)'] = top_companies_df['Average Position of Last Year (Billion USD)'].apply(lambda x: f"${x/1e9:,.2f}B")
                most_recent_date = pd.to_datetime(fetch_data("SELECT MAX(DATE) AS MAX_DATE FROM POSITION")['MAX_DATE'][0]).strftime('%Y-%m-%d')
                st.write(f"### Top 25% Companies ({most_recent_date})")
                st.write("This table lists the top 25% of companies based on their average position over the last year. All values are formatted for better readability.")
                st.dataframe(top_companies_df, use_container_width=True, height=800)
            except Exception as e:
                st.error("Failed to load Top Companies. Please try again later.")
                logging.error(f"Error in TopCompaniesWidget: {e}")
