import streamlit as st
import pandas as pd
from yerimebak_ai_v5.dashboard.services.db_service import get_db_service

db_service = get_db_service()

@st.cache_data(ttl=30)
def get_cached_all_listings() -> pd.DataFrame:
    """Cached call to get all listings"""
    return db_service.get_all_listings()

@st.cache_data(ttl=60)
def get_cached_search_listings(brand: str, model: str, year: int) -> pd.DataFrame:
    """Cached call for specific vehicle search"""
    return db_service.search_listings(brand, model, year)

@st.cache_data(ttl=300)
def get_cached_market_stats():
    """Cached call for market statistics"""
    return db_service.get_market_stats()

@st.cache_data(ttl=1) # Fast refresh for health
def get_cached_db_health():
    return db_service.get_db_health()
