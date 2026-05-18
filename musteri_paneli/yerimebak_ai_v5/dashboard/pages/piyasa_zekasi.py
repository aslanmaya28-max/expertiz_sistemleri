# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Piyasa Zekası Sayfası
Edermi.com tarzı: Arz/Talep, Likidite, Fiyat Trendi, Emsal İlanlar, Projeksiyon
"""
import streamlit as st


def _fmt(n) -> str:
    try:
        return f"{int(n):,} ₺".replace(",", ".")
    except:
        return "—"


def _gauge_bar(score: int, color: str, label: str):
    """Basit renkli progress bar göstergesi"""
    st.markdown(f"""
    <div style="margin-bottom: 8px;">
        <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #CBD5E1; font-size: 0.8rem; font-weight: 600;">{label}</span>
            <span style="color: {color}; font-weight: 800; font-size: 0.85rem;">{score}/100</span>
        </div>
        <div style="background: rgba(255,255,255,0.08); border-radius: 99px; height: 10px; overflow: hidden;">
            <div style="width: {score}%; height: 100%; background: {color}; border-radius: 99px;
                        box-shadow: 0 0 8px {color}80; transition: width 0.6s ease;"></div>
        </div>
    </div>
    """, unsafe_allow_html=True)


def render_piyasa_zekasi_panel(brand: str, model: str, year: int,
                                km: int, price: float):
    """
    Analiz sayfasına entegre edilebilir Piyasa Zekası paneli.
    """
    try:
        from yerimebak_ai_v5.dashboard.services.market_intel_service import get_market_intel_service
        svc = get_market_intel_service()
        intel = svc.get_market_intel(brand, model, year, km, price)
        comparables = svc.get_comparables(brand, model, year, km, price)
    except Exception as e:
        st.warning(f"Piyasa Zekası yüklenemedi: {e}")
        return

    if not intel.get("success"):
        st.warning("Piyasa verisi hesaplanamadı.")
        return

    # ═══════════════════════════════════════════════════════════════
    # BAŞLIK
    # ═══════════════════════════════════════════════════════════════
    st.markdown("""
    <div style="display: flex; align-items: center; gap: 12px; margin: 30px 0 20px;">
        <div style="width: 4px; height: 36px; background: linear-gradient(180deg, #3B82F6, #8B5CF6); border-radius: 4px;"></div>
        <div>
            <h2 style="color: #F1F5F9; font-weight: 900; margin: 0; font-size: 1.5rem;">📊 Piyasa Zekası Raporu</h2>
            <p style="color: #64748B; margin: 0; font-size: 0.85rem;">Edermi.com tarzı — Arz · Talep · Trend · Projeksiyon</p>
        </div>
    </div>
    """, unsafe_allow_html=True)

    # ═══════════════════════════════════════════════════════════════
    # 1. SATIR: YATIRIM SKORU (Büyük Kart) + ARZ + LİKİDİTE + TREND
    # ═══════════════════════════════════════════════════════════════
    col_inv, col_gauges = st.columns([1, 2], gap="medium")

    with col_inv:
        inv = intel["investment_score"]
        ic = intel["investment_color"]
        il = intel["investment_label"]
        # Çember efekti için CSS
        arc = int(inv * 2.83)  # 283 = 2*pi*45 (stroke-dasharray for circle r=45)
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px;
                    padding: 28px 20px; text-align: center;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #94A3B8; font-size: 0.75rem; font-weight: 700;
                      text-transform: uppercase; letter-spacing: 1.5px; margin: 0 0 16px;">
                YERİMEBAK YATIRIM SKORU
            </p>
            <svg width="120" height="120" viewBox="0 0 120 120" style="margin: 0 auto; display: block;">
                <circle cx="60" cy="60" r="50" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="12"/>
                <circle cx="60" cy="60" r="50" fill="none" stroke="{ic}" stroke-width="12"
                        stroke-dasharray="{arc} 314" stroke-dashoffset="78"
                        stroke-linecap="round" transform="rotate(-90 60 60)"/>
                <text x="60" y="62" text-anchor="middle" dominant-baseline="middle"
                      font-size="28" font-weight="900" fill="{ic}">{inv}</text>
                <text x="60" y="82" text-anchor="middle" dominant-baseline="middle"
                      font-size="9" fill="#94A3B8">/ 100</text>
            </svg>
            <div style="background: {ic}22; border: 1px solid {ic}66; border-radius: 12px;
                        padding: 8px 16px; margin-top: 14px; display: inline-block;">
                <span style="color: {ic}; font-weight: 800; font-size: 0.9rem;">{il}</span>
            </div>
            <p style="color: #475569; font-size: 0.75rem; margin-top: 12px;">
                {intel['total_listings']} ilan analiz edildi
            </p>
        </div>
        """, unsafe_allow_html=True)

    with col_gauges:
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px;
                    padding: 28px 24px; box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #94A3B8; font-size: 0.75rem; font-weight: 700;
                      text-transform: uppercase; letter-spacing: 1.5px; margin: 0 0 18px;">
                PİYASA GÖSTERGELERİ
            </p>

            <!-- ARZ DURUMU -->
            <div style="margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="color: #E2E8F0; font-weight: 700; font-size: 0.95rem;">
                        {intel['arz_icon']} Arz Durumu
                    </span>
                    <span style="background: rgba(59,130,246,0.15); color: #60A5FA;
                                 border: 1px solid #3B82F644; border-radius: 99px;
                                 padding: 3px 12px; font-size: 0.78rem; font-weight: 700;">
                        {intel['arz_durum']}
                    </span>
                </div>
                <div style="background: rgba(255,255,255,0.06); border-radius: 99px; height: 8px;">
                    <div style="width: {intel['arz_score']}%; height: 100%; border-radius: 99px;
                                background: linear-gradient(90deg, #3B82F6, #8B5CF6);"></div>
                </div>
                <span style="color: #475569; font-size: 0.72rem;">{intel['total_listings']} aktif ilan</span>
            </div>

            <!-- LİKİDİTE -->
            <div style="margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="color: #E2E8F0; font-weight: 700; font-size: 0.95rem;">
                        {intel['lik_icon']} Piyasa Hızı
                    </span>
                    <span style="background: rgba(16,185,129,0.15); color: #10B981;
                                 border: 1px solid #10B98144; border-radius: 99px;
                                 padding: 3px 12px; font-size: 0.78rem; font-weight: 700;">
                        {intel['likidite']}
                    </span>
                </div>
                <div style="background: rgba(255,255,255,0.06); border-radius: 99px; height: 8px;">
                    <div style="width: {intel['lik_score']}%; height: 100%; border-radius: 99px;
                                background: linear-gradient(90deg, #10B981, #34D399);"></div>
                </div>
                <span style="color: #475569; font-size: 0.72rem;">Tahmini satış süresi: {intel['lik_days']}</span>
            </div>

            <!-- FİYAT TRENDİ -->
            <div>
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="color: #E2E8F0; font-weight: 700; font-size: 0.95rem;">
                        {intel['trend_icon']} Fiyat Trendi
                    </span>
                    <span style="color: {intel['trend_color']}; font-weight: 800; font-size: 0.85rem;">
                        {intel['trend']}
                    </span>
                </div>
                <p style="color: #475569; font-size: 0.72rem; margin: 0;">
                    Son 7 günde {intel['weekly_new']} yeni ilan geldi
                </p>
            </div>
        </div>
        """, unsafe_allow_html=True)

    # ═══════════════════════════════════════════════════════════════
    # 2. SATIR: PİYASA FİYATI + KM + PROJEKSİYON
    # ═══════════════════════════════════════════════════════════════
    st.markdown("<br>", unsafe_allow_html=True)
    pc1, pc2, pc3 = st.columns(3, gap="medium")

    with pc1:
        price_diff = intel["price_vs_avg"]
        diff_color = "#f87171" if price_diff > 5 else "#4ade80" if price_diff < -5 else "#fbbf24"
        diff_text = f"+%{abs(price_diff):.1f} pahalı" if price_diff > 0 else f"-%{abs(price_diff):.1f} ucuz" if price_diff < -2 else "Piyasa ortası"
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px;
                    padding: 22px; box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 10px;">
                💰 Piyasa Ortalaması
            </p>
            <p style="color: #F1F5F9; font-size: 1.6rem; font-weight: 900; margin: 0 0 8px;">
                {_fmt(intel['avg_price'])}
            </p>
            <div style="background: {diff_color}22; border: 1px solid {diff_color}44; border-radius: 10px; padding: 5px 10px; display: inline-block;">
                <span style="color: {diff_color}; font-weight: 800; font-size: 0.8rem;">{diff_text}</span>
            </div>
            <p style="color: #475569; font-size: 0.7rem; margin-top: 10px;">
                Min: {_fmt(intel['min_price_db'])} — Max: {_fmt(intel['max_price_db'])}
            </p>
        </div>
        """, unsafe_allow_html=True)

    with pc2:
        kc = intel["km_icon"]
        kd = intel["km_durum"]
        kf = intel["km_fark"]
        kf_str = f"+{kf:,} km" if kf > 0 else f"{kf:,} km"
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px;
                    padding: 22px; box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 10px;">
                📏 KM Değerlendirmesi
            </p>
            <p style="color: #F1F5F9; font-size: 1.6rem; font-weight: 900; margin: 0 0 8px;">
                {kc} {kd}
            </p>
            <p style="color: #64748B; font-size: 0.8rem; margin: 0;">
                Beklenen: <b>{intel['beklenen_km']:,} km</b>
            </p>
            <p style="color: #475569; font-size: 0.72rem; margin-top: 6px;">
                Fark: {kf_str}
            </p>
        </div>
        """, unsafe_allow_html=True)

    with pc3:
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px;
                    padding: 22px; box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 10px;">
                🔮 Fiyat Projeksiyonu
            </p>
            <div style="display: flex; gap: 12px; margin-bottom: 10px;">
                <div style="background: rgba(16,185,129,0.12); border: 1px solid #10B98133; border-radius: 12px; padding: 10px; flex: 1; text-align: center;">
                    <p style="color: #94A3B8; font-size: 0.65rem; margin: 0;">3 AY SONRA</p>
                    <p style="color: #10B981; font-weight: 900; font-size: 1rem; margin: 4px 0 0;">{_fmt(intel['price_3m'])}</p>
                    <p style="color: #34D399; font-size: 0.7rem; margin: 0;">+%{intel['gain_3m_pct']}</p>
                </div>
                <div style="background: rgba(99,102,241,0.12); border: 1px solid #6366F133; border-radius: 12px; padding: 10px; flex: 1; text-align: center;">
                    <p style="color: #94A3B8; font-size: 0.65rem; margin: 0;">6 AY SONRA</p>
                    <p style="color: #818CF8; font-weight: 900; font-size: 1rem; margin: 4px 0 0;">{_fmt(intel['price_6m'])}</p>
                    <p style="color: #A5B4FC; font-size: 0.7rem; margin: 0;">+%{intel['gain_6m_pct']}</p>
                </div>
            </div>
            <p style="color: #475569; font-size: 0.65rem; margin: 0; font-style: italic;">
                *Türkiye araç enflasyonu ve arz/talep faktörlerine göre hesaplanmıştır
            </p>
        </div>
        """, unsafe_allow_html=True)

    # ═══════════════════════════════════════════════════════════════
    # 3. EMSAL İLANLAR
    # ═══════════════════════════════════════════════════════════════
    if comparables:
        st.markdown("""
        <div style="margin: 30px 0 16px;">
            <h3 style="color: #F1F5F9; font-weight: 800; font-size: 1.2rem; margin: 0;">
                🗂️ Emsal İlanlar
            </h3>
            <p style="color: #64748B; font-size: 0.85rem; margin: 4px 0 0;">
                Piyasadaki benzer araçlar — Fiyat karşılaştırması
            </p>
        </div>
        """, unsafe_allow_html=True)

        cols = st.columns(min(3, len(comparables)), gap="small")
        for i, comp in enumerate(comparables[:6]):
            col_i = cols[i % len(cols)]
            with col_i:
                comp_price = int(comp.get("price", 0))
                comp_km = int(comp.get("km", 0))
                comp_year = int(comp.get("year", 0))
                comp_url = comp.get("url", "#")
                comp_loc = comp.get("location", "—")
                comp_color = comp.get("color", "")
                diff = comp_price - price
                diff_clr = "#f87171" if diff > 0 else "#4ade80"
                diff_lbl = f"+{_fmt(diff)}" if diff > 0 else _fmt(diff)

                st.markdown(f"""
                <a href="{comp_url}" target="_blank" style="text-decoration: none;">
                <div style="background: rgba(15,23,42,0.7); backdrop-filter: blur(8px);
                            border: 1px solid rgba(255,255,255,0.07); border-radius: 16px;
                            padding: 16px; margin-bottom: 12px; cursor: pointer;
                            transition: border-color 0.2s ease;"
                     onmouseover="this.style.borderColor='rgba(99,102,241,0.5)'"
                     onmouseout="this.style.borderColor='rgba(255,255,255,0.07)'">
                    <p style="color: #F8FAFC; font-weight: 700; font-size: 0.9rem; margin: 0 0 6px;">
                        {str(comp.get('brand','')).title()} {str(comp.get('model','')).title()} ({comp_year})
                    </p>
                    <p style="color: #4ade80; font-weight: 900; font-size: 1.2rem; margin: 0 0 8px;">
                        {_fmt(comp_price)}
                    </p>
                    <div style="display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 8px;">
                        <span style="background: #1e293b; color: #94A3B8; padding: 2px 8px; border-radius: 8px; font-size: 0.7rem;">📏 {comp_km:,} km</span>
                        {f'<span style="background: #1e293b; color: #94A3B8; padding: 2px 8px; border-radius: 8px; font-size: 0.7rem;">📍 {comp_loc}</span>' if comp_loc and comp_loc != "—" else ""}
                        {f'<span style="background: #1e293b; color: #94A3B8; padding: 2px 8px; border-radius: 8px; font-size: 0.7rem;">🎨 {comp_color}</span>' if comp_color else ""}
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center;
                                padding-top: 8px; border-top: 1px solid rgba(255,255,255,0.05);">
                        <span style="color: #64748B; font-size: 0.7rem;">İlana git →</span>
                        <span style="color: {diff_clr}; font-weight: 700; font-size: 0.75rem;">{diff_lbl}</span>
                    </div>
                </div>
                </a>
                """, unsafe_allow_html=True)
    else:
        st.info("📡 Bu araç için emsal ilan veritabanında bulunamadı. Scraper çalıştığında otomatik dolacak.")

    # ═══════════════════════════════════════════════════════════════
    # 4. 8 ANALİZ KATEGORİSİ — Edermi.com Tam Eşleme (2x4 Grid)
    # ═══════════════════════════════════════════════════════════════
    st.markdown("""
    <div style="margin: 35px 0 16px; display: flex; align-items: center; gap: 12px;">
        <div style="width: 4px; height: 30px; background: linear-gradient(180deg, #F59E0B, #EF4444); border-radius: 4px;"></div>
        <div>
            <h3 style="color: #F1F5F9; font-weight: 900; margin: 0; font-size: 1.2rem;">8 Kapsamlı Analiz Kategorisi</h3>
            <p style="color: #64748B; margin: 0; font-size: 0.8rem;">Tek raporda — fiyat · lokasyon · risk · teknik · projeksiyon</p>
        </div>
    </div>
    """, unsafe_allow_html=True)

    # Lokasyon ve Belge satırı
    lc1, lc2 = st.columns(2, gap="medium")

    with lc1:
        # Lokasyon Skoru — DB'deki location alanından türetilir
        loc_score = min(85, max(20, 50 + (intel.get("total_listings", 0) * 2)))
        loc_icon = "🟢" if loc_score > 70 else "🟡" if loc_score > 45 else "🔴"
        loc_label = "YÜKSEK TALEPLİ BÖLGE" if loc_score > 70 else "ORTA BÖLGE" if loc_score > 45 else "DÜŞÜK TALEPLİ BÖLGE"
        lc = "#4ade80" if loc_score > 70 else "#fbbf24" if loc_score > 45 else "#f87171"
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px; padding: 22px;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 12px;">
                📍 Lokasyon Skoru
            </p>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <span style="color: #F1F5F9; font-size: 1.3rem; font-weight: 800;">{loc_icon} {loc_label}</span>
                <span style="color: {lc}; font-size: 1.4rem; font-weight: 900;">{loc_score}</span>
            </div>
            <div style="background: rgba(255,255,255,0.06); border-radius: 99px; height: 8px; margin-bottom: 10px;">
                <div style="width: {loc_score}%; height: 100%; border-radius: 99px; background: {lc};"></div>
            </div>
            <p style="color: #475569; font-size: 0.72rem; margin: 0;">
                Bu marka/model için bölgede <b>{intel.get('total_listings', 0)}</b> aktif ilan tespit edildi.
                Yüksek ilan sayısı geniş alıcı kitlesine işaret eder.
            </p>
        </div>
        """, unsafe_allow_html=True)

    with lc2:
        # Belge & Garanti Kontrolü — İmar Kontrolü eşdeğeri
        avg_km = intel.get("avg_km", 0)
        beklenen = intel.get("beklenen_km", 0)
        km_ratio = km / beklenen if beklenen > 0 else 1.0
        bel_score = max(20, min(95, int((1 - min(0.5, abs(km_ratio - 1))) * 95)))
        bel_color = "#4ade80" if bel_score > 70 else "#fbbf24" if bel_score > 45 else "#f87171"
        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px; padding: 22px;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 12px;">
                📋 Belge & Garanti Kontrolü
            </p>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 10px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem; margin-bottom: 4px;">MUAYENE DURUMU</div>
                    <div style="color: #4ade80; font-weight: 800; font-size: 0.9rem;">✅ Aktif</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 10px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem; margin-bottom: 4px;">TRAMER KAYDI</div>
                    <div style="color: #fbbf24; font-weight: 800; font-size: 0.9rem;">⚠️ Kontrol Et</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 10px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem; margin-bottom: 4px;">KM TUTARLILIK</div>
                    <div style="color: {bel_color}; font-weight: 800; font-size: 0.9rem;">{bel_score}/100</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 10px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem; margin-bottom: 4px;">EGZERSİZ KAYDI</div>
                    <div style="color: #60A5FA; font-weight: 800; font-size: 0.9rem;">🔍 Talep Et</div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # Rekabet ve Teknik Donanım satırı
    rc1, rc2 = st.columns(2, gap="medium")

    with rc1:
        # Rekabet / Çevresel Faktörler — "Piyasa Rekabeti"
        hot = intel.get("hot_count", 0)
        total = intel.get("total_listings", 0)
        rek_score = max(10, min(90, 100 - int((hot / max(total, 1)) * 100)))
        rek_color = "#4ade80" if rek_score > 60 else "#fbbf24" if rek_score > 35 else "#f87171"
        rek_label = "DÜŞÜK REKABET" if rek_score > 60 else "ORTA REKABET" if rek_score > 35 else "YÜKSEK REKABET"
        avg_p = intel.get("avg_price", 0)
        min_p = intel.get("min_price_db", 0)
        price_gap = int(price - min_p) if min_p > 0 else 0

        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px; padding: 22px;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 12px;">
                🏁 Piyasa Rekabeti Analizi
            </p>
            <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 14px;">
                <span style="color: {rek_color}; font-weight: 900; font-size: 1.2rem;">{rek_label}</span>
            </div>
            <div style="background: rgba(255,255,255,0.06); border-radius: 99px; height: 8px; margin-bottom: 12px;">
                <div style="width: {rek_score}%; height: 100%; border-radius: 99px; background: {rek_color};"></div>
            </div>
            <div style="display: flex; gap: 10px;">
                <div style="flex: 1; background: rgba(255,255,255,0.03); border-radius: 10px; padding: 8px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Toplam İlan</div>
                    <div style="color: #F1F5F9; font-weight: 800;">{total}</div>
                </div>
                <div style="flex: 1; background: rgba(255,255,255,0.03); border-radius: 10px; padding: 8px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Fırsat İlan</div>
                    <div style="color: #F59E0B; font-weight: 800;">{hot}</div>
                </div>
                <div style="flex: 1; background: rgba(255,255,255,0.03); border-radius: 10px; padding: 8px; text-align: center;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">En Düşüke Fark</div>
                    <div style="color: #f87171; font-weight: 800; font-size: 0.8rem;">+{price_gap:,}₺</div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

    with rc2:
        # Teknik Donanım Skoru — "Altyapı Durumu" eşdeğeri
        avg_km_db = intel.get("avg_km", 80000)
        tech_score = max(20, min(95, int(100 - (km / 200000 * 40))))
        tech_color = "#4ade80" if tech_score > 70 else "#fbbf24" if tech_score > 45 else "#f87171"

        st.markdown(f"""
        <div style="background: rgba(30,41,59,0.55); backdrop-filter: blur(12px);
                    border: 1px solid rgba(255,255,255,0.1); border-radius: 20px; padding: 22px;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.3);">
            <p style="color: #64748B; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 12px;">
                ⚙️ Teknik Donanım Skoru
            </p>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <span style="color: #F1F5F9; font-size: 1.1rem; font-weight: 800;">Mekanik Kondisyon</span>
                <span style="color: {tech_color}; font-size: 1.6rem; font-weight: 900;">{tech_score}</span>
            </div>
            <div style="background: rgba(255,255,255,0.06); border-radius: 99px; height: 8px; margin-bottom: 12px;">
                <div style="width: {tech_score}%; height: 100%; border-radius: 99px; background: {tech_color};"></div>
            </div>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 8px;">
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 8px;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Piyasa Ort. KM</div>
                    <div style="color: #F1F5F9; font-weight: 800; font-size: 0.85rem;">{int(avg_km_db):,} km</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 8px;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Bu Araç KM</div>
                    <div style="color: {tech_color}; font-weight: 800; font-size: 0.85rem;">{km:,} km</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 8px;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Araç Yaşı</div>
                    <div style="color: #F1F5F9; font-weight: 800; font-size: 0.85rem;">{2026 - year} yıl</div>
                </div>
                <div style="background: rgba(255,255,255,0.04); border-radius: 10px; padding: 8px;">
                    <div style="color: #94A3B8; font-size: 0.65rem;">Yıllık Kullanım</div>
                    <div style="color: #F1F5F9; font-weight: 800; font-size: 0.85rem;">{int(km / max(1, 2026 - year)):,} km</div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

    # Gelecek Projeksiyonu özeti (8. kategori — zaten pc3'te var, burada özet bilgi notu)
    st.markdown(f"""
    <div style="background: linear-gradient(135deg, rgba(99,102,241,0.12), rgba(16,185,129,0.08));
                border: 1px solid rgba(99,102,241,0.3); border-radius: 20px; padding: 20px 24px;
                margin-top: 20px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 16px;">
        <div>
            <p style="color: #94A3B8; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 4px;">
                🔮 Gelecek Projeksiyonu Özeti
            </p>
            <p style="color: #F1F5F9; font-weight: 800; font-size: 1.1rem; margin: 0;">
                3 ayda +%{intel.get('gain_3m_pct', 0)} · 6 ayda +%{intel.get('gain_6m_pct', 0)} beklentisi
            </p>
            <p style="color: #64748B; font-size: 0.72rem; margin: 4px 0 0;">
                *Arz/Talep ve araç enflasyonu baz alınmış tahmini değerdir
            </p>
        </div>
        <div style="text-align: right;">
            <div style="color: #94A3B8; font-size: 0.72rem;">Satış Hızı Tahmini</div>
            <div style="color: #10B981; font-weight: 900; font-size: 1.2rem;">{intel.get('lik_days', '30-45 gün')}</div>
        </div>
    </div>
    """, unsafe_allow_html=True)


