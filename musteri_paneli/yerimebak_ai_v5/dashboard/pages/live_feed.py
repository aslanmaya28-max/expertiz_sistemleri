import streamlit as st
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_all_listings
from yerimebak_ai_v5.dashboard.components.live_feed import render_live_feed

st.title("📡 Live Market Feed")
st.write("Real-time activity from all scrapers.")

df = get_cached_all_listings()

render_live_feed(df)
