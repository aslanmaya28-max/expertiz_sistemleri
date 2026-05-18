import streamlit as st
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_market_stats, get_cached_db_health
from yerimebak_ai_v5.dashboard.components.analytics_cards import render_system_kpis
from yerimebak_ai_v5.dashboard.components.live_feed import render_live_feed

st.set_page_config(
    page_title="Genel Bakış | YERİMEBAK AI",
    page_icon="📁",
    layout="wide"
)

st.markdown("""
<style>
.stRadio > label {
    color: #F1F5F9 !important;
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

st.title("📁 Genel Bakış")

stats = get_cached_market_stats()
health = get_cached_db_health()
stats.update({"db_size_mb": health.get('size_mb', 0)})

render_system_kpis(stats)

col1, col2 = st.columns([2, 1])

with col1:
    st.subheader("📈 Pazar Aktivite Trendi")
    st.line_chart([10, 25, 45, 30, 55, 70, 65, 80, 100])

with col2:
    from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_all_listings
    df = get_cached_all_listings()
    render_live_feed(df.head(5))
