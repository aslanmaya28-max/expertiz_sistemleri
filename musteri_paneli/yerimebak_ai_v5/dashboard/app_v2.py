import streamlit as st
import time
import html
from datetime import datetime, timedelta
import sys
import os
from pathlib import Path

# ── Windows Asyncio Fix (v8.1) ────────────────────────────────────────────────
# Playwright and subprocesses on Windows require ProactorEventLoop.
import asyncio
if sys.platform == 'win32':
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

# ── Path düzeltmesi (v8.1 - Pathlib kullanımı) ─────────────────────────────────
# Bu dosya: yerimebak_ai_v5/dashboard/app_v2.py
# Pathlib ile modern ve güvenilir path yönetimi
_DASHBOARD_DIR = Path(__file__).resolve().parent               # .../dashboard/
_V5_DIR = _DASHBOARD_DIR.parent                                # .../yerimebak_ai_v5/
_ROOT_DIR = _V5_DIR.parent                                     # proje kökü

# Sys.path'e ekle (string conversion)
for path_dir in [_ROOT_DIR, _V5_DIR]:
    path_str = str(path_dir)
    if path_str not in sys.path:
        sys.path.insert(0, path_str)

from yerimebak_ai_v5.dashboard.services.live_data_service_v2 import get_live_service_v2
import json
import pandas as pd
from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData, DemandLevel, Seasonality, DamageLevel
from yerimebak_ai_v5.core.opportunity_engine import OpportunityEngine
from yerimebak_ai_v5.core.condition_analyzer import get_condition_analyzer, ConditionAnalyzer
from yerimebak_ai_v5.core.risk_engine_v8 import get_risk_engine_v8, RiskEngineV8
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
try:
    import plotly.express as px
    import plotly.graph_objects as go
    _PLOTLY_OK = True
except ImportError:
    _PLOTLY_OK = False

try:
    from streamlit_autorefresh import st_autorefresh
    _AUTOREFRESH_OK = True
except ImportError:
    st.warning("Please install streamlit-autorefresh: pip install streamlit-autorefresh")
    _AUTOREFRESH_OK = False

# streamlit-echarts removed — Plotly gauge used instead (DRY, one less dependency)
_ECHARTS_OK = False

# v8.0 Engine instances
v8_engine = YerimebakEngineV8(verbose=False)
condition_analyzer = get_condition_analyzer()
risk_engine_v8 = get_risk_engine_v8()

# Canlı veri servisi v2
live_service = get_live_service_v2()

# Analiz sayfası (Lazy Import with Diagnostics)
_ANALIZ_OK = False
_ANALIZ_ERR = ""
try:
    if str(_ROOT_DIR) not in sys.path:
        sys.path.insert(0, str(_ROOT_DIR))

    from yerimebak_ai_v5.dashboard.pages import analiz as analiz_page
    _ANALIZ_OK = True
except Exception as _e:
    import traceback
    _ANALIZ_ERR = f"{type(_e).__name__}: {str(_e)}\n{traceback.format_exc()}"
    print(f"❌ [MainApp] Analiz modülü yükleme hatası: {_ANALIZ_ERR}")

# Modern Türkçe Dashboard v8.0 — YERİMEBAK AI
st.set_page_config(
    page_title="YERİMEBAK AI v8.0 | Final Dealer Master Engine",
    page_icon="🏛️",
    layout="wide",
    initial_sidebar_state="expanded",
)

# WCAG AA Uyumlu Modern Tema
def load_css():
    css_path = os.path.join(os.path.dirname(__file__), "static", "css", "dashboard_styles.css")
    try:
        with open(css_path, "r", encoding="utf-8") as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)
    except Exception as e:
        st.error(f"⚠️ CSS yüklenemedi: {e}")

load_css()

# CSS moved to static/css/dashboard_styles.css






















def render_header():
    """Modern header — admin detaylı, müşteri sade (v8.2)"""
    logged_in_user = st.session_state.get('logged_in_user')

    # Extremely Robust Admin Check (v8.3)
    is_admin = False
    if logged_in_user:
        u_email = str(logged_in_user.get('email', '')).lower().strip()
        u_role = str(logged_in_user.get('role', '')).lower().strip()
        u_name = str(logged_in_user.get('full_name', '')).lower().strip()
        is_admin = (u_email == 'admin@yerimebak.com' or u_role == 'admin' or u_name == 'admin@yerimebak.com')

    if is_admin:
        col1, col2, col3 = st.columns([2, 1, 1])
        with col1:
            st.title("🏛️ YERİMEBAK AI")
            st.markdown("### 🚀 Admin Panel")
        with col2:
            st.markdown(f"""
            <div style='background: rgba(5, 150, 105, 0.1);
                        padding: 15px; border-radius: 10px;
                        border: 1px solid rgba(5, 150, 105, 0.3);
                        text-align: center;'>
                <span class='live-indicator'></span>
                <strong style='color: #6EE7B7; font-size: 14px;'>CANLI AKIŞ</strong><br>
                <small style='color: #9CA3AF; font-size: 11px;'>{datetime.now().strftime('%d.%m.%Y - %H:%M:%S')}</small>
            </div>
            """, unsafe_allow_html=True)
        with col3:
            if st.button("🔄 Yenile", use_container_width=True):
                st.rerun()
            if _AUTOREFRESH_OK:
                st_autorefresh(interval=30000, key="dashboard_live_feed")
    else:
        # Müşteri: sade başlık
        st.markdown("""
        <div style='text-align: center; padding: 10px 0 5px 0;'>
            <h1 style='font-size: 2rem; font-weight: 900; color: #F8FAFC; margin: 0;'>🏪 YERİMEBAK AI</h1>
            <p style='color: #94A3B8; font-size: 0.9rem; margin: 5px 0 0 0;'>Araç Değerleme ve Fırsat Platformu</p>
        </div>
        """, unsafe_allow_html=True)


