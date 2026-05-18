# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Scraper Yönetim Sayfası (Admin Only)
Arabam ve Borusan scraper'larını başlat/durdur
"""
import os
import streamlit as st
import requests
import time
from datetime import datetime

# Docker: app service name | Local: localhost
_API_HOST = os.getenv("API_HOST", "app" if os.path.exists("/.dockerenv") else "localhost")
API_BASE = f"http://{_API_HOST}:8000/api/v1/scrapers"


def render_scraper_control_page():
    """Admin scraper kontrol paneli"""

    st.title("🤖 Scraper Yönetimi")
    st.caption("Arabam ve Borusan scraper'larını başlatıp durdurun. Sadece admin erişimi.")

    st.divider()

    # ── Mevcut Durum ──────────────────────────────────────────────
    st.subheader("📊 Scraper Durumları")

    status_data = {}
    try:
        resp = requests.get(f"{API_BASE}/status", timeout=5)
        if resp.status_code == 200:
            status_data = resp.json()
    except Exception as e:
        st.warning(f"API bağlantı hatası: {e}")

    col_s1, col_s2 = st.columns(2)

    with col_s1:
        arabam_info = status_data.get("arabam", {})
        is_running = arabam_info.get("status") == "running"
        status_color = "🟢" if is_running else "⚪"
        status_label = "Çalışıyor" if is_running else "Bekliyor"
        pid_info = f"PID: {arabam_info.get('pid')}" if arabam_info.get("pid") else "PID: -"
        st.markdown(f"""
        <div style='background: rgba(30,41,59,0.7); padding: 20px; border-radius: 12px;
                    border: 1px solid rgba(148,163,184,0.15);'>
            <h3 style='margin:0; color:#F8FAFC;'>{status_color} Arabam Scraper</h3>
            <p style='color:#94A3B8; font-size:0.85rem;'>Durum: <b>{status_label}</b></p>
            <p style='color:#94A3B8; font-size:0.85rem;'>Son Aktivite: {arabam_info.get('last_activity', '-')}</p>
            <p style='color:#94A3B8; font-size:0.85rem;'>{pid_info}</p>
        </div>
        """, unsafe_allow_html=True)

    with col_s2:
        borusan_info = status_data.get("borusan", {})
        is_running = borusan_info.get("status") == "running"
        status_color = "🟢" if is_running else "⚪"
        status_label = "Çalışıyor" if is_running else "Bekliyor"
        pid_info = f"PID: {borusan_info.get('pid')}" if borusan_info.get("pid") else "PID: -"
        st.markdown(f"""
        <div style='background: rgba(30,41,59,0.7); padding: 20px; border-radius: 12px;
                    border: 1px solid rgba(148,163,184,0.15);'>
            <h3 style='margin:0; color:#F8FAFC;'>{status_color} Borusan Scraper</h3>
            <p style='color:#94A3B8; font-size:0.85rem;'>Durum: <b>{status_label}</b></p>
            <p style='color:#94A3B8; font-size:0.85rem;'>Son Aktivite: {borusan_info.get('last_activity', '-')}</p>
            <p style='color:#94A3B8; font-size:0.85rem;'>{pid_info}</p>
        </div>
        """, unsafe_allow_html=True)

    st.divider()

    # ── Scraper Kontrolleri ───────────────────────────────────────
    st.subheader("🎮 Scraper Kontrolleri")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.markdown("#### 🔵 Arabam")
        if st.button("▶️ Arabam Başlat", key="start_arabam", use_container_width=True, type="primary"):
            try:
                resp = requests.post(f"{API_BASE}/start/arabam", timeout=10)
                if resp.status_code == 200:
                    st.success("✅ Arabam scraper arka planda başlatıldı!")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"❌ Hata: {resp.json().get('detail', 'Bilinmeyen hata')}")
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

        if st.button("⏹️ Arabam Durdur", key="stop_arabam", use_container_width=True):
            try:
                resp = requests.post(f"{API_BASE}/stop/arabam", timeout=10)
                if resp.status_code == 200:
                    st.warning("⚠️ Arabam scraper durduruldu.")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"❌ Hata: {resp.json().get('detail', 'Bilinmeyen hata')}")
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

    with col2:
        st.markdown("#### ⭐ Borusan")
        if st.button("▶️ Borusan Başlat", key="start_borusan", use_container_width=True, type="primary"):
            try:
                resp = requests.post(f"{API_BASE}/start/borusan", timeout=10)
                if resp.status_code == 200:
                    st.success("✅ Borusan scraper arka planda başlatıldı!")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"❌ Hata: {resp.json().get('detail', 'Bilinmeyen hata')}")
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

        if st.button("⏹️ Borusan Durdur", key="stop_borusan", use_container_width=True):
            try:
                resp = requests.post(f"{API_BASE}/stop/borusan", timeout=10)
                if resp.status_code == 200:
                    st.warning("⚠️ Borusan scraper durduruldu.")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"❌ Hata: {resp.json().get('detail', 'Bilinmeyen hata')}")
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

    with col3:
        st.markdown("#### 🚀 Tümü")
        if st.button("▶️ Tümünü Başlat", key="start_all", use_container_width=True, type="primary"):
            try:
                resp = requests.post(f"{API_BASE}/start/all", timeout=10)
                if resp.status_code == 200:
                    st.success("✅ Tüm scraper'lar arka planda başlatıldı!")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"❌ Hata: {resp.json().get('detail', 'Bilinmeyen hata')}")
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

        if st.button("⏹️ Tümünü Durdur", key="stop_all", use_container_width=True):
            try:
                # Her iki kaynağı da durdur
                for source in ["arabam", "borusan"]:
                    requests.post(f"{API_BASE}/stop/{source}", timeout=10)
                st.warning("⚠️ Tüm scraper'lar durduruldu.")
                time.sleep(1)
                st.rerun()
            except Exception as e:
                st.error(f"❌ Bağlantı hatası: {e}")

    st.divider()

    # ── Scraper Konfigürasyonu ────────────────────────────────────
    st.subheader("⚙️ Konfigürasyon")

    config_data = {}
    try:
        resp = requests.get(f"{API_BASE}/config", timeout=5)
        if resp.status_code == 200:
            config_data = resp.json()
    except Exception:
        pass

    if config_data:
        col_c1, col_c2 = st.columns(2)

        with col_c1:
            ac = config_data.get("arabam", {})
            st.json({
                "Kaynak": "Arabam",
                "Aktif": ac.get("enabled", True),
                "Headless": ac.get("headless", True),
                "Max İlan": ac.get("max_listings", 50),
                "Timeout": ac.get("timeout", 30)
            })

        with col_c2:
            bc = config_data.get("borusan", {})
            st.json({
                "Kaynak": "Borusan",
                "Aktif": bc.get("enabled", True),
                "Headless": bc.get("headless", True),
                "Max İlan": bc.get("max_listings", 30),
                "Timeout": bc.get("timeout", 20)
            })
    else:
        st.info("Konfigürasyon yüklenemedi.")

    # ── Docker Worker Durumu ──────────────────────────────────────
    st.divider()
    st.subheader("🐳 Docker Worker Durumu")
    st.info(f"Aktif Worker: {status_data.get('active_workers', '?')} / {status_data.get('total_workers', '?')}")