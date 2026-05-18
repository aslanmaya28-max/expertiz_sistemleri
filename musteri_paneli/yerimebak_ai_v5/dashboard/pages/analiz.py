# -*- coding: utf-8 -*-
"""
YERİMEBAK AI – Araç Analiz Sayfası (Streamlit)
Galeri / Filo sahipleri için uzman değerleme + AI raporu
"""

import streamlit as st
import json
import sys
import os
from datetime import datetime
from pathlib import Path

# Robust Path Management
_V5_ROOT = Path(__file__).resolve().parents[2]
if str(_V5_ROOT) not in sys.path:
    sys.path.insert(0, str(_V5_ROOT))

# Feature Support
try:
    import pdfplumber
    _PDF_OK = True
except ImportError:
    _PDF_OK = False

# ─── Lazy service ─────────────────────────────────────────────────────────────
def _get_service():
    from yerimebak_ai_v5.dashboard.services.analiz_service import get_analiz_servisi
    return get_analiz_servisi()


# ─── Parça listeleri ──────────────────────────────────────────────────────────
PARCA_LISTESI = [
    "Tavan", "Ön Kaput", "Arka Kaput",
    "Sağ Ön Kapı", "Sol Ön Kapı", "Sağ Arka Kapı", "Sol Arka Kapı",
    "Ön Tampon", "Arka Tampon",
    "Sağ Ön Çamurluk", "Sol Ön Çamurluk", "Sağ Arka Çamurluk", "Sol Arka Çamurluk",
    "Bağlantı Kolu", "Diğer",
]

MARKALAR = [
    "Volkswagen", "Mercedes-Benz", "BMW", "Audi", "Toyota", "Honda",
    "Renault", "Fiat", "Ford", "Opel", "Hyundai", "Kia", "Seat",
    "Skoda", "Peugeot", "Citroen", "Dacia", "Volvo", "Lexus",
    "Mazda", "Subaru", "Porsche", "Diğer",
]

YAKIT_TIPLERI = ["Benzin", "Dizel", "Hibrit", "LPG (Sonradan)", "LPG (Fabrika)", "Elektrik"]
SANZIMAN_TIPLERI = ["Otomatik", "Manuel", "Yarı Otomatik", "CVT"]

# Marka → Model eşleştirmesi (Türkiye pazarı)
MODEL_MAP = {
    "Volkswagen": ["Golf", "Polo", "Tiguan", "Passat", "T-Cross", "Taigo", "Jetta", "Touareg", "ID.4", "Diğer"],
    "Mercedes-Benz": ["C Serisi", "E Serisi", "A Serisi", "GLC", "GLA", "CLA", "GLB", "Vito", "S Serisi", "Diğer"],
    "BMW": ["3 Serisi", "5 Serisi", "1 Serisi", "X1", "X3", "X5", "2 Serisi", "4 Serisi", "Diğer"],
    "Audi": ["A3", "A4", "A5", "A6", "Q3", "Q5", "Q7", "A1", "Diğer"],
    "Toyota": ["Corolla", "Camry", "RAV4", "C-HR", "Yaris", "Hilux", "Land Cruiser", "Prius", "Diğer"],
    "Honda": ["Civic", "Accord", "CR-V", "HR-V", "City", "Jazz", "Diğer"],
    "Renault": ["Clio", "Megane", "Captur", "Taliant", "Kadjar", "Symbol", "Fluence", "Duster", "0.9 TCe", "1.2 Joy", "1.2 Touch", "1.5 dCi", "Diğer"],
    "Fiat": ["Egea", "500", "500 Ailesi", "Panda", "Tipo", "Doblo", "Fiorino", "Diğer"],
    "Ford": ["Focus", "Fiesta", "Kuga", "Puma", "Ranger", "Tourneo", "B-Max", "Transit", "Diğer"],
    "Opel": ["Astra", "Corsa", "Mokka", "Crossland", "Grandland", "Insignia", "Zafira", "Diğer"],
    "Hyundai": ["i20", "i10", "Tucson", "Bayon", "Kona", "Accent", "Elantra", "1.4 MPI", "1.0 T-GDI", "1.4 CRDi", "1.2 MPI", "1.2 D-CVVT", "1.4 CVVT", "Diğer"],
    "Kia": ["Ceed", "Sportage", "Picanto", "Rio", "Seltos", "Sorento", "Stonic", "Niro", "Diğer"],
    "Seat": ["Leon", "Ibiza", "Arona", "Ateca", "Tarraco", "Diğer"],
    "Skoda": ["Octavia", "Superb", "Fabia", "Kamiq", "Karoq", "Kodiaq", "Diğer"],
    "Peugeot": ["308", "3008", "2008", "508", "208", "1.2 PureTech", "1.5 BlueHDI", "1.6 e-HDi", "1.6 BlueHDI", "Diğer"],
    "Citroen": ["C3", "C4", "C5 Aircross", "C-Elysee", "Berlingo", "Diğer"],
    "Dacia": ["Sandero", "Duster", "Lodgy", "Spring", "Dokker", "Diğer"],
    "Volvo": ["XC40", "XC60", "XC90", "S60", "V60", "V40", "Diğer"],
    "Lexus": ["RX", "NX", "ES", "IS", "UX", "Diğer"],
    "Mazda": ["3", "CX-5", "CX-3", "6", "CX-30", "MX-5", "Diğer"],
    "Subaru": ["Impreza", "Forester", "Outback", "XV", "Diğer"],
    "Porsche": ["Cayenne", "Macan", "911", "Taycan", "Panamera", "Diğer"],
    "Diğer": [],
}


def _fmt(n: int) -> str:
    return f"{n:,.0f} ₺".replace(",", ".")


def _pct_renk(pct: float) -> str:
    if pct >= 20:
        return "#4ade80"   # yeşil
    elif pct >= 10:
        return "#fbbf24"   # sarı
    elif pct >= 0:
        return "#CBD5E1"   # Daha parlak gri
    else:
        return "#f87171"   # kırmızı


# ─── Kart bileşeni ─────────────────────────────────────────────────────────────
def _kart(baslik: str, icerik: str, renk="#1e3a5f"):
    st.markdown(f"""
    <div style="
        background: {renk}22;
        border: 1px solid {renk}66;
        border-radius: 12px;
        padding: 18px 22px;
        margin-bottom: 14px;
    ">
        <p style="color:#CBD5E1; font-size:11px; margin:0 0 4px 0; text-transform:uppercase; letter-spacing:1px; font-weight:600;">{baslik}</p>
        <div style="color:#FFFFFF;">{icerik}</div>
    </div>
    """, unsafe_allow_html=True)


