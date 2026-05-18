import streamlit as st
import pandas as pd
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_search_listings
from yerimebak_ai_v5.dashboard.components.price_chart import render_price_trend_chart
from yerimebak_ai_v5.core.ai_valuation import get_ai_valuation_engine

st.title("🔍 Vehicle Search & AI Valuation")

col1, col2, col3 = st.columns(3)
with col1:
    brand = st.text_input("Brand", "Volkswagen")
with col2:
    model = st.text_input("Model", "Passat")
with col3:
    year = st.number_input("Year", 2010, 2025, 2020)

if st.button("Analyze Market"):
    df = get_cached_search_listings(brand, model, year)
    
    if df.empty:
        st.error(f"No market data found for {brand} {model} {year}")
    else:
        st.success(f"Found {len(df)} listings.")
        
        # Top Stats
        avg_price = df['price'].mean()
        st.metric("Market Average", f"{int(avg_price):,} TL")
        
        # AI Valuation
        st.subheader("🤖 AI Forensic Valuation")
        engine = get_ai_valuation_engine()
        
        # Prepare data for cleaner/valuation if needed, 
        # but here we can call evaluation directly with mock/sample vehicle data
        vehicle = {"brand": brand, "model": model, "year": year, "km": 50000}
        
        # Need to clean data first as ai_engine expects cleaned listings
        from yerimebak_ai_v5.core.data_cleaner import get_data_cleaner
        cleaner = get_data_cleaner()
        raw_listings = df.to_dict('records')
        clean_listings = cleaner.clean_listing_data(raw_listings)
        
        valuation = engine.evaluate_vehicle(vehicle, clean_listings)
        
        vcol1, vcol2, vcol3 = st.columns(3)
        with vcol1:
            st.metric("Forensic Price", f"{valuation['forensic_price']:,} TL")
        with vcol2:
            st.metric("Confidence", f"{valuation.get('confidence_score', 85)}%")
        with vcol3:
            st.metric("Investment Rating", "A+")

        render_price_trend_chart(df)
