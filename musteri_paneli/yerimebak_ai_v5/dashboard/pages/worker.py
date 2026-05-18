import streamlit as st
from yerimebak_ai_v5.dashboard.services.worker_service import WorkerService

st.title("👷 Worker Monitor")

status = WorkerService.get_worker_status()

col1, col2, col3 = st.columns(3)
with col1:
    st.metric("Status", status['status'])
with col2:
    st.metric("Last Scrape", status['last_scrape'])
with col3:
    st.metric("Health Score", f"{status['health_score']}%")

st.divider()
st.subheader("Manual Scraping Actions")

col_btn1, col_btn2, col_btn3 = st.columns(3)

with col_btn1:
    if st.button("🚀 Başlat: Sahibinden 24 Saatlik Akış (Vacuum)", use_container_width=True, type="primary"):
        import subprocess
        import sys
        try:
            # Run the scraper in the background
            subprocess.Popen(
                [sys.executable, "-m", "yerimebak_ai_v5.scrapers.sahibinden_discovery", "full"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True # Detach from Streamlit process
            )
            st.success("✅ Sahibinden Vacuum (24s) arka planda başlatıldı! Dashboard verileri periyodik olarak otomatik güncelleyecektir.")
        except Exception as e:
            st.error(f"Başlatılırken hata oluştu: {e}")

with col_btn2:
    if st.button("🔑 Sahibinden Oturum Aç (Çerez Yenile)", use_container_width=True):
        import subprocess
        import sys
        try:
            # Run the login script visible
            subprocess.Popen(
                [sys.executable, "-m", "yerimebak_ai_v5.scrapers.sahibinden_login"]
            )
            st.success("✅ Sahibinden Oturum Açma aracı başlatıldı! Lütfen açılan Chrome penceresinde giriş yapın.")
        except Exception as e:
            st.error(f"Başlatılırken hata oluştu: {e}")

with col_btn3:
    if st.button("Restart General Worker", use_container_width=True):
        st.warning("Restart signal sent to scraper_worker...")
