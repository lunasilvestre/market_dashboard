import logging
import streamlit as st
import plotly.graph_objects as go
from utils.snowflake_utils import fetch_data

class CompanyPriceHistoryWidget:
    def render(self):
        company = st.selectbox("Select a company:", self.get_companies())
        if company:
            with st.spinner(f'Loading Price History for {company}...'):
                try:
                    query = f"""
                        SELECT dp.DATE, dp.CLOSE_USD
                        FROM DAILY_POSITION_USD dp
                        JOIN COMPANY c ON dp.COMPANY_ID = c.ID
                        WHERE c.TICKER = '{company}'
                        ORDER BY dp.DATE;
                    """
                    company_price_df = fetch_data(query)
                    if company_price_df.empty:
                        st.warning(f"No price history available for {company}.")
                        return
                    st.write(f"### Price History for {company}")
                    st.write("This chart shows the historical closing prices for the selected company. Use the range slider to zoom in on specific periods.")
                    fig = go.Figure()
                    fig.add_trace(go.Scatter(
                        x=company_price_df['DATE'],
                        y=company_price_df['CLOSE_USD'],
                        mode='lines',
                        name='Close Price (USD)',
                        hovertemplate='%{y:$,.2f}'
                    ))
                    fig.update_layout(
                        title=f'Price History for {company}',
                        xaxis_title='Date',
                        yaxis_title='Close Price (USD)',
                        xaxis_rangeslider_visible=True,
                        height=600,
                        yaxis_tickformat='$,.2f'
                    )
                    st.plotly_chart(fig, use_container_width=True)
                except Exception as e:
                    st.error(f"Failed to load price history for {company}. Please try again later.")
                    logging.error(f"Error in CompanyPriceHistoryWidget: {e}")

    def get_companies(self):
        try:
            query = "SELECT DISTINCT TICKER FROM COMPANY ORDER BY TICKER;"
            companies_df = fetch_data(query)
            if companies_df.empty:
                st.warning("No companies available to select.")
                return []
            return companies_df['TICKER'].tolist()
        except Exception as e:
            st.error("Failed to load companies. Please try again later.")
            logging.error(f"Error in get_companies: {e}")
            return []
