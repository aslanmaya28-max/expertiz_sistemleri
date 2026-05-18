import streamlit as st
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_all_listings
from yerimebak_ai_v5.dashboard.components.listings_table import render_listings_table

st.title("📋 Market Listings")
st.write("Complete view of the Market Data Lake.")

df = get_cached_all_listings()

# Sidebar filters
st.sidebar.header("Filter Listings")
brands = ["All"] + sorted(df['brand'].unique().tolist())
selected_brand = st.sidebar.selectbox("Brand", brands)

if selected_brand != "All":
    df = df[df['brand'] == selected_brand]

render_listings_table(df)
