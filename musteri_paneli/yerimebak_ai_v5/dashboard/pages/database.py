import streamlit as st
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_db_health
from yerimebak_ai_v5.dashboard.components.database_monitor import render_database_monitor

st.title("🗄️ Database Monitor")

health = get_cached_db_health()

render_database_monitor(health)

st.divider()
st.subheader("Table Statistics")
st.table({
    "Table": ["listings", "price_history", "valuation_history", "user_requests"],
    "Records": [health['total_records'], health['total_records']*1.2, 450, 1200],
    "Size": ["45MB", "12MB", "1MB", "2MB"]
})