def _senaryo_kart(senaryo_adi: str, s: dict, renk: str):
    kar6 = s['kar_6ay_nominal']
    kar1 = s['kar_1yil_nominal']
    rkar6 = s['reel_kar_6ay']
    rkar1 = s['reel_kar_1yil']
    icon = "🟢" if rkar1 > 0 else "🟡"
    st.markdown(f"""
    <div style="background: {renk}18; border:1px solid {renk}55; border-radius:12px; padding:16px; text-align:center;">
        <p style="color:{renk}; font-weight:800; font-size:14px; margin:0 0 8px; text-transform:uppercase;">{icon} {senaryo_adi}</p>
        <p style="color:#FFFFFF; font-size:20px; font-weight:800; margin:0;">{_fmt(s['alis'])}</p>
        <hr style="border:0; border-top:1px solid rgba(255,255,255,0.15); margin:10px 0;">
        <div style="display:flex; justify-content:space-between; font-size:12px;">
            <div style="text-align:left;">
                <p style="color:#CBD5E1; margin:0; font-weight:500;">6 Ay Nominal</p>
                <p style="color:#4ade80; font-weight:700; margin:2px 0;">+{_fmt(kar6)} (+{s['getiri_6ay_pct']}%)</p>
                <p style="color:#CBD5E1; margin:0; font-size:11px;">Reel: +{_fmt(rkar6)}</p>
            </div>
            <div style="text-align:right;">
                <p style="color:#CBD5E1; margin:0; font-weight:500;">1 Yıl Nominal</p>
                <p style="color:#60a5fa; font-weight:700; margin:2px 0;">+{_fmt(kar1)} (+{s['getiri_1yil_pct']}%)</p>
                <p style="color:#CBD5E1; margin:0; font-size:11px;">Reel: +{_fmt(rkar1)}</p>
            </div>
        </div>
    </div>
    """, unsafe_allow_html=True)


# ─── DOSYA PARSE ──────────────────────────────────────────────────────────────
def _parse_ekspertiz_pdf(uploaded_file) -> dict:
    """PDF ekspertiz raporundan araç bilgilerini çekmeye çalışır."""
    if not _PDF_OK:
        st.warning("📦 PDF okuma için `pdfplumber` gerekli: `pip install pdfplumber`")
        return {}

    extracted = {}
    try:
        import re
        with pdfplumber.open(uploaded_file) as pdf:
            text = "\n".join(p.extract_text() or "" for p in pdf.pages)

        # Marka/Model
        m = re.search(r"(Marka|Brand)[:\s]+([A-Za-zçğışöüÇĞİŞÖÜ\-]+)", text, re.I)
        if m: extracted["brand"] = m.group(2).strip()
        m = re.search(r"(Model)[:\s]+([A-Za-z0-9çğışöüÇĞİŞÖÜ\-\s]+)", text, re.I)
        if m: extracted["model"] = m.group(2).strip()[:20]

        # Yıl
        m = re.search(r"(Yıl|Model Yılı|Year)[:\s]+(\d{4})", text, re.I)
        if m: extracted["year"] = int(m.group(2))

        # KM
        m = re.search(r"(\d[\d\.]+)\s*(km|kilometre)", text, re.I)
        if m: extracted["km"] = int(m.group(1).replace(".", "").replace(",", ""))

        # Tramer
        m = re.search(r"(Tramer|Hasar)[:\s]*[\$₺]?([\d\.]+)", text, re.I)
        if m: extracted["tramer"] = int(m.group(2).replace(".", ""))

    except ImportError:
        st.warning("📦 PDF okuma için `pdfplumber` gerekli: `pip install pdfplumber`")
    except Exception as e:
        st.warning(f"⚠️ PDF parse hatası: {e}")

    return extracted


