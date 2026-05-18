import streamlit as st
import pandas as pd
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_all_listings
from yerimebak_ai_v5.dashboard.services.analytics_service import AnalyticsService
from yerimebak_ai_v5.dashboard.components.analytics_cards import render_analytics_cards
from yerimebak_ai_v5.dashboard.components.price_chart import render_market_distribution

# Türkçe başlık
st.set_page_config(
    page_title="Pazar Analitiği | YERİMEBAK AI",
    page_icon="📊",
    layout="wide"
)

# Turuncu menü CSS
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

st.title("📊 Pazar Analitiği")

df = get_cached_all_listings()

if df.empty:
    st.warning("Analitik için veri bulunamuyor.")
else:
    metrics = AnalyticsService.calculate_market_metrics(df)
    render_analytics_cards(metrics)
    
    st.divider()
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("💰 Fiyat Dağılımı")
        render_market_distribution(df)
    with col2:
        st.subheader("📈 Pazar Yapısı")
        source_counts = df['source'].value_counts()
        st.bar_chart(source_counts)

    st.subheader("🔍 Fırsat Analizi")
    drops = AnalyticsService.detect_price_drops(df)
    if not drops.empty:
        st.dataframe(drops[['brand', 'model', 'year', 'price', 'opportunity_score']].head(10))
    else:
        st.info("Şu an için önemli fiyat düşüşü tespit edilmedi.")