def render_detailed_listing_card(listing, index):
    """Detaylı ilan kartı render et - v8.0 Engine ile"""
    # --- CSS MODERNİZASYONU ---
    st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

    .stApp {
        font-family: 'Inter', sans-serif;
    }

    /* Modern Kart Tasarımı */
    .listing-card-v8 {
        background: rgba(30, 41, 59, 0.7);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(148, 163, 184, 0.1);
        border-radius: 16px;
        padding: 24px;
        margin-bottom: 24px;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
    }

    /* v8.0 Expander Animasyonları */
    div[data-testid="stExpander"] details summary {
        transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) !important;
        border-radius: 12px;
        background: linear-gradient(90deg, rgba(30, 41, 59, 0.6), rgba(15, 23, 42, 0.8)) !important;
        border: 1px solid rgba(148, 163, 184, 0.15);
        padding: 10px 15px !important;
    }
    div[data-testid="stExpander"] details summary:hover {
        transform: scale(1.02) translateX(10px) !important;
        background: linear-gradient(90deg, rgba(30, 41, 59, 0.9), rgba(37, 99, 235, 0.2)) !important;
        box-shadow: -5px 5px 20px rgba(96, 165, 250, 0.4) !important;
        border-color: rgba(96, 165, 250, 0.8) !important;
    }
    div[data-testid="stExpander"] details summary p {
        font-weight: 800 !important;
        font-size: 1.15rem !important;
        color: #F8FAFC !important;
        transition: color 0.3s ease !important;
    }
    div[data-testid="stExpander"] details summary:hover p {
        color: #60A5FA !important;
        text-shadow: 0 0 8px rgba(96, 165, 250, 0.6) !important;
    }

    .tech-label {
        color: #94A3B8;
        font-size: 0.8rem;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.025em;
    }

    .tech-value {
        color: #F1F5F9;
        font-size: 1rem;
        font-weight: 600;
        margin-bottom: 8px;
    }

    .ai-metric-box {
        background: rgba(15, 23, 42, 0.5);
        border-radius: 12px;
        padding: 12px;
        text-align: center;
        border: 1px solid rgba(148, 163, 184, 0.15);
    }

    .badge-v8 {
        padding: 4px 12px;
        border-radius: 9999px;
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
    }
    </style>
    """, unsafe_allow_html=True)

    with st.container():
        # HTML Wrapper Başlangıç
        st.markdown('<div class="listing-card-v8">', unsafe_allow_html=True)

        # 3 Kolonlu Ana Düzen (v8.0 Premium)
        # c1: Görsel, c2: Detaylar, c3: AI Analizi
        c1, c2, c3 = st.columns([1.2, 1.5, 1])

        # v8.0 ENGINE - Profesyonel Galeri Analizi
        # Raw value extraction with robust fallback
        raw_year = listing.get('year')
        if raw_year is None: raw_year = 2020
        current_year = 2026
        safe_year = min(int(raw_year), current_year)

        km = listing.get('km')
        if km is None or str(km).lower() == 'standart':
            km = 0
        try:
            km = int(str(km).replace('.', '').replace(',', '').strip())
        except:
            km = 0

        price = listing.get('price')
        if price is None or price == 0: price = 1
        try:
            price = float(str(price).replace('.', '').replace(',', '').strip())
        except:
            price = 1
        market_reference = get_market_reference_service().get_reference(
            brand=str(listing.get('brand') or ''),
            model=str(listing.get('model') or ''),
            year=safe_year,
            km=km,
            fuel=listing.get('fuel_type') or listing.get('fuel'),
            transmission=listing.get('gear_type') or listing.get('transmission'),
            exclude_id=listing.get('id'),
            listed_price=price,
        )
        market_avg = listing.get('market_avg') or market_reference.get('market_avg_price') or price

        # Boya bilgisini al ve formatla
        paint_info = listing.get('paint_info', {})
        if isinstance(paint_info, str):
            try:
                parsed = json.loads(paint_info)
                if isinstance(parsed, str):
                    parsed = json.loads(parsed)
                paint_info = parsed
            except:
                try:
                    import ast
                    paint_info = ast.literal_eval(paint_info)
                except:
                    paint_info = {}

        if not isinstance(paint_info, dict):
            paint_info = {}

        # Boya verisini paint_data formatına çevir
        paint_data_list = []
        local_paint_parts_list = []

        if paint_info:
            # Yeni format: local_paint_parts ve painted_parts alanları var
            local_parts = paint_info.get('local_paint_parts', [])
            painted_parts = paint_info.get('painted_parts', [])

            # Eğer yeni format alanları boşsa, eski formattaki details alanını kontrol et
            if not local_parts and not painted_parts and paint_info.get('details'):
                # Eski format: details alanından parçaları çıkar
                # Önce tüm boyalı parçaları topla (duplicate kontrolü ile)
                all_painted_parts = []
                details = paint_info.get('details', [])
                for detail in details:
                    if 'Lokal boyalı' in detail:
                        # Lokal boyalı parçaları çıkar
                        lines = detail.split('\n')
                        for i, line in enumerate(lines):
                            if i > 0 and line.strip():  # İlk satır başlık, sonraki satırlar parçalar
                                part = line.strip()
                                if part and part != '-' and part not in all_painted_parts:
                                    all_painted_parts.append(part)
                                    local_paint_parts_list.append(part)
                    elif 'Boyalı' in detail:
                        # Normal boyalı parçaları çıkar
                        lines = detail.split('\n')
                        for i, line in enumerate(lines):
                            if i > 0 and line.strip():  # İlk satır başlık, sonraki satırlar parçalar
                                part = line.strip()
                                if part and part != '-' and part not in all_painted_parts:
                                    all_painted_parts.append(part)

                # Şimdi paint_data_list'i oluştur
                for part in all_painted_parts:
                    if part in local_paint_parts_list:
                        paint_data_list.append({
                            "location": part,
                            "condition": "LOCAL"
                        })
                    else:
                        paint_data_list.append({
                            "location": part,
                            "condition": "PAINTED"
                        })
            else:
                # Yeni format: local_paint_parts ve painted_parts alanlarını kullan
                for part in local_parts:
                    paint_data_list.append({
                        "location": part,
                        "condition": "LOCAL"
                    })
                    local_paint_parts_list.append(part)

                for part in painted_parts:
                    if part not in local_parts:  # Lokal olanları tekrar ekleme
                        paint_data_list.append({
                            "location": part,
                            "condition": "PAINTED"
                        })

        # Değişen parçaları al
        changed_parts_list = []
        if paint_info:
            # Önce direkt listeden al
            changed_parts_list = paint_info.get('changed_parts', [])

            # Eğer liste boşsa details'dan dene (eski/raw veri desteği)
            if not changed_parts_list and paint_info.get('details'):
                details = paint_info.get('details', [])
                for detail in details:
                    if 'Değişmiş' in detail and 'Değişen parça' not in detail:
                        lines = detail.split('\n')
                        for i, line in enumerate(lines):
                            if i > 0 and line.strip():
                                part = line.strip()
                                invalid_entries = ['Boyalı', 'Lokal Boyalı', 'Değişmiş', 'Belirtilmemiş', '-', '']
                                if part and part not in invalid_entries:
                                    changed_parts_list.append(part)

        # Duplikeleri temizle ve liste olduğundan emin ol
        if not isinstance(changed_parts_list, list):
            changed_parts_list = []
        changed_parts_list = list(set([str(p) for p in changed_parts_list if p]))

        # Hasar miktarını açıklama metninden çıkar
        damage_amount = 0
        description = listing.get('description', '') or listing.get('accident_record', '')
        if description and isinstance(description, str):
            import re
            # "25.000 tl", "25.000₺", "25000 tl", "25.000 kayıt" formatlarını ara
            # Not: "KAYIT" kelimesi de hasar kaydı anlamına geliyor
            match = re.search(r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?)\s*(?:tl|₺|kayıt)', description, re.IGNORECASE)
            if match:
                try:
                    # Virgül ve noktaları temizle
                    amount_str = match.group(1).replace('.', '').replace(',', '')
                    damage_amount = float(amount_str)
                except:
                    pass

        # Hasar seviyesini tespit et
        title_str = str(listing.get('title', '')).lower()
        if 'ağır' in title_str or 'heavy' in title_str:
            damage_level = DamageLevel.HEAVY
        elif 'orta' in title_str or 'medium' in title_str:
            damage_level = DamageLevel.MEDIUM
        elif 'hafif' in title_str or 'light' in title_str:
            damage_level = DamageLevel.LIGHT
        else:
            damage_level = DamageLevel.NONE

        painted_locations = [str(p.get('location', '')) for p in paint_data_list if p and p.get('location')]

        # v8.0 VehicleData oluştur (Boya ve Değişen verileri eklendi)
        vehicle = VehicleData(
            make_model=f"{listing.get('brand', '')} {listing.get('model', '')}",
            year=safe_year,
            mileage_km=int(km) if km else 0,
            fuel_type=listing.get('fuel', 'Bilinmiyor'),
            gear_type=listing.get('transmission', 'Bilinmiyor'),
            listed_price=float(price),
            market_price_avg=float(market_avg),
            damage_level=damage_level.value,
            bodywork_status=changed_parts_list + painted_locations,
            demand_level=listing.get('demand_level', 'MEDIUM'),
            seasonality='NORMAL'
        )

        # v8.0 Analizi çalıştır
        try:
            valuation = v8_engine.analyze(vehicle)
        except Exception as e:
            st.error(f"Engine analyze error: {e}")
            from yerimebak_ai_v5.core.engine_v8 import DealerVerdict, CommercialAnalysis, LiquidityMetrics, TechnicalScoring
            class MockValuation:
                technical_scoring = TechnicalScoring(opportunity_score=50, risk_percentage=50)
                commercial_analysis = CommercialAnalysis(optimal_purchase_price=price*0.9, net_profit_tl=0, net_margin_percent=0, estimated_total_cost=price*0.95, maximum_purchase_price=price*0.9)
                liquidity_metrics = LiquidityMetrics(estimated_days_to_sell=30, liquidity_score=50)
                dealer_verdict = DealerVerdict(decision='HOLD', action_note='Analiz basarisiz')

                # Mock exit_strategy handling
                class MockExit:
                    estimated_exit_price = price
                exit_strategy = MockExit()
            valuation = MockValuation()

        # Deterministic Risk Engine v8.0 - Boya ve KM analizi
        # paint_data_list içinde condition: "LOCAL" veya "PAINTED" olan parçalar var
        painted_count = len([p for p in paint_data_list if p.get('condition') in ['PAINTED', 'PLATED']])
        local_paint_count = len([p for p in paint_data_list if p.get('condition') == 'LOCAL'])

        try:
            risk_v8_result = risk_engine_v8.calculate({
                "price": float(price),
                "vehicle_km": int(km) if km else 0,
                "market_average_km": safe_year * 20000,  # Yıllık 20.000 KM
                "painted_parts": painted_count,
                "local_paint_parts": local_paint_count,
                "changed_parts": changed_parts_list if changed_parts_list else [],
                "damage_amount": damage_amount,  # Regex ile çekilen hasar miktarı kullanılıyor
                "package_level": listing.get('package_info', 'BASE'),
                "has_paint_flag": paint_info.get('has_paint', False) if paint_info else False,
                "has_changed_flag": paint_info.get('has_changed', False) if paint_info else False
            })
        except:
            risk_v8_result = {"total_risk": 50, "paint_risk": 0, "change_risk": 0}

        # UI Verileri
        title = f"{str(listing.get('brand', '')).title()} {str(listing.get('model', '')).title()} ({safe_year})"
        image_url = listing.get('image_url', '')
        opp_score = valuation.technical_scoring.opportunity_score
        risk_score = valuation.technical_scoring.risk_percentage
        action = valuation.dealer_verdict.decision

        # v8.0 Ticari Veriler
        net_profit = valuation.commercial_analysis.net_profit_tl
        net_margin = valuation.commercial_analysis.net_margin_percent
        exit_price = valuation.exit_strategy.estimated_exit_price
        optimal_price = valuation.commercial_analysis.optimal_purchase_price
        days_to_sell = valuation.liquidity_metrics.estimated_days_to_sell

        # Galerici Kararı - Risk Engine ve Kar Marjı ile tutarlı hale getir
        # Negatif kar varsa veya yüksek risk varsa "KAÇIN" demeli
        if net_profit < 0 or risk_score > 50:
            action = "AVOID"
        elif net_profit < 20000 or risk_score > 35:
            action = "HOLD"
        elif net_profit > 50000 and risk_score < 25:
            action = "STRONG_BUY"
        elif net_profit > 30000:
            action = "BUY"
        else:
            action = "NEGOTIATE"

        # Boya Durumu Badge (Kullanıcı isteği - v8.0 Detaylı)
        p_status = "Bilinmiyor"
        p_color = "#94A3B8"

        # Risk Engine v8 sonuçlarını baz al (Daha güvenilir)
        if risk_v8_result:
            total_risk = risk_v8_result.get('total_risk', 0)
            paint_risk_v8 = risk_v8_result.get('paint_risk', 0)
            change_risk_v8 = risk_v8_result.get('change_risk', 0)

            # Flag'leri kontrol et (Liste boş olsa bile flag True olabilir)
            has_changed_flag = paint_info.get('has_changed', False) if paint_info else False
            has_paint_flag = paint_info.get('has_paint', False) if paint_info else False

            if change_risk_v8 > 0 or has_changed_flag:
                p_status = "Değişen Var"
                p_color = "#f87171" # Kırmızı
            elif paint_risk_v8 > 0 or has_paint_flag:
                # Boyalı parça sayısını göster
                p_count = painted_count + local_paint_count
                p_status = f"{p_count} Parça Boyalı" if p_count > 0 else "Boyalı Parça Var"
                p_color = "#FBBF24" # Sarı
            elif total_risk < 5:
                p_status = "Hatasız / Orijinal"
                p_color = "#4ade80" # Yeşil
            else:
                p_status = "Orijinal / Hafif Risk"
                p_color = "#4ade80"

        # 1. KOLON: GÖRSEL VE BAŞLIK
        with c1:
            badge_icon = "🔵" if "arabam" in listing['source'].lower() else "⭐"
            url = listing.get('url', '#')
            # 🔒 GÜVENLİK: XSS korumasi - URL'yi HTML escape et
            safe_url = html.escape(str(url))
            safe_title = html.escape(str(title))

            st.markdown(f"**{badge_icon} <a href='{safe_url}' target='_blank' style='color: #60A5FA; text-decoration: none; font-size: 1.1rem;'>{safe_title}</a>**", unsafe_allow_html=True)

            # Araç Görseli (Çözünürlük Korumalı)
            if image_url and str(image_url).lower() != 'none' and "consentmanager.net/delivery/flags/tr.gif" not in str(image_url):
                # HD Kalite İyileştirmesi (Thumbnail to Original Dönüşümü)
                hd_url = str(image_url)
                hd_url = hd_url.replace('240x180', '800x600').replace('120x90', '800x600').replace('160x120', '800x600').replace('480x360', '800x600')
                hd_url = hd_url.replace('/thmb_', '/').replace('/thumb/', '/origin/')


                st.markdown(f"""
                <div style='width: 100%; height: 200px; border-radius: 12px; overflow: hidden;
                            border: 1px solid rgba(148, 163, 184, 0.2);
                            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.2);
                            margin: 15px auto; background: #0f172a; text-align: center; position: relative; display: flex; align-items: center; justify-content: center;'>
                    <a href='{url}' target='_blank' style='display: block; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center;'>
                        <img src='{hd_url}'
                             style='max-width: 100%; max-height: 100%; object-fit: contain; backdrop-filter: blur(10px);'>
                        <div style='position: absolute; bottom: 8px; right: 8px; background: rgba(0,0,0,0.7); color: #fff; font-size: 0.65rem; padding: 4px 8px; border-radius: 6px; font-weight: bold; border: 1px solid rgba(255,255,255,0.2); backdrop-filter: blur(4px);'>HD 💎</div>
                    </a>
                </div>
                """, unsafe_allow_html=True)
            else:
                # Placeholder for missing image
                st.markdown(f"""
                <div style='width: 100%; height: 180px; background: #1E293B; border-radius: 12px;
                            display: flex; align-items: center; justify-content: center; margin: 15px 0;
                            border: 1px dashed rgba(148, 163, 184, 0.3); color: #64748B;'>
                    <div style='text-align: center;'>
                        <div style='font-size: 2rem;'>📷</div>
                        <div style='font-size: 0.8rem;'>Görsel Yok</div>
                    </div>
                </div>
                """, unsafe_allow_html=True)

            # Fırsat Badge'i
            if opp_score > 75:
                st.markdown('<div style="background: linear-gradient(90deg, #F59E0B, #EF4444); color: white; padding: 4px 12px; border-radius: 8px; font-size: 0.8rem; font-weight: bold; text-align: center; margin-top: 10px;">🔥 YÜKSEK FIRSAT SKORU</div>', unsafe_allow_html=True)

        # 2. KOLON: ARAÇ ÖZELLİKLERİ (Kompakt ve Net Liste)
        with c2:
            st.markdown('<div style="padding-left: 20px; border-left: 1px solid rgba(148, 163, 184, 0.1); margin-top: -10px;">', unsafe_allow_html=True)

            # Güncel İlan Fiyatı (Hala en üstte, belirgin)
            st.markdown(f'<div style="color: #F8FAFC; font-size: 1.8rem; font-weight: 900; margin-bottom: 12px; letter-spacing: -0.02em;">{price:,.0f} ₺</div>', unsafe_allow_html=True)

            # Rapor Konteynırı
            st.markdown('<div class="report-container">', unsafe_allow_html=True)

            def render_tech_row(label, value):
                # Robust value handling
                if value is None:
                    value = "Belirtilmedi"

                v_str = str(value).strip()
                if not v_str or v_str.lower() in ['none', 'belirtilmemiş', '0', '0.0']:
                    v_str = "Belirtilmedi"

                st.markdown(f"""
                    <div class="report-row" style="padding: 4px 0;">
                        <div class="report-label" style="font-size: 0.7rem; letter-spacing: 0;">{label}</div>
                        <div class="report-value" style="font-size: 0.85rem; font-weight: 600;">{v_str}</div>
                    </div>
                """, unsafe_allow_html=True)

            # 1. İlan Tarihi
            raw_date = listing.get("listing_date", "-")
            try:
                dt = datetime.strptime(raw_date, "%Y-%m-%d")
                aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
                formatted_date = f"{dt.day} {aylar[dt.month-1]} {dt.year}"
            except:
                formatted_date = raw_date
            render_tech_row("İlan Tarihi", formatted_date)

            # 2. Marka
            brand_val = str(listing.get('brand') or '').title()
            render_tech_row("Marka", brand_val)

            # 3. Seri
            series_val = str(listing.get('series', '') or 'Belirtilmemiş').title()
            render_tech_row("Seri", series_val)

            # 4. Model
            model_val = str(listing.get('model', '') or 'Standart').title()
            render_tech_row("Model", model_val)

            # 5. Yıl
            render_tech_row("Yıl", str(safe_year))

            # 6. Kilometre
            km_val = int(km) if km is not None else 0
            render_tech_row("Kilometre", f"{km_val:,} km")

            # 7. Vites Tipi
            trans_val = str(listing.get("transmission") or "Standart").title()
            render_tech_row("Vites Tipi", trans_val)

            # 8. Yakıt Tipi
            fuel_val = str(listing.get("fuel") or "Standart").title()
            render_tech_row("Yakıt Tipi", fuel_val)

            # 9. Kasa Tipi
            body_val = str(listing.get("body_type") or "Standart").title()
            render_tech_row("Kasa Tipi", body_val)

            # 10. Renk
            color_val = str(listing.get("color") or "Standart").title()
            render_tech_row("Renk", color_val)

            # 11. Motor Hacmi
            m_hacim = listing.get('engine_size') or "Belirtilmemiş"
            render_tech_row("Motor Hacmi", m_hacim)

            # 12. Motor Gücü
            m_guc = listing.get('horsepower') or "Belirtilmemiş"
            render_tech_row("Motor Gücü", m_guc)

            st.markdown('</div>', unsafe_allow_html=True)
            st.markdown('</div>', unsafe_allow_html=True)

        # 3. KOLON: AI ANALİZİ VE KARAR (KADRANLI TASARIM)
        with c3:
            st.markdown('<div style="padding-left: 10px; height: 100%;">', unsafe_allow_html=True)

            profit_color = "#4ade80" if net_profit > 0 else "#f87171"
            r_color = "#4ade80" if risk_score < 25 else "#FBBF24" if risk_score < 45 else "#f87171"

            action_tr = {
                "BUY": "ALINABİLİR",
                "STRONG_BUY": "YÜKSEK ÖNCELİK",
                "NEGOTIATE": "PAZARLIK YAP",
                "HOLD": "BEKLE",
                "AVOID": "KAÇIN"
            }.get(action, action)

            main_color = "#10B981" if "BUY" in action else "#F59E0B" if "NEGOTIATE" in action or "HOLD" in action else "#EF4444"

            # Birleştirilmiş Yapay Zeka Skoru Hesaplama (0-100)
            # 100 = Yüksek Fırsat, Yüksek Kar, Düşük Risk
            profit_score = max(0, min(100, (net_profit / 50000) * 100)) # 50k TL ve üstü kar = 100 puan
            safe_score = max(0, 100 - risk_score) # 0 risk = 100 güvenli puan

            ai_score = (opp_score * 0.3) + (profit_score * 0.4) + (safe_score * 0.3)
            gauge_val = int(max(0, min(100, ai_score)))

            if gauge_val < 35:
                status_text = "RİSKLİ / RISKY"
                status_color = "#ff4d4d"
                needle_color = "#ff4d4d"
            elif gauge_val < 70:
                status_text = "ORTA / INTERMEDIATE"
                status_color = "#ffcc00"
                needle_color = "#ffcc00"
            else:
                status_text = "FIRSAT / OPPORTUNITY"
                status_color = "#2ecc71"
                needle_color = "#2ecc71"

            date_str = listing.get("listing_date", "-")
            if "-" in str(date_str) and len(str(date_str)) > 5:
                try:
                    dt = datetime.strptime(str(date_str).strip(), "%Y-%m-%d")
                    ay_isimleri = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
                    formatted_date_str = f"{dt.day} {ay_isimleri[dt.month-1]} {dt.year}"
                except:
                    formatted_date_str = str(date_str)
            else:
                formatted_date_str = str(date_str)

            gauge_options = {
                "backgroundColor": "transparent",
                "series": [
                    {
                        "type": "gauge",
                        "startAngle": 210,
                        "endAngle": -30,
                        "min": 0,
                        "max": 100,
                        "splitNumber": 10,
                        "radius": "100%",
                        "axisLine": {
                            "lineStyle": {
                                "width": 18,
                                "color": [
                                    [0.33, "#ff4d4d"],
                                    [0.66, "#ffcc00"],
                                    [1, "#2ecc71"]
                                ],
                                "shadowColor": "rgba(0, 0, 0, 0.5)",
                                "shadowBlur": 10
                            }
                        },
                        "pointer": {
                            "icon": "path://M12.8,0.7l12,40.1H0.7L12.8,0.7z",
                            "length": "65%",
                            "width": 6,
                            "offsetCenter": [0, "-10%"],
                            "itemStyle": {
                                "color": needle_color,
                                "shadowColor": "rgba(0, 0, 0, 0.3)",
                                "shadowBlur": 5
                            }
                        },
                        "axisTick": {
                            "length": 8,
                            "lineStyle": {
                                "color": "auto",
                                "width": 1
                            }
                        },
                        "splitLine": {
                            "length": 15,
                            "lineStyle": {
                                "color": "auto",
                                "width": 3
                            }
                        },
                        "axisLabel": {
                            "color": "#94A3B8",
                            "fontSize": 11,
                            "distance": 22,
                            "fontWeight": "bold"
                        },
                        "title": {
                            "offsetCenter": [0, "30%"],
                            "fontSize": 9,
                            "color": "#94A3B8",
                            "fontWeight": "bold"
                        },
                        "detail": {
                            "valueAnimation": True,
                            "formatter": "{value}%",
                            "color": status_color,
                            "fontSize": 20,
                            "fontWeight": "bolder",
                            "offsetCenter": [0, "65%"]
                        },
                        "data": [
                            {
                                "value": int(gauge_val),
                                "name": "YAPAY ZEKA SKORU"
                            }
                        ]
                    }
                ]
            }

            st.markdown(f"""
            <div style="background: rgba(15, 23, 42, 0.4); border-radius: 16px; padding: 15px; border: 1px solid rgba(148, 163, 184, 0.1); height: 100%; display: flex; flex-direction: column; justify-content: space-between;">
                <div style="text-align: center; margin-bottom: 5px;">
                    <span style="font-size: 1.1rem; font-weight: 900; color: {main_color}; letter-spacing: 0.05em; text-shadow: 0 0 10px {main_color}44;">🎯 {action_tr}</span>
                </div>
            """, unsafe_allow_html=True)

            if _PLOTLY_OK:
                fig_gauge = go.Figure(go.Indicator(
                    mode = "gauge+number",
                    value = gauge_val,
                    number = {"suffix": "%", "font": {"size": 28, "color": status_color}},
                    title = {"text": "YAPAY ZEKA SKORU", "font": {"size": 10, "color": "#94A3B8"}},
                    gauge = {
                        "axis": {"range": [0, 100], "tickwidth": 1, "tickcolor": "#475569"},
                        "bar": {"color": status_color, "thickness": 0.15},
                        "bgcolor": "rgba(15,23,42,0.3)",
                        "borderwidth": 0,
                        "steps": [
                            {"range": [0, 35], "color": "rgba(255,77,77,0.15)"},
                            {"range": [35, 70], "color": "rgba(255,204,0,0.12)"},
                            {"range": [70, 100], "color": "rgba(46,204,113,0.15)"}
                        ],
                        "threshold": {
                            "line": {"color": status_color, "width": 4},
                            "thickness": 0.8,
                            "value": gauge_val
                        }
                    }
                ))
                fig_gauge.update_layout(
                    height=220,
                    margin=dict(l=20, r=20, t=50, b=10),
                    paper_bgcolor="rgba(0,0,0,0)",
                    font={"color": "#F1F5F9"}
                )
                st.plotly_chart(fig_gauge, use_container_width=True, key=f"dealer_gauge_{index}_{listing.get('id', int(time.time()))}")

            metrics_html = f"""
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 5px;">
                    <div style="background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.05); border-radius: 8px; padding: 6px; text-align: center;">
                        <div style="color: #94A3B8; font-size: 0.6rem; font-weight: 700;">KAR</div>
                        <div style="color: {profit_color}; font-size: 0.95rem; font-weight: 900; margin-top: 2px;">{net_profit:,.0f} ₺</div>
                    </div>
                    <div style="background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.05); border-radius: 8px; padding: 6px; text-align: center;">
                        <div style="color: #94A3B8; font-size: 0.6rem; font-weight: 700;">MARJ</div>
                        <div style="color: {profit_color}; font-size: 0.95rem; font-weight: 900; margin-top: 2px;">%{net_margin:.1f}</div>
                    </div>
                    <div style="background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.05); border-radius: 8px; padding: 6px; text-align: center;">
                        <div style="color: #94A3B8; font-size: 0.6rem; font-weight: 700;">FIRSAT</div>
                        <div style="color: #60A5FA; font-size: 0.95rem; font-weight: 900; margin-top: 2px;">{opp_score}</div>
                    </div>
                    <div style="background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.05); border-radius: 8px; padding: 6px; text-align: center;">
                        <div style="color: #94A3B8; font-size: 0.6rem; font-weight: 700;">RİSK</div>
                        <div style="color: {r_color}; font-size: 0.95rem; font-weight: 900; margin-top: 2px;">%{int(risk_score)}</div>
                    </div>
                </div>
                <div style="margin-top: 10px; text-align: center; color: #64748B; font-size: 0.7rem; font-weight: 600;">
                    İlan Tarihi: {formatted_date_str}
                </div>
            </div>
            """
            st.markdown(metrics_html, unsafe_allow_html=True)
            st.markdown('</div>', unsafe_allow_html=True)

        # HTML Wrapper Bitiş (Listeleme Kartı Bitiş)
        st.markdown('</div>', unsafe_allow_html=True)

        # Detaylı bilgiler (expandable) - v8.0 Profesyonel Analiz
        # Kartın DIŞINDA ve BİRAZ ALTINDA (margin ile ayrılmış)
        st.markdown("<div style='margin-bottom: 20px;'></div>", unsafe_allow_html=True)
        with st.expander("🔬 v8.0 Profesyonel Galeri Analizi", expanded=False):
            # CSS for compact internal grid
            st.markdown("""
                <style>
                .analysis-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 12px; }
                .analysis-card { background: rgba(15, 23, 42, 0.4); padding: 12px; border-radius: 12px; border: 1px solid rgba(148, 163, 184, 0.1); }
                .analysis-title { color: #94A3B8; font-size: 0.65rem; text-transform: uppercase; font-weight: 700; letter-spacing: 0.05em; }
                .analysis-val { font-size: 1.15rem; font-weight: 800; margin-top: 4px; }
                .sub-title-v8 { color: #60A5FA; font-size: 0.85rem; font-weight: 700; margin-bottom: 8px; margin-top: 15px; border-bottom: 1px solid rgba(96, 165, 250, 0.2); padding-bottom: 4px; }
                .metric-row { display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 0.85rem; }
                .metric-label { color: #94A3B8; }
                .metric-value { color: #F1F5F9; font-weight: 600; }
                </style>
            """, unsafe_allow_html=True)

            # --- BÖLÜM 1: TİCARİ ÖZET (GRID) ---
            st.markdown('<div class="analysis-grid">', unsafe_allow_html=True)
            p_color = "#4ade80" if net_profit > 0 else "#f87171"
            st.markdown(f"""
                <div class="analysis-card" style="border-left: 4px solid {p_color};">
                    <div class="analysis-title">Net Kar / Marj</div>
                    <div class="analysis-val" style="color: {p_color};">
                        {net_profit:,.0f} ₺ <span style='font-size: 0.8rem; opacity: 0.8;'>(%{net_margin:.1f})</span>
                    </div>
                </div>
                <div class="analysis-card" style="border-left: 4px solid #60A5FA;">
                    <div class="analysis-title">Hedef Satış / Piyasa</div>
                    <div class="analysis-val">
                        {exit_price:,.0f} ₺ <span style="font-size: 0.7rem; color: #60A5FA;">({market_avg:,.0f} ₺)</span>
                    </div>
                </div>
            """, unsafe_allow_html=True)
            st.markdown('</div>', unsafe_allow_html=True)

            # --- BÖLÜM 2: DETAYLI ANALİZ BLOKLARI ---
            col_a, col_b = st.columns(2)

            with col_a:
                st.markdown('<div class="sub-title-v8">🛡️ GÜVENLİ ALIM ANALİZİ</div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Toplam Maliyet:</span><span class="metric-value">{valuation.commercial_analysis.estimated_total_cost:,.0f} ₺</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Net Kar:</span><span class="metric-value" style="color: {p_color};">{net_profit:,.0f} ₺ (%{net_margin:.1f})</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Pazarlık Avantajı:</span><span class="metric-value" style="color: #4ade80;">{(price - optimal_price):,.0f} ₺</span></div>', unsafe_allow_html=True)

                st.markdown('<div class="sub-title-v8">🎯 TEKLİF REHBERİ</div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Optimum Fiyat:</span><span class="metric-value">{optimal_price:,.0f} ₺</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Maksimum Teklif:</span><span class="metric-value">{(optimal_price * 1.05):,.0f} ₺</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Çıkış Fiyatı:</span><span class="metric-value">{exit_price:,.0f} ₺</span></div>', unsafe_allow_html=True)

            with col_b:
                st.markdown('<div class="sub-title-v8">⚡ LİKİDİTE & RİSK</div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Tahmini Satış:</span><span class="metric-value">{days_to_sell} Gün</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Likidite Skoru:</span><span class="metric-value">%{valuation.liquidity_metrics.liquidity_score}</span></div>', unsafe_allow_html=True)
                st.markdown(f'<div class="metric-row"><span class="metric-label">Risk Skoru:</span><span class="metric-value">%{risk_score:.1f}</span></div>', unsafe_allow_html=True)

                # Teknik Riskler (Car Dashboard / İbreli Stil)
                st.markdown('<div class="sub-title-v8">🏎️ TEKNİK RİSKLER (V8)</div>', unsafe_allow_html=True)

                def car_dashboard_gauge(label, pct):
                    """SVG tabanlı yarım daire gösterge — Streamlit uyumlu"""
                    pct = max(0, min(100, float(pct)))
                    color = "#4ade80" if pct < 15 else ("#f87171" if pct > 45 else "#fbbf24")
                    # SVG arc: -180 (sol) → 0 (sağ), ibre açısı
                    import math
                    angle = math.radians(-180 + (180 * pct / 100))
                    # İbre uç noktası (yarıçap=30, merkez=50,45)
                    nx = 50 + 30 * math.cos(angle)
                    ny = 45 + 30 * math.sin(angle)
                    # Arc path: büyük yarım daire
                    arc_end_angle = math.radians(-180 + (180 * pct / 100))
                    ax = 50 + 35 * math.cos(arc_end_angle)
                    ay = 45 + 35 * math.sin(arc_end_angle)
                    # large-arc-flag
                    large = 1 if pct > 50 else 0

                    return f"""<div style="text-align:center;border:1px solid rgba(148,163,184,0.1);padding:12px 8px 8px;border-radius:12px;background:rgba(15,23,42,0.5);">
<svg width="100" height="58" viewBox="0 0 100 58" xmlns="http://www.w3.org/2000/svg">
  <path d="M 15 45 A 35 35 0 0 1 85 45" fill="none" stroke="{color}33" stroke-width="7" stroke-linecap="round"/>
  <path d="M 15 45 A 35 35 0 {large} 1 {ax:.1f} {ay:.1f}" fill="none" stroke="{color}" stroke-width="7" stroke-linecap="round"/>
  <line x1="50" y1="45" x2="{nx:.1f}" y2="{ny:.1f}" stroke="#e2e8f0" stroke-width="3" stroke-linecap="round"/>
  <circle cx="50" cy="45" r="5" fill="#e2e8f0"/>
</svg>
<div style="color:{color};font-weight:900;font-size:1.1rem;margin-top:2px;">%{pct:.1f}</div>
<div style="font-size:0.6rem;letter-spacing:0.1em;color:#94A3B8;margin-top:2px;">{label}</div>
</div>"""

                tr1, tr2, tr3 = st.columns(3)
                with tr1: st.markdown(car_dashboard_gauge("KM RİSKİ", risk_v8_result.get('km_risk', 0)), unsafe_allow_html=True)
                with tr2: st.markdown(car_dashboard_gauge("BOYA RİSKİ", risk_v8_result.get('paint_risk', 0)), unsafe_allow_html=True)
                with tr3: st.markdown(car_dashboard_gauge("DEĞİŞEN RİSKİ", risk_v8_result.get('change_risk', 0)), unsafe_allow_html=True)

            # --- BÖLÜM 3: DETERMINISTIK KARAR ---
            st.markdown("<div style='margin-top: 15px;'></div>", unsafe_allow_html=True)
            d_en = risk_v8_result.get('decision', 'HOLD')
            d_score = risk_v8_result.get('opportunity_score', 0)
            if net_profit < 0 or action == "AVOID": d_en, d_score = "AVOID", 0

            d_tr = {"BUY": "AL", "STRONG_BUY": "YÜKSEK ÖNCELİKLE AL", "NEGOTIATE": "PAZARLIK YAP", "HOLD": "BEKLE", "AVOID": "KAÇIN"}.get(d_en, d_en)
            d_color = "#f87171" if d_en == "AVOID" else "#10B981" if "BUY" in d_en else "#F59E0B"
            st.markdown(f"""
                <div style="background: {d_color}11; border: 1px solid {d_color}33; padding: 12px; border-radius: 12px; text-align: center;">
                    <div style="color: {d_color}; font-weight: 900; font-size: 1.1rem; letter-spacing: 0.05em;">🎯 DETERMINISTIK KARAR: {d_tr}</div>
                    <div style="color: #94A3B8; font-size: 0.75rem; font-weight: 600; margin-top: 4px;">FIRSAT SKORU: {d_score}/100 | AI GÜVEN ENDEKSİ: %94</div>
                </div>
            """, unsafe_allow_html=True)

            # AI Analiz Notu (En alt) — KM + Boya/Değişen + Fiyat Etkisi
            notes = []

            # Piyasa değeri baz alınarak her faktörün TL etkisi hesaplanır
            market_val = exit_price or float(price)
            km_risk_pct = risk_v8_result.get('km_risk', 0) if risk_v8_result else 0
            paint_risk_pct = risk_v8_result.get('paint_risk', 0) if risk_v8_result else 0
            change_risk_pct = risk_v8_result.get('change_risk', 0) if risk_v8_result else 0

            # KM Analizi + TL Etki
            if km > 0:
                km_ann = condition_analyzer.analyze_km(int(km), safe_year, "medium")
                km_impact_tl = int(market_val * km_risk_pct / 100)
                km_note = km_ann.analysis_note
                if km_impact_tl > 0:
                    km_note += f" → <b style='color:#f87171;'>Fiyat etkisi: -{km_impact_tl:,} ₺</b>"
                notes.append(km_note)

            # Boya/Değişen panel bilgisi + TL Etki
            try:
                raw_paint = listing.get('paint_info', '')
                if raw_paint and raw_paint != 'None':
                    import json as _json
                    pi = _json.loads(raw_paint) if isinstance(raw_paint, str) else raw_paint

                    painted = pi.get('painted_parts', [])
                    changed = pi.get('changed_parts', [])
                    original = pi.get('original_parts', [])

                    if changed:
                        change_impact_tl = int(market_val * change_risk_pct / 100)
                        change_note = f"🔴 Değişen: {', '.join(changed)}"
                        if change_impact_tl > 0:
                            change_note += f" → <b style='color:#f87171;'>Fiyat etkisi: -{change_impact_tl:,} ₺</b>"
                        notes.append(change_note)

                    if painted:
                        paint_impact_tl = int(market_val * paint_risk_pct / 100)
                        paint_note = f"🟠 Boyalı: {', '.join(painted)}"
                        if paint_impact_tl > 0:
                            paint_note += f" → <b style='color:#fbbf24;'>Fiyat etkisi: -{paint_impact_tl:,} ₺</b>"
                        notes.append(paint_note)

                    if original:
                        notes.append(f"🟢 Orijinal: {', '.join(original)}")

                    if not changed and not painted and pi.get('has_paint'):
                        paint_impact_tl = int(market_val * paint_risk_pct / 100)
                        pn = "🟠 Boyalı parça mevcut (detay belirtilmemiş)"
                        if paint_impact_tl > 0:
                            pn += f" → <b style='color:#fbbf24;'>Fiyat etkisi: -{paint_impact_tl:,} ₺</b>"
                        notes.append(pn)
                    if not changed and not painted and not original and pi.get('is_original'):
                        notes.append("🟢 Boyasız / Orijinal")
            except:
                pass

            if notes:
                notes_html = '<br>'.join(notes)
                st.markdown(f"""
                <div style='font-size: 0.75rem; color: #CBD5E1; margin-top: 20px; padding: 12px;
                            background: rgba(96, 165, 250, 0.08); border-radius: 12px;
                            border-left: 4px solid #60A5FA; display: flex; align-items: flex-start; gap: 10px;'>
                    <span style='font-size: 1.2rem; filter: saturate(0.5);'>ℹ️</span>
                    <div>
                        <b style='color: #60A5FA; display: block; margin-bottom: 4px; text-transform: uppercase; font-size: 0.65rem; letter-spacing: 0.05em;'>AI Analiz Notu</b>
                        {notes_html}
                    </div>
                </div>
                """, unsafe_allow_html=True)

        st.markdown("---")


def render_main_dashboard():
    """Ana dashboard - v2"""
    st.markdown("---")

    # Ana KPI Kartları
    st.subheader("📊 Ana Metrikler")

    # Gerçek canlı veri
    stats = live_service.get_market_stats()

    total_listings = sum(s.get('total', 0) for s in stats.values())
    avg_price = 0
    if stats:
        all_prices = []
        for source_data in stats.values():
            if source_data.get('avg_price'):
                all_prices.append(source_data['avg_price'])
        if all_prices:
            avg_price = sum(all_prices) / len(all_prices)

    # KPI Kartları
    col1, col2, col3, col4, col5, col6 = st.columns(6)

    total_listings = sum(s.get('total', 0) for s in stats.values())
    total_daily = sum(s.get('daily_total', 0) for s in stats.values())
    total_daily_opps = sum(s.get('daily_opportunities', 0) for s in stats.values())

    with col1:
        st.metric("📦 Toplam Havuz", f"{total_listings}", "Genel")
    with col2:
        st.metric("🔥 Günlük Fırsat", f"{total_daily_opps}", f"{total_daily} Toplam", delta_color="normal")
    with col3:
        s_ara = stats.get('arabam', {'total':0, 'daily_total':0, 'daily_opportunities':0})
        st.metric("🔵 Arabam", f"{s_ara.get('total', 0)}", f"+{s_ara.get('daily_total', 0)} ({s_ara.get('daily_opportunities', 0)}★)")
    with col4:
        s_bor = stats.get('borusan', {'total':0, 'daily_total':0, 'daily_opportunities':0})
        st.metric("⭐ Borusan", f"{s_bor.get('total', 0)}", f"+{s_bor.get('daily_total', 0)} ({s_bor.get('daily_opportunities', 0)}★)")
    with col5:
        s_sah = stats.get('sahibinden', {'total':0, 'daily_total':0, 'daily_opportunities':0})
        st.metric("🔴 Sahibinden", f"{s_sah.get('total', 0)}", f"+{s_sah.get('daily_total', 0)} ({s_sah.get('daily_opportunities', 0)}★)")
    with col6:
        st.empty()

    st.markdown("---")

    # Modern Filtreleme Sistemi (Radio Tab)
    st.subheader("🔍 İlan Filtreleme")

    col_f1, col_f2 = st.columns([3, 1])

    with col_f1:
        filter_mode = st.radio(
            "Filtre Modu Seçin:",
            [
                "📦 Tüm İlanlar",
                "🔥 Fırsat İlanlar",
                "✅ Hatasız (Hasarsız)",
                "🎨 Boyasız",
                "🎁 Full Paket"
            ],
            horizontal=True,
            label_visibility="collapsed"
        )

    with col_f2:
        # Marka Filtresi
        active_brands = live_service.get_active_brands()
        selected_brand = st.selectbox(
            "Marka Seçin:",
            ["Tüm Markalar"] + active_brands,
            label_visibility="collapsed"
        )

    # Zaman Filtresi (Logic injection point)
    time_filter = st.session_state.get('time_filter', 'Tümü')

    st.markdown("---")

    # SQL-level filtering for all modes — searches entire DB, not limited window
    listings = []
    if filter_mode == "📦 Tüm İlanlar":
        if selected_brand != "Tüm Markalar":
            listings = live_service.get_filtered_listings(brand=selected_brand, limit=500)
        else:
            listings = live_service.get_detailed_listings(limit=500)
    elif filter_mode == "🔥 Fırsat İlanlar":
        if selected_brand != "Tüm Markalar":
            all_brand = live_service.get_filtered_listings(brand=selected_brand, limit=5000)
            listings = [l for l in all_brand if l.get('opportunity_score') and float(l.get('opportunity_score', 0)) > 70]
        else:
            listings = live_service.get_opportunity_vehicles(limit=500)
    elif filter_mode == "✅ Hatasız (Hasarsız)":
        raw = live_service.get_no_accident_vehicles(limit=5000)
        if selected_brand != "Tüm Markalar":
            listings = [l for l in raw if str(l.get('brand', '')).strip().lower() == selected_brand.lower()]
        else:
            listings = raw
    elif filter_mode == "🎨 Boyasız":
        raw = live_service.get_no_paint_vehicles(limit=5000)
        if selected_brand != "Tüm Markalar":
            listings = [l for l in raw if str(l.get('brand', '')).strip().lower() == selected_brand.lower()]
        else:
            listings = raw
    elif filter_mode == "🎁 Full Paket":
        raw = live_service.get_full_package_vehicles(limit=5000)
        if selected_brand != "Tüm Markalar":
            listings = [l for l in raw if str(l.get('brand', '')).strip().lower() == selected_brand.lower()]
        else:
            listings = raw


    # Apply Time Filter
    if time_filter != "Tümü" and listings:
        now = datetime.now()
        filtered = []
        for l in listings:
            ldate = l.get('listing_date')
            if ldate:
                try:
                    # v13.3: Standardize date format for filtering
                    if "-" in ldate:
                        l_dt = datetime.strptime(ldate[:10], "%Y-%m-%d")
                        diff = now - l_dt
                        hours = diff.total_seconds() / 3600
                        if time_filter == "Son 24 Saat" and hours <= 24:
                            filtered.append(l)
                        elif time_filter == "Son 48 Saat" and hours <= 48:
                            filtered.append(l)
                    else:
                        # Legacy format (e.g. "Mart") - Show by default to avoid losing data
                        filtered.append(l)
                except:
                    filtered.append(l)
            else:
                # ldate yoksa Tümü değilse ekleme
                pass
        listings = filtered

    # Render results
    if listings:
        st.caption(f"📊 {filter_mode} - {len(listings)} ilan bulundu (Filtre: {time_filter})")
        for i, listing in enumerate(listings):
            render_detailed_listing_card(listing, i)
    else:
        st.warning(f"⚠️ {filter_mode} kategorisinde {time_filter} için ilan bulunamadı.")

    # Auto-refresh mesajı
    st.caption("⚡ Bu sayfa otomatik olarak her 30 saniyede yenilenir. Son yenileme: " +
               datetime.now().strftime('%H:%M:%S'))


def render_scraper_info():
    """Scraper kapasite bilgisi (v8.1 updated)"""
    st.subheader("📊 Kaynak Bazlı Veri Kapasitesi")

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("""
        ### 🔵 Arabam.com (Detailed v8.1)

        **Temel Bilgiler:**
        - ✅ Fiyat / KM / Yıl / Marka

        **Detaylı Bilgiler:**
        - ✅ Boya durumu (Triple-Extract)
        - ✅ Hasar/Tramer (Text-Analysis)
        - ✅ Paket (ML-Pattern)
        - ✅ Ana Görsel (Triple-Strategy)
        """)

    with col2:
        st.markdown("""
        ### ⭐ Borusan Next (Enterprise v3.1)

        **Temel Bilgiler:**
        - ✅ Fiyat / KM / Yıl / Marka

        **Detaylı Bilgiler:**
        - ✅ Boya durumu (Expertise-Sketch)
        - ✅ Hasar/Tramer (Expertise-Audit)
        - ✅ Satılma durumu
        - ✅ Sertifika / Garanti
        - ✅ Ana Görsel (Enterprise-JSON)
        """)


def _render_vitrin_page():
    user = st.session_state.get('logged_in_user')

    if user:
        try:
            live_svc = get_live_service_v2()

            # ── 1. TOPLAM ARAÇ SAYISI (Büyük Rakam) ──────────────
            stats = live_svc.get_market_stats()
            total = sum(s.get('total', 0) for s in stats.values())

            st.markdown(f"""
            <div style='text-align: center; padding: 15px 0 10px 0;'>
                <div style='font-size: 3.5rem; font-weight: 900; color: #60A5FA; line-height: 1;'>{total:,}</div>
                <div style='color: #94A3B8; font-size: 1rem; margin-top: 4px;'>Havuzdaki Toplam Araç</div>
            </div>
            """, unsafe_allow_html=True)

            # ── 2. SEKME: Fırsat Araçlar / Tüm Araçlar ───────────
            tab_firsat, tab_tumu = st.tabs(["🔥 Fırsat Araçlar", "📦 Tüm Araçlar"])

            # ── 3. MARKA / MODEL FİLTRESİ ────────────────────────
            active_brands = live_svc.get_active_brands()

            with tab_firsat:
                col_f1, col_f2 = st.columns(2)
                with col_f1:
                    selected_brand = st.selectbox(
                        "🏷️ Marka", ["Tüm Markalar"] + active_brands,
                        key="firsat_brand"
                    )
                with col_f2:
                    model_options = ["Tüm Modeller"]
                    if selected_brand != "Tüm Markalar":
                        try:
                            brand_rows = live_svc.get_filtered_listings(brand=selected_brand, limit=2000)
                            models = sorted(set(
                                str(l.get('model', '')).strip()
                                for l in brand_rows
                                if l.get('model') and str(l.get('model', '')).strip()
                            ))
                            model_options += models
                        except:
                            pass
                    selected_model = st.selectbox("🚗 Model", model_options, key="firsat_model")

                # SQL-level filtering — searches ALL listings, not limited window
                filter_kwargs = {"limit": 30}
                if selected_brand != "Tüm Markalar":
                    filter_kwargs["brand"] = selected_brand
                if selected_model != "Tüm Modeller":
                    filter_kwargs["model"] = selected_model

                # First get count for display, then filter by opportunity
                if selected_brand != "Tüm Markalar" or selected_model != "Tüm Modeller":
                    all_matching = live_svc.get_filtered_listings(**{k: v for k, v in filter_kwargs.items() if k != "limit"}, limit=5000)
                    listings = [l for l in all_matching if l.get('opportunity_score') and float(l.get('opportunity_score', 0)) > 70]
                    listings = listings[:30]
                else:
                    listings = live_svc.get_opportunity_vehicles(limit=30)

                if listings:
                    st.success(f"🔥 {len(listings)} fırsat araç bulundu")
                    for i, listing in enumerate(listings):
                        render_detailed_listing_card(listing, i)
                else:
                    st.info("Seçilen filtrelere uygun fırsat araç bulunamadı.")

            with tab_tumu:
                col_f3, col_f4 = st.columns(2)
                with col_f3:
                    selected_brand2 = st.selectbox(
                        "🏷️ Marka", ["Tüm Markalar"] + active_brands,
                        key="tum_brand"
                    )
                with col_f4:
                    model_options2 = ["Tüm Modeller"]
                    if selected_brand2 != "Tüm Markalar":
                        try:
                            brand_rows2 = live_svc.get_filtered_listings(brand=selected_brand2, limit=2000)
                            models2 = sorted(set(
                                str(l.get('model', '')).strip()
                                for l in brand_rows2
                                if l.get('model') and str(l.get('model', '')).strip()
                            ))
                            model_options2 += models2
                        except:
                            pass
                    selected_model2 = st.selectbox("🚗 Model", model_options2, key="tum_model")

                # SQL-level filtering — searches ALL listings in DB
                filter_kwargs2 = {"limit": 30}
                if selected_brand2 != "Tüm Markalar":
                    filter_kwargs2["brand"] = selected_brand2
                if selected_model2 != "Tüm Modeller":
                    filter_kwargs2["model"] = selected_model2

                listings_all = live_svc.get_filtered_listings(**filter_kwargs2)

                if listings_all:
                    st.caption(f"📊 {len(listings_all)} araç listeleniyor")
                    for i, listing in enumerate(listings_all):
                        render_detailed_listing_card(listing, i)
                else:
                    st.info("Seçilen filtrelere uygun araç bulunamadı.")
        except Exception as e:
            st.warning("Veriler yüklenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.")
        return

    st.markdown("""
    <style>
        /* Glassmorphism Form Container */
        div[data-testid="stForm"] {
            background: rgba(30, 41, 59, 0.45) !important;
            backdrop-filter: blur(16px) !important;
            -webkit-backdrop-filter: blur(16px) !important;
            border: 1px solid rgba(255, 255, 255, 0.1) !important;
            border-radius: 24px !important;
            padding: 40px !important;
            max-width: 520px !important;
            margin: 60px auto !important;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4) !important;
        }
        /* Input Fields */
        div[data-testid="stForm"] .stTextInput > div > div > input {
            background: rgba(15, 23, 42, 0.6) !important;
            border: 1px solid rgba(148, 163, 184, 0.3) !important;
            border-radius: 10px !important;
            color: #F8FAFC !important;
            padding: 14px !important;
            font-size: 1rem !important;
        }
        div[data-testid="stForm"] .stTextInput label {
            color: #CBD5E1 !important;
            font-size: 0.9rem !important;
            font-weight: 500 !important;
        }
        /* Submit Button */
        div[data-testid="stForm"] [data-testid="stFormSubmitButton"] > button {
            background: linear-gradient(90deg, #FF8C00, #FF4500) !important;
            color: #FFFFFF !important;
            border: none !important;
            border-radius: 50px !important;
            font-weight: 800 !important;
            font-size: 1.15rem !important;
            padding: 18px 24px !important;
            margin-top: 25px !important;
            width: 100% !important;
            box-shadow: 0 6px 20px rgba(255, 69, 0, 0.3) !important;
            transition: all 0.3s ease !important;
            letter-spacing: 0.5px !important;
        }
        div[data-testid="stForm"] [data-testid="stFormSubmitButton"] > button:hover {
            transform: translateY(-2px) !important;
            box-shadow: 0 8px 25px rgba(255, 69, 0, 0.5) !important;
        }

        /* Secondary Link Styling */
        .secondary-link-container {
            text-align: center;
            margin-top: 20px;
        }
    </style>
    """, unsafe_allow_html=True)

    with st.form("quick_register_form", clear_on_submit=False):
        st.markdown("""
            <div style='text-align: center; margin-bottom: 30px;'>
                <div style='display: flex; justify-content: center; align-items: center; gap: 8px; margin-bottom: 20px;'>
                    <span style='font-size: 1.6rem;'>🖼️</span>
                    <span style='font-size: 1.6rem; font-weight: 800; color: #F8FAFC; letter-spacing: 0.5px;'>YERİMEBAK AI</span>
                    <span style='background: #4F46E5; color: white; padding: 2px 8px; border-radius: 8px; font-size: 0.75rem; font-weight: bold;'>v8.0</span>
                </div>
                <h2 style='color: #F1F5F9; font-size: 1.7rem; font-weight: 800; margin-bottom: 16px; line-height: 1.3;'>
                    Yapay Zeka Destekli Araç Değerleme Platformu
                </h2>
                <h3 style='color: #E2E8F0; font-size: 1.15rem; font-weight: 600; margin-bottom: 12px;'>
                    Rakipleriniz Arasında Kaybolmayın! 🚨
                </h3>
                <p style='color: #94A3B8; font-size: 0.9rem; line-height: 1.6; margin-bottom: 10px; padding: 0 10px;'>
                    Sahibinden, Arabam.com gibi sitelerdeki araç ilanlarını yapay zeka ile saniyeler içinde analiz edin.
                    Piyasa fiyatı, değer kaybı, risk analizi ve yatırım simülasyonu tek platformda.
                </p>
            </div>
        """, unsafe_allow_html=True)

        full_name = st.text_input("İsim Soyad")
        phone = st.text_input("Cep Telefonu")

        if st.form_submit_button("HEMEN ÜCRETSİZ DENEYİN!", use_container_width=True):
            if full_name and phone:
                try:
                    from yerimebak_ai_v5.dashboard.services.auth_service import AuthService
                    res = AuthService().register_user(full_name.strip(), phone)
                    if res.get("success"):
                        st.session_state['logged_in_user'] = res
                        st.session_state['menu_selection'] = "🏪 Vitrin"
                        st.rerun()
                    else:
                        login = AuthService().login_with_phone(phone)
                        if login.get("success"):
                            st.session_state['logged_in_user'] = login
                            st.session_state['menu_selection'] = "🏪 Vitrin"
                            st.rerun()
                        else:
                            st.error(res.get('error'))
                except Exception as e: st.error(str(e))

    st.markdown("<div class='secondary-link-container'>", unsafe_allow_html=True)
    col_a, col_b, col_c = st.columns([1, 2, 1])
    with col_b:
        if st.button("Diğer Giriş Seçenekleri", use_container_width=True, type="secondary"):
            st.session_state['menu_selection'] = "🔑 Kayıt / Giriş"
            st.rerun()
    st.markdown("</div>", unsafe_allow_html=True)

def _render_api_key_page():
    user = st.session_state.get('logged_in_user')
    if not user:
        st.warning("Lütfen giriş yapın.")
        return

    api_key = user.get('api_key', 'Bulunamadı')
    credits = user.get('credits', 0)
    tier = user.get('tier', 'free').upper()

    st.markdown(f"""
    <div style="background: rgba(30, 41, 59, 0.45); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 24px; padding: 40px; max-width: 600px; margin: 40px auto; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4);">
        <h2 style="color:#F1F5F9; display:flex; align-items:center; justify-content: center; gap:10px; margin-bottom: 20px; font-weight: 800;">
            🧩 Chrome Uzantısı ile Analiz
        </h2>
        <p style="color:#94A3B8; font-size:1.05em; line-height:1.6; text-align: center; margin-bottom: 30px;">
            Sahibinden ve Arabam.com ilanlarını gezerken tek tıkla yapay zeka analizini çalıştırmak için
            YerimeBak AI Chrome eklentisini kullanabilirsiniz.
        </p>

        <div style="margin-top:20px;">
            <h4 style="color:#E2E8F0; font-weight: 600; margin-bottom: 15px;">🛠️ Kurulum Adımları</h4>
            <ol style="color:#CBD5E1; font-size:1rem; line-height:1.8; margin-left: 20px;">
                <li>YerimeBak AI eklentisini indirin veya uzantılarınıza ekleyin.</li>
                <li>İlan sitelerinden birinde gezerken eklenti ikonuna tıklayın.</li>
                <li>Aşağıdaki kişisel <b>API Anahtarınızı</b> kopyalayıp eklentiye yapıştırın.</li>
                <li>"Kaydet" butonuna basarak sistemi aktif edin!</li>
            </ol>
        </div>

        <div style="background: rgba(15, 23, 42, 0.6); border: 1px solid rgba(148, 163, 184, 0.3); border-radius: 12px; padding: 25px; margin-top: 30px; text-align: center;">
            <div style="color:#94A3B8; margin-bottom:10px; font-weight:600; font-size: 0.9rem; text-transform:uppercase;">Size Özel API Anahtarınız</div>
            <code style="color:#FFD700; font-size:1.4em; display:block; margin-bottom:5px; letter-spacing:1px; background: transparent;">{api_key}</code>
        </div>

        <div style="display:flex; justify-content:space-around; margin-top:30px; padding-top:20px; border-top:1px solid rgba(255,255,255,0.1);">
            <div style="text-align:center;">
                <div style="color:#94A3B8; font-size: 0.9rem;">Üyelik Tipi</div>
                <div style="font-weight:800; color:#F8FAFC; font-size: 1.1rem;">{tier}</div>
            </div>
            <div style="text-align:center;">
                <div style="color:#94A3B8; font-size: 0.9rem;">Kalan Kredi</div>
                <div style="font-weight:800; color:#10B981; font-size: 1.1rem;">{credits}</div>
            </div>
        </div>
    </div>
    """, unsafe_allow_html=True)


def _render_admin_dashboard():
    """Admin'e özel yönetim paneli — müşteri sayfasından tamamen ayrı."""
    db_manager = _get_db_manager()

    # ── ÜST KPI BAR ──
    stats = live_service.get_market_stats()
    total = sum(s.get('total', 0) for s in stats.values())
    total_daily = sum(s.get('daily_total', 0) for s in stats.values())
    total_daily_opps = sum(s.get('daily_opportunities', 0) for s in stats.values())

    k1, k2, k3, k4, k5 = st.columns(5)
    with k1: st.metric("📦 Toplam İlan", f"{total:,}")
    with k2: st.metric("🔥 Günlük Fırsat", f"{total_daily_opps}")
    with k3: st.metric("📅 Günlük Yeni", f"{total_daily}")
    with k4:
        db_mb = db_manager.get_db_size() / (1024*1024) if db_manager else 0
        st.metric("💾 DB Boyutu", f"{db_mb:.1f} MB")
    with k5:
        health = _check_system_health(db_manager) if db_manager else "critical"
        if health == "healthy":
            st.metric("❤️ Sağlık", "🟢 OK")
        elif health == "warning":
            st.metric("❤️ Sağlık", "🟡 UYARI")
        else:
            st.metric("❤️ Sağlık", "🔴 KRİTİK")

    st.markdown("---")

    # ── KAYNAK DAĞILIMI ──
    tab_src, tab_brand, tab_time = st.tabs(["📊 Kaynak Dağılımı", "🏷️ Marka Dağılımı", "📅 Zaman Serisi"])

    with tab_src:
        source_df = _get_listings_by_source(db_manager)
        if _PLOTLY_OK and not source_df.empty:
            fig_pie = px.pie(source_df, values="count", names="source",
                             title="Kaynak Dağılımı (%)", hole=0.45,
                             color="source", color_discrete_map={"arabam": "#60A5FA", "borusan": "#F59E0B"})
            fig_pie.update_traces(textposition="inside", textinfo="percent+label")
            st.plotly_chart(fig_pie, use_container_width=True)
        elif not source_df.empty:
            st.dataframe(source_df, use_container_width=True)
        else:
            st.info("📭 Henüz veri yok.")

    with tab_brand:
        render_brand_distribution(db_manager)

    with tab_time:
        render_time_series(db_manager)

    st.markdown("---")

    # ── SCRAPER BİLGİSİ ──
    render_scraper_info()

    st.markdown("---")

    # ── AI ENGINE STATUS ──
    st.subheader("🤖 AI Servis Durumu")
    try:
        from yerimebak_ai_v5.core.unified_ai_service import get_unified_ai_service
        ai_service = get_unified_ai_service()
        ai_c1, ai_c2, ai_c3 = st.columns(3)
        with ai_c1: st.metric("Durum", "✅ AKTİF" if ai_service.enabled else "❌ KAPALI")
        with ai_c2: st.metric("Primary", ai_service.config.get('primary_model', 'N/A').split('/')[-1])
        with ai_c3: st.metric("Fallback", ai_service.config.get('fallback_model', 'N/A').split('/')[-1])
    except Exception as e:
        st.warning(f"AI servis bilgisi alınamadı: {e}")

    # ── YENİLE ──
    st.markdown("---")
    if st.button("🔄 Verileri Yenile", type="primary"):
        st.rerun()


def main():
    logged_in_user = st.session_state.get('logged_in_user')

    if logged_in_user and logged_in_user.get('user_id'):
        try:
            from yerimebak_ai_v5.core.database_config import DatabaseConfig
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            cur.execute("SELECT id, email, full_name, credits, tier, role, api_key FROM users WHERE id = %s", (logged_in_user['user_id'],))
            db_user = cur.fetchone()
            conn.close()
            if db_user:
                db_user = dict(db_user)
                st.session_state['logged_in_user'] = {
                    'user_id': db_user['id'],
                    'full_name': db_user.get('full_name', ''),
                    'email': db_user['email'],
                    'api_key': db_user.get('api_key'),
                    'credits': db_user.get('credits', 0),
                    'tier': db_user.get('tier', 'free'),
                    'role': db_user.get('role', 'user'),
                }
                logged_in_user = st.session_state['logged_in_user']
        except Exception:
            pass

    # Extremely Robust Admin Check (v8.3)
    is_admin = False
    if logged_in_user:
        u_email = str(logged_in_user.get('email', '')).lower().strip()
        u_role = str(logged_in_user.get('role', '')).lower().strip()
        u_name = str(logged_in_user.get('full_name', '')).lower().strip()
        is_admin = (u_email == 'admin@yerimebak.com' or u_role == 'admin' or u_name == 'admin@yerimebak.com')

    default_page = "🛡️ Admin Panel" if is_admin else "🏪 Vitrin"

    # Otomatik yönlendirme mantığı (v8.1)
    if "menu_selection" not in st.session_state:
        st.session_state["menu_selection"] = default_page
    elif is_admin and st.session_state.get("menu_selection") == "🏪 Vitrin":
        # Admin ise ve Vitrin'deyse, Admin Panel'e yönlendir (ilk girişte)
        st.session_state["menu_selection"] = "🛡️ Admin Panel"
    elif not is_admin and st.session_state.get("menu_selection") == "🛡️ Admin Panel":
        # Admin değilse ama Admin Panel seçiliyse (eski oturum vb.), Vitrin'e yönlendir
        st.session_state["menu_selection"] = "🏪 Vitrin"

    with st.sidebar:
        st.markdown("# 🏛️ YERİMEBAK AI")
        st.markdown("### v8.0 Dashboard")
        st.markdown("---")

        if logged_in_user:
            if is_admin:
                st.markdown(f"""
                <div style='background:rgba(239,68,68,0.1); border:1px solid rgba(239,68,68,0.3);
                            border-radius:10px; padding:10px; margin-bottom:10px; text-align:center;'>
                    <span style='color:#f87171; font-weight:700;'>👑 ADMIN</span><br>
                    <small style='color:#94A3B8;'>{logged_in_user.get('full_name', 'Admin')}</small>
                </div>
                """, unsafe_allow_html=True)

                admin_menu = [
                    "🛡️ Admin Panel",
                    "🏠 Canlı Akış",
                    "🔬 Araç Analizi",
                    "🤖 Scraper Yönetimi",
                    "⚙️ Sistem Sağlığı",
                    "---",
                    "🏪 Müşteri Vitrini",
                    "💎 Kredi Yükle",
                    "🔑 API Anahtarım",
                ]
                safe_menu = [m for m in admin_menu if m != "---"]
                current = st.session_state.get('menu_selection', default_page)
                idx = safe_menu.index(current) if current in safe_menu else 0
                menu = st.radio("Admin Menü:", safe_menu, index=idx)
            else:
                st.success(f"Hoş geldin, {logged_in_user.get('full_name', 'Kullanıcı')}!")
                st.caption(f"💰 Krediniz: {logged_in_user.get('credits', 0)}")

                customer_menu = ["🏪 Vitrin", "🔬 Araç Analizi", "📈 Piyasa Zekası", "💎 Kredi Yükle", "🔑 API Anahtarım", "📜 Analiz Geçmişi"]
                current = st.session_state.get('menu_selection', "🏪 Vitrin")
                idx = customer_menu.index(current) if current in customer_menu else 0
                menu = st.radio("Sayfa Seçin:", customer_menu, index=idx)

            # Otomatik Admin Düzeltme (v8.4) - Eğer email admin ise ama veritabanı geride kaldıysa
            if u_email == 'admin@yerimebak.com' and u_role != 'admin':
                try:
                    db_manager = _get_db_manager()
                    with db_manager.get_connection() as conn:
                        with conn.cursor() as cur:
                            cur.execute("UPDATE users SET role = 'admin', credits = 1000, tier = 'enterprise' WHERE email = %s", (u_email,))
                            conn.commit()
                    st.info("🔄 Admin yetkileri veritabanında güncellendi. Lütfen bir kez yenileyin.")
                except: pass

            st.session_state['menu_selection'] = menu

            if st.button("🚪 Çıkış Yap", use_container_width=True):
                st.session_state['logged_in_user'] = None
                st.session_state['menu_selection'] = "🏪 Vitrin"
                st.rerun()
        else:
            menu = st.radio("Sayfa Seçin:", ["🏪 Vitrin", "🔑 Kayıt / Giriş"], index=0 if st.session_state.get('menu_selection') == "🏪 Vitrin" else 1)
            st.session_state['menu_selection'] = menu

    # Header
    render_header()

    # ── ROUTING ──
    # Admin'e özel sayfalar
    if menu == "🛡️ Admin Panel":
        _render_admin_dashboard()
    elif menu == "🏠 Canlı Akış":
        render_main_dashboard()
    elif menu == "🤖 Scraper Yönetimi":
        if is_admin:
            from yerimebak_ai_v5.dashboard.pages.scraper_control import render_scraper_control_page
            render_scraper_control_page()
        else:
            st.warning("Admin yetkisi gereklidir.")
    elif menu == "⚙️ Sistem Sağlığı":
        if is_admin:
            render_system_health_hub()
        else:
            st.warning("Admin yetkisi gereklidir.")
    # Müşteri + ortak sayfalar
    elif menu == "🏪 Vitrin" or menu == "🏪 Müşteri Vitrini":
        _render_vitrin_page()
    elif menu == "🔑 Kayıt / Giriş":
        from yerimebak_ai_v5.dashboard.pages.kayit import render_kayit_page
        render_kayit_page()
    elif menu == "💎 Kredi Yükle":
        from yerimebak_ai_v5.dashboard.pages.pricing import render_pricing_page
        render_pricing_page()
    elif menu == "🔑 API Anahtarım":
        _render_api_key_page()
    elif menu == "📈 Piyasa Zekası":
        from yerimebak_ai_v5.dashboard.pages.piyasa_zekasi import render_piyasa_zekasi_page
        render_piyasa_zekasi_page()
    elif menu == "🔬 Araç Analizi":
        if _ANALIZ_OK:
            analiz_page.render_analiz_page()
        else:
            st.error(f"❌ Analiz modülü yüklenemedi: {_ANALIZ_ERR}")
    elif menu == "📜 Analiz Geçmişi":
        st.info("Analiz geçmişi buradadır.")


def render_heatmap_page():
    st.subheader("🗺️ Bölgesel Piyasa Isı Haritası")
    st.info("💡 Şehir bazlı satış hızı, talep ve karlılık analizi.")

    try:
        from yerimebak_ai_v5.core.ai_orchestrator import ai_orchestrator
        # Tüm veriyi çek (gerçekçi istatistik için)
        listings = live_service.get_detailed_listings(limit=500)
        heatmap_data = ai_orchestrator.get_regional_heatmap(listings)

        if heatmap_data:
            df = pd.DataFrame.from_dict(heatmap_data, orient='index').reset_index()
            df.columns = ['Şehir', 'İlan Sayısı', 'Satış Hızı', 'Talep Skoru', 'Ort. Fiyat']

            # KPI Kartları
            h_col1, h_col2, h_col3 = st.columns(3)
            with h_col1:
                top_city = df.loc[df['İlan Sayısı'].idxmax()]['Şehir']
                st.metric("📍 En Aktif Şehir", top_city)
            with h_col2:
                fastest_city = df.loc[df['Satış Hızı'].idxmax()]['Şehir']
                st.metric("⚡ En Hızlı Satış", fastest_city)
            with h_col3:
                high_demand = df.loc[df['Talep Skoru'].idxmax()]['Şehir']
                st.metric("🔥 En Yüksek Talep", high_demand)

            st.markdown("---")

            col1, col2 = st.columns([1, 1])
            with col1:
                st.markdown("### 🏢 Şehir Dağılım Tablosu")
                st.dataframe(df.sort_values(by='İlan Sayısı', ascending=False),
                             use_container_width=True, hide_index=True)

            with col2:
                if _PLOTLY_OK:
                    st.markdown("### 📊 Talep vs Satış Hızı")
                    fig = px.scatter(df, x='Talep Skoru', y='Satış Hızı', size='İlan Sayısı',
                                     color='Şehir', hover_name='Şehir',
                                     title="Bölgesel Pazar Dinamiği")
                    st.plotly_chart(fig, use_container_width=True)
        else:
            st.warning("Yeterli bölgesel veri bulunamadı.")
    except Exception as e:
        st.error(f"Isı haritası yüklenirken hata: {e}")

def render_fleet_charts():
    """Filo yönetimi için özel grafikler"""
    if not _PLOTLY_OK: return

    st.subheader("📈 Filo Portföy & Amortisman Trendi")

    # Simüle edilmiş amortisman eğrisi
    years = [0, 1, 2, 3, 4, 5]
    value_pct = [100, 88, 78, 70, 63, 58] # % bazında değer koruma

    df_trend = pd.DataFrame({"Yıl": years, "Kalan Değer (%)": value_pct})

    fig = px.line(df_trend, x="Yıl", y="Kalan Değer (%)",
                  title="Tahmini Ortalama Amortisman Eğrisi",
                  markers=True)
    fig.update_layout(yaxis_range=[0, 100])
    st.plotly_chart(fig, use_container_width=True)


# Entry point moved to the end of file


# ═══════════════════════════════════════════════════════
# Sistem Durumu Sayfası — Yardımcı Fonksiyonlar
# ═══════════════════════════════════════════════════════


def _get_db_manager():
    """DatabaseManager'i güvenli şekilde import et."""
    try:
        # Import inside function to avoid startup circularity
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        from yerimebak_ai_v5.data_lake.database import db_manager
        return db_manager
    except ImportError as e:
        print(f"❌ [DB] Import hatası: {e}")
        return None
    except Exception as e:
        print(f"❌ [DB] Veritabanı yöneticisi başlatılamadı: {e}")
        return None


def _get_listings_by_source(db_manager) -> "pd.DataFrame":
    """Kaynağa göre ilan sayılarını getir."""
    query = """
        SELECT source, COUNT(*) as count
        FROM listings
        WHERE source IS NOT NULL
        GROUP BY source
        ORDER BY count DESC
    """
    try:
        with db_manager.get_connection() as conn:
            return pd.read_sql_query(query, conn)
    except Exception:
        return pd.DataFrame()


def _get_last_update_time(db_manager) -> "datetime | None":
    """Son güncelleme zamanını getir."""
    try:
        with db_manager.get_connection() as conn:
            cur = conn.execute("SELECT MAX(updated_at) as last_update FROM listings")
            row = cur.fetchone()
            if row and row['last_update']:
                val = row['last_update']
                if isinstance(val, datetime):
                    return val
                return datetime.fromisoformat(str(val))
    except Exception:
        pass
    return None


def _check_system_health(db_manager) -> str:
    """Sistem sağlık durumunu kontrol et."""
    if not db_manager:
        return "critical"

    status_db = False
    status_update = False
    status_data = False

    # 1. DB erişim
    try:
        size = db_manager.get_db_size()
        if size > 0:
            status_db = True
    except Exception as e:
        print(f"⚠️ [Health] DB erişim hatası: {e}")

    # 2. Son güncelleme (24 saat içinde)
    try:
        last_update = _get_last_update_time(db_manager)
        if last_update:
            hours_ago = (datetime.now() - last_update).total_seconds() / 3600
            if hours_ago < 24:
                status_update = True
    except Exception as e:
        print(f"⚠️ [Health] Güncelleme zamanı kontrol hatası: {e}")

    # 3. Minimum veri
    try:
        count = db_manager.get_table_count("listings")
        if count > 0:
            status_data = True
    except Exception as e:
        print(f"⚠️ [Health] Veri kontrol hatası: {e}")

    # Final Decision
    if status_db and status_update and status_data:
        return "healthy"
    elif status_db or status_data:
        # DB'ye erişiliyor veya veri var ama güncel değilse UYARI
        return "warning"
    return "critical"


def render_general_stats(db_manager):
    """Genel fiyat istatistiklerini göster."""
    try:
        with db_manager.get_connection() as conn:
            cur = conn.execute(
                "SELECT AVG(price) as avg_p, MIN(price) as min_p, MAX(price) as max_p FROM listings WHERE price IS NOT NULL"
            )
            row = cur.fetchone()
            avg_p = row['avg_p'] or 0
            min_p = row['min_p'] or 0
            max_p = row['max_p'] or 0
        col1, col2, col3 = st.columns(3)
        col1.metric("💰 Ortalama Fiyat", f"{avg_p:,.0f} ₺")
        col2.metric("⬇️ Minimum Fiyat", f"{min_p:,.0f} ₺")
        col3.metric("⬆️ Maximum Fiyat", f"{max_p:,.0f} ₺")
    except Exception as e:
        st.warning(f"Fiyat istatistikleri alınamadı: {e}")


def render_brand_distribution(db_manager):
    """Marka dağılımını Treemap olarak göster."""
    if not _PLOTLY_OK:
        st.warning("⚠️ Plotly yüklenmemiş — `pip install plotly`")
        return
    try:
        with db_manager.get_connection() as conn:
            df = pd.read_sql_query(
                "SELECT brand, COUNT(*) as count FROM listings WHERE brand IS NOT NULL GROUP BY brand ORDER BY count DESC LIMIT 25",
                conn,
            )
        if not df.empty:
            fig = px.treemap(
                df,
                path=["brand"],
                values="count",
                title="🏷️ Marka Dağılımı (Top 25)",
                color="count",
                color_continuous_scale="Blues",
            )
            fig.update_layout(margin=dict(t=30, l=0, r=0, b=0))
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("📦 Marka verisi bulunamadı.")
    except Exception as e:
        st.warning(f"Marka dağılımı alınamadı: {e}")


def render_time_series(db_manager):
    """Günlük ilan ekleme trendini çizgi grafik olarak göster."""
    if not _PLOTLY_OK:
        st.warning("⚠️ Plotly yüklenmemiş — `pip install plotly`")
        return
    try:
        with db_manager.get_connection() as conn:
            df = pd.read_sql_query(
                "SELECT DATE(created_at) as date, COUNT(*) as count FROM listings WHERE created_at IS NOT NULL GROUP BY DATE(created_at) ORDER BY date",
                conn,
            )
        if not df.empty:
            fig = px.line(
                df,
                x="date",
                y="count",
                title="📅 Günlük İlan Ekleme Trendi",
                markers=True,
                line_shape="spline",
            )
            fig.update_traces(line_color="#60A5FA", marker_color="#F59E0B")
            fig.update_layout(
                xaxis_title="Tarih",
                yaxis_title="İlan Sayısı",
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
                font_color="#F1F5F9",
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("📦 Zaman serisi verisi bulunamadı.")
    except Exception as e:
        st.warning(f"Zaman serisi alınamadı: {e}")


def render_system_health_hub():
    """Consolidated System and AI Health Monitoring (v8.1)"""
    st.markdown("## ⚙️ Sistem ve AI Sağlığı Hub'ı")
    st.markdown("---")

    # 1. 🤖 AI ENGINE STATUS
    st.markdown("### 🤖 Unified AI Service (Tril-Engine)")
    from yerimebak_ai_v5.core.unified_ai_service import get_unified_ai_service
    ai_service = get_unified_ai_service()

    ai_col1, ai_col2, ai_col3, ai_col4 = st.columns(4)
    with ai_col1:
        st.metric("Durum", "✅ AKTİF" if ai_service.enabled else "❌ DEVRE DIŞI")
    with ai_col2:
        st.metric("Primary", ai_service.config.get('primary_model', 'N/A').split('/')[-1])
    with ai_col3:
        st.metric("Secondary", ai_service.config.get('secondary_model', 'N/A').split('/')[-1])
    with ai_col4:
        st.metric("Fallback", ai_service.config.get('fallback_model', 'N/A').split('/')[-1])

    st.markdown("---")

    # 2. 📊 SYSTEM METRICS
    db_manager = _get_db_manager()
    total = db_manager.get_table_count("listings") if db_manager else 0
    health = _check_system_health(db_manager) if db_manager else "critical"
    db_mb = db_manager.get_db_size() / (1024*1024) if db_manager else 0

    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("📊 Toplam İlan", f"{total:,}")
    with col2:
        st.metric("💾 Veritabanı", f"{db_mb:.2f} MB" if db_manager else "N/A")
    with col3:
        last_update = _get_last_update_time(db_manager) if db_manager else None
        st.metric("🕐 Son Güncelleme", f"{(datetime.now() - last_update).total_seconds() / 3600:.1f}s" if last_update else "Veri Yok")
    with col4:
        st.metric("Genel Sağlık", "🟢 SAĞLIKLI" if health == "healthy" else "🔴 KRİTİK")

    st.markdown("---")

    # 3. 🔍 SCRAPER CAPABILITIES
    render_scraper_info()
    st.markdown("---")

    st.markdown("---")

    # ── Kaynak Bazında Dağılım
    st.markdown("### 📈 Kaynak Bazında İlan Dağılımı")
    source_df = _get_listings_by_source(db_manager)

    if _PLOTLY_OK and not source_df.empty:
        col_bar, col_pie = st.columns(2)
        color_map = {"arabam": "#60A5FA", "borusan": "#F59E0B"}

        with col_bar:
            fig_bar = px.bar(
                source_df,
                x="source",
                y="count",
                title="Kaynağa Göre İlan Sayısı",
                color="source",
                color_discrete_map=color_map,
                text="count",
            )
            fig_bar.update_traces(textposition="outside")
            fig_bar.update_layout(
                xaxis_title="Kaynak",
                yaxis_title="İlan Sayısı",
                showlegend=False,
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
                font_color="#F1F5F9",
            )
            st.plotly_chart(fig_bar, use_container_width=True)

        with col_pie:
            fig_pie = px.pie(
                source_df,
                values="count",
                names="source",
                title="Kaynak Dağılımı (%)",
                hole=0.45,
                color="source",
                color_discrete_map=color_map,
            )
            fig_pie.update_traces(textposition="inside", textinfo="percent+label")
            fig_pie.update_layout(
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
                font_color="#F1F5F9",
            )
            st.plotly_chart(fig_pie, use_container_width=True)
    elif not source_df.empty:
        st.dataframe(source_df, use_container_width=True)
    else:
        st.info("📭 Henüz kaynak verisi bulunmuyor. Scraper başlatılmalı.")

    st.markdown("---")

    # ── Detaylı İstatistikler (Tab'ler)
    st.markdown("### 📋 Detaylı İstatistikler")
    tab1, tab2, tab3 = st.tabs(["📊 Genel", "🏷️ Markalar", "📅 Zaman Serisi"])

    with tab1:
        render_general_stats(db_manager)

    with tab2:
        render_brand_distribution(db_manager)

    with tab3:
        render_time_series(db_manager)

    st.markdown("---")

    # ── Sistem Bilgileri
    st.markdown("### 💻 Sistem Bilgileri")
    with st.expander("🔧 Teknik Detaylar", expanded=False):
        col_a, col_b = st.columns(2)
        with col_a:
            db_path_str = os.getenv("DATABASE_URL", "PostgreSQL")[:50] + "..." if os.getenv("DATABASE_URL") else "Bilinmiyor"
            tablo_sayisi = db_manager.get_table_count("listings") if db_manager else 0
            st.markdown(f"""
**Veritabanı Bilgileri:**
- 📁 Konum: `{db_path_str}`
- 📦 Boyut: {db_mb:.2f} MB
- 📊 Tablo sayısı: {tablo_sayisi}
- 📋 Toplam İlan: {total:,}
""")
        with col_b:
            st.markdown(f"""
**Çalışma Ortamı:**
- 🐳 Container: `{os.getenv('HOSTNAME', 'Local')}`
- 📂 Data Path: `{os.getenv('DATA_PATH', 'Varsayılan')}`
- 🕐 Timezone: `{os.getenv('TZ', 'UTC')}`
- ⏰ Saat: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}
""")

    # ── Yenile butonu
    if st.button("🔄 Verileri Yenile", type="primary", use_container_width=False):
        st.rerun()

if __name__ == "__main__":
    main()
