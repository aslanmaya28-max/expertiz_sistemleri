from fastapi import APIRouter
import streamlit as st

router = APIRouter(prefix="/cache", tags=["cache"])

@router.post("/clear")
async def clear_cache():
    st.cache_data.clear()
    return {"status": "success", "message": "Streamlit cache cleared"}
