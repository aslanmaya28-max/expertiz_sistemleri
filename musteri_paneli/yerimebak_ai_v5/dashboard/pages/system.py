import streamlit as st
from yerimebak_ai_v5.dashboard.services.worker_service import WorkerService

st.title("🖥️ System Performance")

metrics = WorkerService.get_system_metrics()

col1, col2, col3 = st.columns(3)
with col1:
    st.metric("CPU Usage", f"{metrics['cpu_usage']}%")
with col2:
    st.metric("RAM Usage", f"{metrics['ram_usage']}%")
with col3:
    st.metric("Disk Usage", f"{metrics['disk_usage']}%")

st.divider()
st.subheader("Load Average")
st.write(f"1m: {metrics['load_avg'][0]} | 5m: {metrics['load_avg'][1]} | 15m: {metrics['load_avg'][2]}")

st.subheader("Process Monitor")
st.code("""
PID   USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
1234  root      20   0  1.2g  450m   80m S   2.5   4.2   12:34.56 python -m scraper_worker
5678  root      20   0  850m  200m   45m S   0.5   1.8    5:21.10 python -m master_pipeline
""")
