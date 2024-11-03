import logging
import streamlit as st
from widgets.top_sectors import TopSectorsWidget
from widgets.top_companies import TopCompaniesWidget
from widgets.price_history import CompanyPriceHistoryWidget

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Set Streamlit page configuration
st.set_page_config(layout="wide", page_title="Market Dashboard", page_icon="📊")

# Sidebar for navigation
st.sidebar.title("Navigation")
page = st.sidebar.radio("Go to", ["Top Sectors by Position", "Top Companies", "Price History"])

# Streamlit app setup
st.title("Market Dashboard")

# Instantiate and render each widget based on selected page
if page == "Top Sectors by Position":
    top_sectors_widget = TopSectorsWidget()
    top_sectors_widget.render()
elif page == "Top Companies":
    top_companies_widget = TopCompaniesWidget()
    top_companies_widget.render()
elif page == "Price History":
    company_price_history_widget = CompanyPriceHistoryWidget()
    company_price_history_widget.render()