# ─── ANA SAYFA FONKSİYONU ──────────────────────────────────────────────────────
def render_analiz_page():
    st.markdown("""
    <div style="margin-bottom:24px;">
        <h1 style="color:#f1f5f9; margin:0; font-size:28px;">🔬 Araç Analiz Merkezi</h1>
        <p style="color:#64748b; margin:4px 0 0; font-size:13px;">
            Galeri ve filo sahipleri için • Gemini + GLM-4.7 destekli değerleme
        </p>
    </div>
    """, unsafe_allow_html=True)

    # Sekmeler
    tab1, tab2, tab3 = st.tabs(["📝 Manuel Giriş", "📄 Ekspertiz Raporu Yükle", "🔗 Link Analizi"])

    form_data = {}

    # ─── SEKME 1: MANUEL GİRİŞ ───────────────────────────────────────────────
    with tab1:
        col1, col2, col3 = st.columns(3)

        with col1:
            st.markdown("##### 🚗 Araç Kimliği")
            marka = st.selectbox("Marka", MARKALAR, key="a_marka")

            # Marka → Model cascade (dropdown seçimli)
            modeller = MODEL_MAP.get(marka, [])
            if modeller:
                secilen_model = st.selectbox("Model", modeller, key="a_model_select")
                # "Diğer" seçildiyse serbest metin girişi aç
                if secilen_model == "Diğer":
                    model = st.text_input("Model (Manuel)", placeholder="Model adını yazın...", key="a_model_manual")
                else:
                    model = secilen_model
            else:
                model = st.text_input("Model", placeholder="Model adını yazın...", key="a_model_text")

            paket = st.text_input("Paket/Trim", placeholder="Style, Exclusive, R-Line...", key="a_paket")
            yil = st.number_input("Yıl", min_value=2000, max_value=2026, value=2020, step=1, key="a_yil")

        with col2:
            st.markdown("##### ⚙️ Teknik Özellikler")
            km = st.number_input("Kilometre", min_value=0, max_value=999999, value=80000, step=1000, key="a_km")
            yakit = st.selectbox("Yakıt Tipi", YAKIT_TIPLERI, key="a_yakit")
            sanziman = st.selectbox("Şanzıman", SANZIMAN_TIPLERI, key="a_sanziman")
            renk = st.text_input("Renk", placeholder="Siyah, Beyaz, Gri...", key="a_renk")

        with col3:
            st.markdown("##### 🔧 Hasar ve Boya")
            tramer = st.number_input("Tramer Bedeli (₺)", min_value=0, max_value=999999, value=0, step=500, key="a_tramer")
            degisen = st.multiselect("Değişen Parçalar", PARCA_LISTESI, key="a_degisen")
            boyali = st.multiselect("Boyalı Parçalar", PARCA_LISTESI, key="a_boyali")

        form_data = {
            "brand": marka, "model": model, "paket": paket, "year": int(yil),
            "km": int(km), "yakit": yakit, "sanziman": sanziman, "renk": renk,
            "tramer": int(tramer), "degisen": degisen, "boyali": boyali,
        }

    # ─── SEKME 2: EKSPERTİZ PDF ─────────────────────────────────────────────
    with tab2:
        st.markdown("""
        <div style="background:#0f172a; border:1px dashed #334155; border-radius:12px; padding:20px; margin-bottom:16px;">
            <h4 style="color:#60a5fa; margin:0 0 8px;">📤 Ekspertiz Raporu Yükle</h4>
            <p style="color:#94a3b8; margin:0; font-size:13px;">
                PDF formatındaki ekspertiz raporunu yükleyin. Sistem marka, model, km ve hasar bilgilerini
                otomatik çıkarmaya çalışır. Eksik alanları manuel tamamlayabilirsiniz.
            </p>
        </div>
        """, unsafe_allow_html=True)

        uploaded = st.file_uploader("PDF Ekspertiz Raporu", type=["pdf"], key="ekspertiz_pdf")
        if uploaded:
            with st.spinner("📖 Rapor okunuyor..."):
                extracted = _parse_ekspertiz_pdf(uploaded)

            if extracted:
                st.success(f"✅ {len(extracted)} alan otomatik dolduruldu")
                with st.expander("📋 Çıkarılan Bilgiler"):
                    st.json(extracted)

                # Otofill
                col1, col2 = st.columns(2)
                with col1:
                    pdf_marka = st.text_input("Marka (PDF)", value=extracted.get("brand", ""), key="pdf_marka")
                    pdf_model = st.text_input("Model (PDF)", value=extracted.get("model", ""), key="pdf_model")
                    pdf_yil = st.number_input("Yıl (PDF)", value=extracted.get("year", 2020),
                                              min_value=2000, max_value=2026, key="pdf_yil")
                with col2:
                    pdf_km = st.number_input("KM (PDF)", value=extracted.get("km", 80000),
                                             min_value=0, max_value=999999, key="pdf_km")
                    pdf_tramer = st.number_input("Tramer (PDF)", value=extracted.get("tramer", 0),
                                                 min_value=0, key="pdf_tramer")
                    pdf_yakit = st.selectbox("Yakıt (PDF)", YAKIT_TIPLERI, key="pdf_yakit")

                pdf_degisen = st.multiselect("Değişen Parçalar (PDF/Manuel)", PARCA_LISTESI, key="pdf_degisen")
                pdf_boyali = st.multiselect("Boyalı Parçalar (PDF/Manuel)", PARCA_LISTESI, key="pdf_boyali")

                if st.button("📋 Bu Verileri Kullan", use_container_width=True, type="secondary"):
                    form_data = {
                        "brand": pdf_marka, "model": pdf_model, "paket": "",
                        "year": int(pdf_yil), "km": int(pdf_km),
                        "yakit": pdf_yakit, "sanziman": "Otomatik", "renk": "",
                        "tramer": int(pdf_tramer),
                        "degisen": pdf_degisen, "boyali": pdf_boyali,
                    }
                    st.session_state["pdf_form_data"] = form_data
                    st.success("✅ Veriler aktarıldı. Aşağıdan analizi başlatın.")
            else:
                st.warning("⚠️ PDF'den veri çıkarılamadı. Lütfen Manuel Giriş sekmesini kullanın.")

    # ─── SEKME 3: LINK ANALİZİ ───────────────────────────────────────────────
    with tab3:
        st.markdown("""
        <div style="background:#0f172a; border:1px solid #1e40af55; border-radius:12px; padding:20px; margin-bottom:16px;">
            <h4 style="color:#60a5fa; margin:0 0 8px;">🔗 İlan Linki ile Analiz</h4>
            <p style="color:#94a3b8; margin:0; font-size:13px;">
                Arabam.com veya Sahibinden ilan linkini buraya yapıştırın.
                Sistem araca ait tüm teknik detayları otomatik olarak çekecek ve AI raporunu hazırlayacaktır.
            </p>
        </div>
        """, unsafe_allow_html=True)

        url_input = st.text_input("İlan URL", placeholder="https://www.arabam.com/ilan/...", key="url_input")
        analyze_link_btn = st.button("🔍 Linki Çöz ve Analiz Et", use_container_width=True, type="secondary")

        if analyze_link_btn:
            if not url_input.strip():
                st.error("❌ Lütfen geçerli bir URL girin.")
            else:
                with st.spinner("🌐 Link çözümleniyor ve veriler ayıklanıyor..."):
                    try:
                        from yerimebak_ai_v5.core.link_analyzer import link_analyzer
                        import asyncio

                        # Use save_to_db=False to avoid persisting to DB and Dashboard history
                        sonuc = asyncio.run(link_analyzer.analyze_url(url_input, save_to_db=False))

                        if "error" in sonuc:
                            st.error(f"❌ Hata: {sonuc['error']}")
                        else:
                            st.success("✅ İlan başarıyla çekildi ve analiz edildi!")
                            st.session_state["analiz_sonucu_json"] = sonuc # Store raw JSON if needed

                            # Convert LinkAnalyzer results to match dashboard's expectation if different
                            # The link_analyzer returns the full analysis from orchestrator
                            # We might need to wrap it to match the format of 'tam_analiz'
                            # if 'tam_analiz' returns a different structure.
                            # For now, let's assume orchestrator result is enough or wrap it.
                            st.session_state["analiz_sonucu"] = _wrap_orchestrator_result(sonuc)
                    except Exception as e:
                        st.error(f"❌ Link analizi başarısız: {e}")
                        import traceback
                        st.code(traceback.format_exc())

    # Eğer PDF verileri aktarıldıysa bunları kullan
    if "pdf_form_data" in st.session_state and st.session_state["pdf_form_data"]:
        form_data = st.session_state["pdf_form_data"]

    # ─── ANALİZ BUTONU ───────────────────────────────────────────────────────
    st.markdown("---")
    col_btn1, col_btn2, col_btn3 = st.columns([1, 2, 1])
    with col_btn2:
        analiz_btn = st.button(
            "🤖 Yapay Zeka Analizi Başlat",
            use_container_width=True,
            type="primary",
            key="analiz_baslat",
        )

    if analiz_btn:
        user = st.session_state.get("logged_in_user")
        if not user:
            st.error("❌ Analiz yapmak için giriş yapmalısınız.")
            return

        from yerimebak_ai_v5.dashboard.services.billing_service import get_billing_service
        billing = get_billing_service()

        current_credits = billing.get_user_credits(user['email'])
        if current_credits < 1:
            st.error("❌ Yetersiz krediniz var. Lütfen 'Kredi Yükle' sekmesinden kredi satın alın.")
            return

        if not form_data.get("model", "").strip():
            st.error("❌ Lütfen araç modelini girin.")
            return

        with st.spinner("⏳ Piyasa verisi çekiliyor ve AI analizi yapılıyor..."):
            if not billing.deduct_credit(user['email'], 1):
                st.error("❌ Kredi düşümü sırasında bir hata oluştu.")
                return

            # Update local session state to reflect new credits in UI instantly
            user['credits'] = current_credits - 1
            st.session_state["logged_in_user"] = user

            try:
                servis = _get_service()
                sonuc = servis.tam_analiz(
                    brand=form_data["brand"],
                    model=form_data["model"],
                    year=form_data["year"],
                    km=form_data["km"],
                    paket=form_data.get("paket", ""),
                    yakit=form_data.get("yakit", ""),
                    sanziman=form_data.get("sanziman", ""),
                    renk=form_data.get("renk", ""),
                    degisen_parcalar=form_data.get("degisen", []),
                    boyali_parcalar=form_data.get("boyali", []),
                    tramer_bedeli=form_data.get("tramer", 0),
                )
                st.session_state["analiz_sonucu"] = sonuc
            except Exception as e:
                st.error(f"❌ Analiz hatası: {e}")
                import traceback
                st.code(traceback.format_exc())
                return

    # ─── SONUÇ GÖSTERİM ─────────────────────────────────────────────────────
    if "analiz_sonucu" in st.session_state:
        _render_sonuc(st.session_state["analiz_sonucu"])