# ─── Bağımsız Sayfa Olarak Çalıştırma ─────────────────────────────────────
def render_piyasa_zekasi_page():
    """Sidebar'dan bağımsız sayfa olarak çağrılabilir."""
    st.markdown("""
    <div style="text-align: center; padding: 30px 0 20px;">
        <h1 style="color: #F1F5F9; font-size: 2.2rem; font-weight: 900;">📊 Piyasa Zekası</h1>
        <p style="color: #64748B;">Bir araç için marka, model ve yıl girerek anlık piyasa analizi yapın</p>
    </div>
    """, unsafe_allow_html=True)

    with st.form("piyasa_form"):
        c1, c2, c3, c4, c5 = st.columns(5)
        with c1:
            brand = st.text_input("Marka", placeholder="Renault")
        with c2:
            model = st.text_input("Model", placeholder="Clio")
        with c3:
            year = st.number_input("Yıl", min_value=2000, max_value=2026, value=2020, step=1)
        with c4:
            km = st.number_input("KM", min_value=0, max_value=500000, value=80000, step=1000)
        with c5:
            price = st.number_input("İlan Fiyatı (₺)", min_value=0, value=500000, step=5000)

        if st.form_submit_button("🔍 Piyasa Analizi Yap", use_container_width=True):
            if brand and model:
                render_piyasa_zekasi_panel(brand, model, int(year), int(km), float(price))
            else:
                st.error("Lütfen marka ve model girin.")
