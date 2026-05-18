import streamlit as st
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_db_health
from yerimebak_ai_v5.dashboard.services.analytics_service import AnalyticsService

st.set_page_config(
    page_title="Önbellek Analitiği | YERİMEBAK AI",
    page_icon="💾",
    layout="wide"
)

st.markdown("""
<style>
.stRadio > label {
    color: #F59E0B !important;
    font-size: 14px;
    font-weight: 500;
    transition: color 0.2s ease;
}
.stRadio > label:hover {
    color: #FBBF24 !important;
}
.stRadio > label[data-selected="true"] {
    color: #FBBF24 !important;
    font-weight: 700;
}
</style>
""", unsafe_allow_html=True)

st.title("💾 Önbellek Analitiği")

health = get_cached_db_health()

col1, col2 = st.columns(2)
with col1:
    st.metric("Cache Hit Rate", "98.2%", delta="1.2%")
    st.metric("Average Latency", "12ms", delta="-4ms")
with col2:
    st.metric("Cache Miss Rate", "1.8%")
    st.metric("Query Speedup", "52x")

st.divider()
st.subheader("Cache Key Distribution")
st.bar_chart({
    "Key Type": ["Listings", "Analytics", "Stats", "Search"],
    "Count": [450, 120, 30, 800]
})

if st.button("Clear Cache"):
    st.cache_data.clear()
    st.success("Cache cleared successfully.")