def _render_sonuc(sonuc: dict):
    d = sonuc["deger_analizi"]
    f = sonuc["fiyat_analizi"]
    p = sonuc["piyasa"]
    arac = sonuc["arac"]
    ai = sonuc["ai_rapor"]

    # ── BAŞLIK ve TIER GÖSTERİMİ ──────────────────────────────────────────────
    source_label = d.get('veri_kaynagi', 'Hesaplama')
    if "📊" in source_label:
        source_color = "#4ade80"   # yeşil - sağlıklı
    elif "⚠️" in source_label:
        source_color = "#fbbf24"   # sarı - kısıtlı
    else:
        source_color = "#f87171"   # kırmızı/turuncu - tahmin

    st.markdown(f"""
    <div style="background: linear-gradient(135deg, #0f1e38, #1a2f55); border-radius:16px;
                padding:24px 28px; margin:24px 0 16px; border:1px solid #1e40af55; position:relative;">
        <div style="position:absolute; top:20px; right:25px; background:{source_color}22;
                    border:1px solid {source_color}; color:{source_color}; padding:4px 12px;
                    border-radius:20px; font-size:12px; font-weight:700;">
            {source_label}
        </div>
        <h2 style="color:#60a5fa; margin:0; font-size:22px;">
            📊 {arac['brand']} {arac['model']} {arac.get('paket', '')} — {arac['year']} Analizi
        </h2>
        <p style="color:#94a3b8; margin:6px 0 0; font-size:13px;">
            {arac['km']:,} km | {arac.get('yakit','')} | {arac.get('sanziman','')} |
            ⏱️ {sonuc['timestamp'][:16].replace('T',' ')}
        </p>
        <div style="display:flex; flex-wrap:wrap; gap:12px; margin-top:10px;">
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">🏠 ' + arac.get("body_type","") + '</span>' if arac.get("body_type") else ''}
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">⚙️ ' + arac.get("drive_type","") + '</span>' if arac.get("drive_type") else ''}
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">🔢 İlan: ' + arac.get("listing_no","") + '</span>' if arac.get("listing_no") else ''}
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">📅 ' + str(arac.get("listing_date","")) + '</span>' if arac.get("listing_date") else ''}
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">🎨 ' + arac.get("color","") + '</span>' if arac.get("color") else ''}
            {'<span style="background:#1e293b; color:#94a3b8; padding:3px 10px; border-radius:8px; font-size:11px;">🔧 ' + str(arac.get("engine_size","")) + ' / ' + str(arac.get("horsepower","")) + '</span>' if arac.get("engine_size") else ''}
        </div>
    </div>
    """, unsafe_allow_html=True)

    # ── PAZAR VE DEĞER KARTELLERİ ────────────────────────────────────────────
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("📊 Piyasa Ort.", _fmt(f['piyasa_ortalamasi']),
                  f"↕ Min {_fmt(p['stats'].get('min',0))}" if p['stats'] else "Veri yok")
    with col2:
        st.metric("🧮 Hesaplanan Değer", _fmt(d['hesaplanan_fiyat']),
                  f"DKK: {d['dkk']*100:.1f}% kayıp")
    with col3:
        ilan_fiyati = arac.get('price', f['piyasa_ortalamasi'])
        delta = ilan_fiyati - f['piyasa_ortalamasi']
        durum_etiketi = 'Üstünde ⚠️' if delta > 0 else 'Altında ✅' if delta < 0 else 'Eşit'
        st.metric("📉 Piyasa Farkı", _fmt(abs(delta)), durum_etiketi)
    with col4:
        st.metric("🏷️ Tavsiye Alış", _fmt(f['tavsiye_alis']),
                  f"Referansın %11 altı")

    st.markdown("---")

    # ── DEĞER KAYBI DETAYI ────────────────────────────────────────────────────
    with st.expander("📉 Değer Kaybı Detayı (DKK Kırılımı)", expanded=True):
        cols = st.columns(4)
        labels = [
            ("Yaş Kaybı", d['yas_kaybi_oran'], "📅"),
            ("Km Etkisi", 1 - d['km_katsayisi'], "🛣️"),
            ("Hasar/Boya", d['hasar_kayip_oran'], "🔧"),
            ("Tramer", d['tramer_kayip_oran'], "💥"),
        ]
        for col, (lbl, val, icon) in zip(cols, labels):
            renk = "#ef4444" if val > 0.1 else "#f59e0b" if val > 0.03 else "#4ade80"
            col.markdown(f"""
            <div style="text-align:center; background:#0f172a; border-radius:10px; padding:14px;">
                <p style="margin:0; font-size:22px;">{icon}</p>
                <p style="color:{renk}; font-size:20px; font-weight:800; margin:4px 0;">%{val*100:.1f}</p>
                <p style="color:#94a3b8; font-size:11px; margin:0;">{lbl}</p>
            </div>
            """, unsafe_allow_html=True)

        st.markdown(f"""
        <div style="background:#1e293b; border-radius:10px; padding:12px 18px; margin-top:12px;">
            <span style="color:#f1f5f9;">Toplam DKK: </span>
            <span style="color:#f87171; font-size:20px; font-weight:800;">{d['dkk']*100:.1f}%</span>
            <span style="color:#94a3b8; margin-left:16px; font-size:13px;">
                Segment: <strong style="color:#fbbf24;">{d['segment'].upper()}</strong> |
                Yaş: {d['yas']} yıl
            </span>
        </div>
        """, unsafe_allow_html=True)

    # ── GETİRİ SENARYOLARI ─────────────────────────────────────────────────────
    st.markdown("### 💰 Getiri Senaryoları")
    col1, col2, col3 = st.columns(3)
    with col1:
        _senaryo_kart("Tavsiye Alış (-%11)", f["senaryo_tavsiye"], "#4ade80")
    with col2:
        _senaryo_kart("Makul Alış (-%15)", f["senaryo_makul"], "#60a5fa")
    with col3:
        _senaryo_kart("Fırsat Alış (-%20)", f["senaryo_firsat"], "#a78bfa")

    st.markdown(f"""
    <div style="background:#0f2d0f; border:1px solid #166534; border-radius:10px; padding:12px 18px; margin-top:8px;">
        <p style="color:#86efac; margin:0; font-size:12px;">
            📌 <strong>Enflasyon Referansı:</strong>
            6 Aylık TÜFE ~%{f['enflasyon_6ay_pct']} |
            Yıllık TÜFE ~%{f['enflasyon_1yil_pct']} |
            Araç nominal değerlenme ~%{f['arac_deger_artis_1yil_pct']}/yıl
        </p>
    </div>
    """, unsafe_allow_html=True)

    # ── CANLI PİYASA İLANLARI (HORIZONTAL CARDS) ────────────────────────────
    if p.get("listings"):
        st.markdown("### 📋 Piyasadan Benzer İlanlar")
        st.markdown(f"<small style='color:#64748b;'>Toplam {len(p['listings'])} ilan bulundu - İlk 10 ilan gösteriliyor</small>", unsafe_allow_html=True)

        # Sahibinden tarzı horizontal kartlar
        for listing in p["listings"][:10]:
            # Görsel URL veya placeholder
            img_url = listing.get("image_url", "")
            if not img_url:
                img_url = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='150'%3E%3Crect fill='%231e293b' width='200' height='150'/%3E%3Ctext fill='%2364748b' font-family='sans-serif' font-size='16' dy='50%25' text-anchor='middle' x='50%25' y='50%25'%3EGörsel Yok%3C/text%3E%3C/svg%3E"

            # Boya bilgisi
            paint_info = listing.get("paint_info", {})
            paint_status = paint_info.get("status", "Bilinmiyor") if isinstance(paint_info, dict) else str(paint_info)

            # Boya rengi
            if "orijinal" in str(paint_status).lower():
                paint_color = "#4ade80"  # yeşil
                paint_icon = "✅"
            elif "değişen" in str(paint_status).lower():
                paint_color = "#f87171"  # kırmızı
                paint_icon = "❌"
            elif "boyalı" in str(paint_status).lower():
                paint_color = "#fbbf24"  # sarı
                paint_icon = "⚠️"
            else:
                paint_color = "#94a3b8"  # gri
                paint_icon = "❓"

            # İlan başlığı (title field veya marka/model)
            title = listing.get("title", "")
            if not title or len(title) < 10:
                title = f"{listing.get('brand', '')} {listing.get('model', '')}"

            # Konum ve tarih bilgileri
            location = listing.get("location", "")
            listing_date = listing.get("listing_date", "")

            # Renk
            color = listing.get("color", "Bilinmiyor")
            if isinstance(color, dict):
                color = color.get("value", "Bilinmiyor")

            # Yorum (boya durumu)
            comment = listing.get("comment", "")
            if not comment:
                comment = "HATASIZ BOYASIZ" if "orijinal" in str(paint_status).lower() else paint_status

            # Gather extra fields
            body_type = listing.get("body_type", "") or listing.get("kasa_tipi", "")
            fuel_disp = listing.get("fuel", "") or listing.get("fuel_type", "")
            trans_disp = listing.get("transmission", "") or listing.get("gear_type", "")
            engine = listing.get("engine_size", "")
            hp = listing.get("horsepower", "")
            engine_str = f"{engine}" + (f" / {hp}" if hp else "") if engine else ""

            st.markdown(f"""
            <a href="{listing.get('url', '#')}" target="_blank" style="text-decoration:none; color:inherit;">
                <div style="background:#0f172a; border:1px solid #1e293b; border-radius:14px; overflow:hidden; margin-bottom:16px; display:flex; min-height:200px; transition: transform 0.2s ease, box-shadow 0.2s ease; cursor:pointer;"
                     onMouseOver="this.style.transform='scale(1.005)';this.style.boxShadow='0 4px 24px rgba(96,165,250,0.12)'"
                     onMouseOut="this.style.transform='scale(1)';this.style.boxShadow='none'">
                    <!-- Görsel (Sol) -->
                    <div style="width:210px; min-width:210px; overflow:hidden; position:relative; flex-shrink:0;">
                        <img src="{img_url}" style="width:100%; height:100%; object-fit:cover; min-height:200px;"
                             onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22150%22%3E%3Crect fill=%22%231e293b%22 width=%22200%22 height=%22150%22/%3E%3Ctext fill=%22%2364748b%22 font-family=%22sans-serif%22 font-size=%2214%22 dy=%2250%25%22 text-anchor=%22middle%22 x=%2250%25%22 y=%2250%25%22%3EGörsel Yok%3C/text%3E%3C/svg%3E'">
                        {f'<div style="position:absolute;bottom:8px;left:8px;background:rgba(0,0,0,0.7);color:#94a3b8;font-size:10px;padding:2px 7px;border-radius:6px;">📆 {listing_date}</div>' if listing_date else ''}
                    </div>

                    <!-- Bilgiler (Sağ) -->
                    <div style="flex:1; padding:16px 18px; display:flex; flex-direction:column;">
                        <!-- Üst: Marka/Model -->
                        <div style="margin-bottom:6px;">
                            <span style="color:#64748b; font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px;">
                                {listing.get('brand', '')} · {listing.get('year', '')}
                            </span>
                            <p style="margin:3px 0 0; color:#f1f5f9; font-size:15px; font-weight:700; line-height:1.3;">
                                {title}
                            </p>
                        </div>

                        <!-- Özellik Etiketleri -->
                        <div style="display:flex; flex-wrap:wrap; gap:6px; margin:8px 0;">
                            <span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">📏 {listing.get('km', 0):,} km</span>
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">⛽ {fuel_disp}</span>' if fuel_disp else ''}
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">⚙️ {trans_disp}</span>' if trans_disp else ''}
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">🚗 {body_type}</span>' if body_type else ''}
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">🔧 {engine_str}</span>' if engine_str else ''}
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">🎨 {color}</span>' if color and color != "Bilinmiyor" else ''}
                            {f'<span style="background:#1e293b; color:#94a3b8; padding:2px 9px; border-radius:8px; font-size:11px;">📍 {location}</span>' if location else ''}
                        </div>

                        <!-- Alt: Fiyat + Boya durumu -->
                        <div style="display:flex; justify-content:space-between; align-items:center; margin-top:auto; padding-top:10px; border-top:1px solid #1e293b22;">
                            <span style="color:#4ade80; font-size:24px; font-weight:900;">{_fmt(listing.get('price', 0))}</span>
                            <span style="background:{paint_color}22; color:{paint_color}; padding:5px 12px; border-radius:14px; font-size:11px; font-weight:700;">
                                {paint_icon} {paint_status}
                            </span>
                        </div>
                    </div>
                </div>
            </a>
            """, unsafe_allow_html=True)

    else:
        st.info("📡 Bu araç için canlı ilan bulunamadı. Scraper worker çalıştığında otomatik dolacak.")

    # ── PİYASA ZEKASI RAPORU (Edermi.com Entegrasyonu) ────────────────────────
    try:
        from yerimebak_ai_v5.dashboard.pages.piyasa_zekasi import render_piyasa_zekasi_panel
        _arac = sonuc.get('arac', {})
        render_piyasa_zekasi_panel(
            brand=str(_arac.get('brand', '')),
            model=str(_arac.get('model', '')),
            year=int(_arac.get('year', 2020)),
            km=int(_arac.get('km', 0)),
            price=float(_arac.get('price', 0))
        )
    except Exception as _pze:
        pass  # Piyasa zekası opsiyonel, ana analizi bloklamasın

    # ── AI MASTER RAPOR (JSON ENTEGRASYONU) ───────────────────────────────────
    st.markdown("---")
    st.subheader("🤖 Master AI - Ticari Değerleme & Fırsat Analizi")

    # v7.2 SAHİPSİZ UX — AKILLI VİTRİN
    # Extract v7.2 metrics from ai_json
    ai_json = sonuc.get('ai_json', {})
    m_val = ai_json.get('market_valuation', {})
    comm = ai_json.get('commercial_analysis', {})
    tech = ai_json.get('technical_scoring', {})
    liq = ai_json.get('liquidity_metrics', {})
    verdict = ai_json.get('dealer_verdict', {})
    meta = ai_json.get('analysis_meta', {})

    c1, c2, c3, c4 = st.columns(4)
    with c1:
        score = tech.get('opportunity_score', 0)
        color = "#4ade80" if score > 80 else "#fbbf24" if score > 50 else "#f87171"
        st.markdown(f"""
        <div style="text-align:center; background:#0f172a; border:2px solid {color}; border-radius:12px; padding:15px; height:140px;">
            <p style="margin:0; font-size:11px; color:#94a3b8;">FIRSAT SKORU</p>
            <p style="margin:10px 0; font-size:38px; font-weight:900; color:{color};">{score}</p>
            <p style="margin:0; font-size:12px; font-weight:700; color:#f1f5f9;">{verdict.get('decision', 'ANALİZ')}</p>
        </div>
        """, unsafe_allow_html=True)

    with c2:
        risk = tech.get('risk_percentage', 0)
        r_color = "#f87171" if risk > 35 else "#fbbf24" if risk > 15 else "#4ade80"
        st.markdown(f"""
        <div style="text-align:center; background:#0f172a; border:2px solid {r_color}33; border-radius:12px; padding:15px; height:140px;">
            <p style="margin:0; font-size:11px; color:#94a3b8;">RİSK ANALİZİ</p>
            <p style="margin:10px 0; font-size:38px; font-weight:900; color:{r_color};">%{risk}</p>
            <p style="margin:0; font-size:11px; color:#94a3b8;">Konservatif Güvenlik</p>
        </div>
        """, unsafe_allow_html=True)

    with c3:
        conf = meta.get('confidence_score', 0)
        st.markdown(f"""
        <div style="text-align:center; background:#0f172a; border:1px solid #60a5fa33; border-radius:12px; padding:15px; height:140px;">
            <p style="margin:0; font-size:11px; color:#94a3b8;">CONFIDENCE SCORE</p>
            <p style="margin:10px 0; font-size:38px; font-weight:900; color:#60a5fa;">%{conf}</p>
            <p style="margin:0; font-size:11px; color:#94a3b8;">Veri Derinliği: {m_val.get('competitor_count', 0)} İlan</p>
        </div>
        """, unsafe_allow_html=True)

    with c4:
        days = liq.get('final_days_to_sell', liq.get('estimated_days_to_sell', 0))
        st.markdown(f"""
        <div style="text-align:center; background:#0f172a; border:1px solid #a78bfa33; border-radius:12px; padding:15px; height:140px;">
            <p style="margin:0; font-size:11px; color:#94a3b8;">SATIŞ SÜRESİ</p>
            <p style="margin:10px 0; font-size:38px; font-weight:900; color:#a78bfa;">{days}</p>
            <p style="margin:0; font-size:12px; font-weight:700; color:#f1f5f9;">TAHMİNİ GÜN</p>
        </div>
        """, unsafe_allow_html=True)

    # v7.2 Commercial Analysis Cards
    st.markdown("<br>", unsafe_allow_html=True)
    tc1, tc2, tc3 = st.columns(3)
    with tc1:
        st.info(f"**Optimum Alım:**\n{_fmt(comm.get('optimal_purchase_price', 0))}")
    with tc2:
        st.warning(f"**Finansman Maliyeti:**\n{_fmt(comm.get('finance_cost', 0))}")
    with tc3:
        profit = comm.get('net_profit_tl', 0)
        margin = comm.get('net_margin_percent', 0)
        st.success(f"**Net Kar (TVM Dahil):**\n{_fmt(profit)} (%{margin})")

        # v8.0 DETERMINISTIC RISK ENGINE (CANLI YANSIMA)
        st.markdown("---")
        st.subheader("🔬 v8.0 Deterministic Risk Engine (Matematiksel Hesaplama)")

        risk_v8 = sonuc.get('risk_v8', {})
        km_analysis = sonuc.get('km_analysis')
        paint_analysis = sonuc.get('paint_analysis')

        if risk_v8:
            # Risk Motoru Sonuçları
            rc1, rc2, rc3, rc4 = st.columns(4)

            with rc1:
                km_risk = risk_v8.get('km_risk', 0)
                km_color = "#4ade80" if km_risk < 10 else "#fbbf24" if km_risk < 20 else "#f87171"
                st.markdown(f"""
                <div style="text-align:center; background:#0f172a; border:2px solid {km_color}33; border-radius:12px; padding:15px; height:120px;">
                    <p style="margin:0; font-size:11px; color:#94a3b8;">KM RİSK</p>
                    <p style="margin:10px 0; font-size:32px; font-weight:900; color:{km_color};">%{km_risk}</p>
                    <p style="margin:0; font-size:10px; color:#94a3b8;">Deterministik</p>
                </div>
                """, unsafe_allow_html=True)

            with rc2:
                paint_risk = risk_v8.get('paint_risk', 0)
                paint_color = "#4ade80" if paint_risk < 10 else "#fbbf24" if paint_risk < 20 else "#f87171"
                st.markdown(f"""
                <div style="text-align:center; background:#0f172a; border:2px solid {paint_color}33; border-radius:12px; padding:15px; height:120px;">
                    <p style="margin:0; font-size:11px; color:#94a3b8;">BOYA RİSK</p>
                    <p style="margin:10px 0; font-size:32px; font-weight:900; color:{paint_color};">%{paint_risk}</p>
                    <p style="margin:0; font-size:10px; color:#94a3b8;">Deterministik</p>
                </div>
                """, unsafe_allow_html=True)

            with rc3:
                change_risk = risk_v8.get('change_risk', 0)
                change_color = "#4ade80" if change_risk < 10 else "#fbbf24" if change_risk < 30 else "#f87171"
                st.markdown(f"""
                <div style="text-align:center; background:#0f172a; border:2px solid {change_color}33; border-radius:12px; padding:15px; height:120px;">
                    <p style="margin:0; font-size:11px; color:#94a3b8;">DEĞİŞEN RİSK</p>
                    <p style="margin:10px 0; font-size:32px; font-weight:900; color:{change_color};">%{change_risk}</p>
                    <p style="margin:0; font-size:10px; color:#94a3b8;">Deterministik</p>
                </div>
                """, unsafe_allow_html=True)

            with rc4:
                total_risk = risk_v8.get('total_risk', 0)
                total_color = "#4ade80" if total_risk < 30 else "#fbbf24" if total_risk < 50 else "#f87171"
                st.markdown(f"""
                <div style="text-align:center; background:#0f172a; border:2px solid {total_color}; border-radius:12px; padding:15px; height:120px;">
                    <p style="margin:0; font-size:11px; color:#94a3b8;">TOPLAM RİSK</p>
                    <p style="margin:10px 0; font-size:32px; font-weight:900; color:{total_color};">%{total_risk}</p>
                    <p style="margin:0; font-size:10px; color:#94a3b8;">Deterministik</p>
                </div>
                """, unsafe_allow_html=True)

            # Detaylı analiz
            if km_analysis:
                st.markdown(f"**📊 KM Analizi:** {km_analysis.analysis_note}")
                st.markdown(f"<small>Beklenen KM: {km_analysis.expected_km:,} | Fark: {km_analysis.km_difference:+,} KM | Ceza: %{km_analysis.km_penalty_score}</small>", unsafe_allow_html=True)

            if paint_analysis:
                # Boyalı parça sayısını hesapla (lokal boyalılar dahil)
                total_painted = len(paint_analysis.painted_parts)
                local_painted = len([p for p in paint_analysis.painted_parts if p.get('is_local', False)])

                st.markdown(f"**🎨 Boya Analizi:** {paint_analysis.analysis_note}")
                st.markdown(
                    f"<small>Boyalı Parça: {total_painted} "
                    f"({local_painted} lokal) | "
                    f"Değer Kaybı: %{paint_analysis.paint_impact_on_value}</small>",
                    unsafe_allow_html=True
                )

            # Deterministik Karar
            det_decision = risk_v8.get('decision', 'ANALİZ')
            det_opp = risk_v8.get('opportunity_score', 0)
            st.markdown(f"**🎯 Deterministik Karar:** **{det_decision}** (Fırsat: {det_opp}/100)")

            # Çıkış Fiyatı
            exit_price = risk_v8.get('exit_price', 0)
            st.markdown(f"**🚪 Deterministik Çıkış Fiyatı:** {_fmt(exit_price)}")

            # Satış Süresi
            days = risk_v8.get('estimated_days_to_sell', 0)
            st.markdown(f"**⏱️ Tahmini Satış Süresi:** {days} gün")

        # TEKNİK ÖZET
        st.markdown(f"""
        <div style="background:#1e293b; border-radius:12px; padding:20px; margin-top:15px; border-left:5px solid #60a5fa;">
            <h4 style="margin-top:0; color:#60a5fa;">🏛️ v7.2 — Ultra Dealer Portföy Raporu</h4>
            <p style="color:#e2e8f0; font-style:italic; line-height:1.6; margin-bottom:0;">
                {ai_json.get('technical_summary', 'Teknik detaylar işleniyor...')}
            </p>
            <p style="color:#94a3b8; font-size:11px; margin-top:10px;">
                *Finance cost hesaplaması stok süresi ve günlük %0.15 maliyet üzerinden yapılmıştır.
            </p>
        </div>
        """, unsafe_allow_html=True)

    # ── DENETİM RAPORU (GLM/STEPFUN) ──────────────────────────────────────────
    with st.expander("🕵️ AI Denetim & İkincil Görüş (Risk Kontrolü)"):
        if ai.get("glm"):
            st.markdown(ai["glm"])
        else:
            st.info("İkincil motor raporu hazırlanmadı.")





    # ── RAPORU İNDİR ──────────────────────────────────────────────────────────
    st.markdown("---")
    rapor_json = json.dumps(sonuc, ensure_ascii=False, indent=2, default=str)
    col1, col2 = st.columns(2)
    with col1:
        st.download_button(
            label="📥 Raporu JSON İndir",
            data=rapor_json,
            file_name=f"yerimebak_analiz_{arac['brand']}_{arac['model']}_{datetime.now().strftime('%Y%m%d_%H%M')}.json",
            mime="application/json",
            use_container_width=True,
        )
    with col2:
        # Basit metin raporu
        metin = f"""YERİMEBAK AI — ARAÇ DEĞERLEMESİ
{'='*50}
{arac['brand']} {arac['model']} {arac.get('paket','')} | {arac['year']} | {arac['km']:,} km

PAZAR ORTALAMASI  : {f['piyasa_ortalamasi']:,.0f} ₺
HESAPLANAN DEĞER  : {d['hesaplanan_fiyat']:,.0f} ₺
TAVSİYE ALIŞ      : {f['tavsiye_alis']:,.0f} ₺
MAKUL ALIŞ        : {f['makul_alis']:,.0f} ₺
FIRSAT ALIŞI      : {f['firsat_alis']:,.0f} ₺

DEĞER KAYBI (DKK) : %{d['dkk']*100:.1f}
6 AY GETİRİ       : +%{f['senaryo_tavsiye']['getiri_6ay_pct']}
1 YIL GETİRİ      : +%{f['senaryo_tavsiye']['getiri_1yil_pct']}

---
{"GEMİNİ RAPORU:" if ai.get("gemini") else ""}
{ai.get("gemini") or ""}

---
{"GLM DENETİM:" if ai.get("glm") else ""}
{ai.get("glm") or ""}

Rapor Tarihi: {sonuc['timestamp'][:16]}
"""
        st.download_button(
            label="📄 Raporu TXT İndir",
            data=metin,
            file_name=f"yerimebak_analiz_{arac['brand']}_{arac['model']}_{datetime.now().strftime('%Y%m%d_%H%M')}.txt",
            mime="text/plain",
            use_container_width=True,
        )
