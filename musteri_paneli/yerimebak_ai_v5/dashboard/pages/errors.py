import streamlit as st
from yerimebak_ai_v5.dashboard.components.error_monitor import render_error_monitor

st.title("🚨 Error Monitor")

# Simulation of errors for now
errors = [
    {"module": "Scraper", "message": "Connection timeout on listing page", "timestamp": "2026-02-17 14:10", "stacktrace": "Traceback...\nTimeoutError"},
    {"module": "Database", "message": "Database is locked during collective write", "timestamp": "2026-02-17 13:45", "stacktrace": "sqlite3.OperationalError: database is locked"}
]

render_error_monitor(errors)
