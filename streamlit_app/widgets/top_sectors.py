import logging
import streamlit as st
import altair as alt
from utils.snowflake_utils import fetch_data

# Define consistent chart dimensions globally
CHART_WIDTH = 800
CHART_HEIGHT = 500

class TopSectorsWidget:
    def render(self):
        with st.spinner('Loading Top Sectors by Position...'):
            try:
                query = """
                    SELECT DATE, SECTOR_NAME, TOTAL_SECTOR_POSITION_USD
                    FROM DAILY_SECTOR_POSITION
                    WHERE DATE = (SELECT MAX(DATE) FROM DAILY_SECTOR_POSITION)
                    ORDER BY TOTAL_SECTOR_POSITION_USD DESC
                    LIMIT 10;
                """
                top_sectors_df = fetch_data(query)
                if top_sectors_df.empty:
                    st.warning("No data available for Top Sectors by Position.")
                    return
                top_sectors_df = top_sectors_df.sort_values(by='TOTAL_SECTOR_POSITION_USD', ascending=False)
                top_sectors_df['TOTAL_SECTOR_POSITION_BILLION_USD'] = top_sectors_df['TOTAL_SECTOR_POSITION_USD'] / 1e9  # Convert to billions
                most_recent_date = top_sectors_df['DATE'].max().strftime('%Y-%m-%d')
                st.write(f"### Top 10 Sectors by Position ({most_recent_date})")
                st.write("This chart shows the top 10 sectors by total position on the most recent available date. The values are represented in billions of USD.")
                chart = alt.Chart(top_sectors_df).mark_bar().encode(
                    x=alt.X('TOTAL_SECTOR_POSITION_BILLION_USD:Q', title='Total Sector Position (Billion USD)', sort='-y', axis=alt.Axis(format='.2f')),
                    y=alt.Y('SECTOR_NAME:N', sort='-x', title='Sector Name', axis=alt.Axis(labelLimit=200)),
                    color=alt.Color('SECTOR_NAME:N', legend=alt.Legend(title="Sector")),
                    tooltip=[
                        alt.Tooltip('SECTOR_NAME:N', title='Sector Name'),
                        alt.Tooltip('TOTAL_SECTOR_POSITION_BILLION_USD:Q', format='.2f', title='Total Position (Billion USD)')
                    ]
                ).properties(
                    width=CHART_WIDTH,
                    height=CHART_HEIGHT
                )
                st.altair_chart(chart, use_container_width=True)
            except Exception as e:
                st.error("Failed to load Top Sectors by Position. Please try again later.")
                logging.error(f"Error in TopSectorsWidget: {e}")