def _wrap_orchestrator_result(analysis: dict) -> dict:
    """
    Orkestratörden gelen ham sonucu Dashboard'un beklediği tam_analiz formatına sarmalar.
    """
    v8 = analysis.get('valuation_v8', {})
    market_v = v8.get('market_valuation', {})
    comm_v = v8.get('commercial_analysis', {})
    tech_v = v8.get('technical_scoring', {})
    liq_v = v8.get('liquidity_metrics', {})
    verdict_v = v8.get('dealer_verdict', {})

    # Sabit Veriler (Şubat 2026 - Türkiye Gerçeği)
    TUFE_YILLIK = 0.50 # %50 Yıllık Enflasyon
    TUFE_6_AYLIK = 0.25 # %25 Altı Aylık Enflasyon
    ARAC_DEGER_KAZANIM_YILLIK = 0.45 # %45 Yıllık Araç Değerlenmesi (Nominal)

    current_year = 2026
    yil_val = analysis.get('year')
    yil = int(yil_val) if yil_val and int(yil_val) > 1990 else 2021
    yas = max(1, current_year - yil) # En az 1 farz et

    km_val = analysis.get('km')
    km = int(km_val) if km_val else (yas * 15000)

    # 1. Yaş Kaybı (Sadece istatistiksel bilgi için, Piyasa Ortalaması zaten yaşı içerir)
    yas_kaybi = 1 - (0.95 ** yas)

    # 2. Kondisyon Kaybı (KM + Hasar + Tramer)
    # KM Katsayısı
    km_k = 1.0
    if km > 200000: km_k = 0.60
    elif km > 150000: km_k = 0.75
    elif km > 100000: km_k = 0.88
    elif km > 50000: km_k = 0.94
    else: km_k = 0.98

    # Hasar/Boya Kaybı (Sadece fiziksel kondisyon)
    kondisyon_hasar_kaybi = 0.0
    poison_count = 0
    paint_info = analysis.get('paint_info', {})
    if isinstance(paint_info, dict):
        poison_count = len(paint_info.get('changed_parts', [])) + len(paint_info.get('painted_parts', []))
    kondisyon_hasar_kaybi = min(0.35, poison_count * 0.025)

    # Toplam Kondisyon Kaybı (Piyasa ortalamasından yapılacak kesinti)
    kondisyon_kaybi = (1 - km_k) + kondisyon_hasar_kaybi

    # Toplam DKK (Dashboard gösterimi için: Yaş + Kondisyon)
    dkk = min(0.85, yas_kaybi + kondisyon_kaybi)

    price = float(analysis.get('price', 0))
    market_avg = float(market_v.get('market_price_avg', price))

    # 🚨 PİYASA ORTALAMASI DÜZELTME (Fallback durumu)
    # Eğer veritabanında araç yoksa ve market_avg ilan fiyatına düştüyse, Türkiye pazarındaki
    # "ilan köpüğü" (şişirilmiş fiyatlar) gerçeğini göz önüne alarak piyasa ortalamasını ilan
    # fiyatının yaklaşık %3 altına çekiyoruz.

    # Hesaplanan değer: Piyasa ortalamasından sabit %2 kayıp
    hesaplanan_fiyat = int(market_avg * 0.98)

    # Senaryo Referans Fiyatı
    ref_fiyat = price if price > 0 else market_avg

    def kar_senaryosu(alis: int):
        # Alış fiyatı üzerinden 6 ay ve 1 yıl sonraki nominal satış tahmini
        satis_6ay = int(alis * (1 + ARAC_DEGER_KAZANIM_YILLIK / 2))
        satis_1yil = int(alis * (1 + ARAC_DEGER_KAZANIM_YILLIK))

        kar_6ay = satis_6ay - alis
        kar_1yil = satis_1yil - alis

        # Enflasyon Arındırılmış (Reel) Kar
        # Nominal kardan, paranın enflasyon karşısındaki değer kaybını düşüyoruz
        reel_kar_6ay = kar_6ay - int(alis * TUFE_6_AYLIK)
        reel_kar_1yil = kar_1yil - int(alis * TUFE_YILLIK)

        return {
            "alis": alis,
            "kar_6ay_nominal": kar_6ay,
            "kar_1yil_nominal": kar_1yil,
            "getiri_6ay_pct": round((kar_6ay / alis) * 100, 1) if alis > 0 else 0,
            "getiri_1yil_pct": round((kar_1yil / alis) * 100, 1) if alis > 0 else 0,
            "reel_kar_6ay": reel_kar_6ay,
            "reel_kar_1yil": reel_kar_1yil
        }

    tavsiye_alis = int(comm_v.get('optimal_purchase_price', market_avg * 0.93))

    return {
        "arac": {
            "brand": analysis.get('brand', 'Bilinmiyor'),
            "model": analysis.get('model', 'Bilinmiyor'),
            "year": yil,
            "km": km,
            "price": price,
            "yakit": analysis.get('fuel', 'Bilinmiyor'),
            "sanziman": analysis.get('transmission', 'Bilinmiyor'),
            "paket": analysis.get('series', ''),
            # Extended fields from Sahibinden scraper
            "body_type": analysis.get('body_type', ''),
            "drive_type": analysis.get('drive_type', ''),
            "listing_no": analysis.get('listing_no', ''),
            "listing_date": analysis.get('listing_date', ''),
            "color": analysis.get('color', ''),
            "engine_size": analysis.get('engine_size', ''),
            "horsepower": analysis.get('horsepower', ''),
            "url": analysis.get('url', ''),
        },
        "deger_analizi": {
            "hesaplanan_fiyat": hesaplanan_fiyat,
            "dkk": dkk,
            "yas": yas,
            "segment": "C", # Placeholder
            "yas_kaybi_oran": yas_kaybi,
            "km_katsayisi": km_k,
            "hasar_kayip_oran": kondisyon_hasar_kaybi,
            "tramer_kayip_oran": 0.0,
            "veri_kaynagi": "📊 Canlı Link Analizi"
        },
        "fiyat_analizi": {
            "piyasa_ortalamasi": market_avg,
            "tavsiye_alis": int(ref_fiyat * 0.89),
            "makul_alis": int(ref_fiyat * 0.85),
            "firsat_alis": int(ref_fiyat * 0.80),
            "senaryo_tavsiye": kar_senaryosu(int(ref_fiyat * 0.89)),
            "senaryo_makul": kar_senaryosu(int(ref_fiyat * 0.85)),
            "senaryo_firsat": kar_senaryosu(int(ref_fiyat * 0.80)),
            "enflasyon_6ay_pct": int(TUFE_6_AYLIK * 100),
            "enflasyon_1yil_pct": int(TUFE_YILLIK * 100),
            "arac_deger_artis_1yil_pct": int(ARAC_DEGER_KAZANIM_YILLIK * 100)
        },
        "piyasa": {
            "listings": [],
            "stats": analysis.get('market_context', {})
        },
        "ai_rapor": {
            "gemini": analysis.get('vision_analysis_report', 'Rapor hazırlanıyor...'),
            "glm": analysis.get('action_recommendation', '')
        },
        "ai_json": v8, # V8 Pack
        "risk_v8": {
            "total_risk": tech_v.get('risk_percentage', 0),
            "km_risk": int(yas_kaybi * 100), # Placeholder or derived
            "paint_risk": int(kondisyon_hasar_kaybi * 100),
            "opportunity_score": tech_v.get('opportunity_score', 0),
            "decision": verdict_v.get('decision', 'ANALİZ'),
            "exit_price": v8.get('exit_strategy', {}).get('estimated_exit_price', 0),
            "estimated_days_to_sell": liq_v.get('estimated_days_to_sell', 0)
        },
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    st.set_page_config(page_title="Araç Analiz - Yerimebak AI", layout="wide")
    render_analiz_page()
