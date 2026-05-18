# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Kredi & Fiyatlandırma (Otomatik Yükleme)
"""
import streamlit as st

def render_pricing_page():
    st.markdown("""
    <div style='text-align: center; margin-bottom: 40px; margin-top: 20px;'>
        <div style='display: flex; justify-content: center; align-items: center; gap: 10px; margin-bottom: 10px;'>
            <span style='font-size: 2.5rem;'>💎</span>
            <h1 style='color: #F1F5F9; font-weight: 900; font-size: 2.5rem; margin: 0;'>Kredi Yükle</h1>
        </div>
        <p style='color: #94A3B8; font-size: 1.1rem; max-width: 600px; margin: 15px auto 0;'>
            Dilediğiniz paketi seçin, anında hesabınıza yüklensin. Kredilerinizi yapay zeka analizlerinde ve Chrome uzantısında kullanabilirsiniz.
        </p>
    </div>
    """, unsafe_allow_html=True)

    user = st.session_state.get('logged_in_user')
    if not user:
        st.warning("Lütfen işlem yapmadan önce giriş yapın.")
        return

    # Campaign pricing
    packages = {
        "1 Kredi": {"credits": 1, "price": 100, "popular": False, "color": "#3B82F6", "gradient": "linear-gradient(135deg, #2563EB, #3B82F6)"},
        "5 Kredi": {"credits": 5, "price": 400, "popular": False, "color": "#F59E0B", "gradient": "linear-gradient(135deg, #D97706, #F59E0B)"},
        "10 Kredi": {"credits": 10, "price": 750, "popular": True, "color": "#FFD700", "gradient": "linear-gradient(135deg, #FF8C00, #FFD700)"},
        "50 Kredi (Kurumsal)": {"credits": 50, "price": 3000, "popular": False, "color": "#10B981", "gradient": "linear-gradient(135deg, #059669, #10B981)"}
    }

    cols = st.columns(4)

    for i, (pkg_name, pkg) in enumerate(packages.items()):
        with cols[i]:
            border_col = pkg['color'] if pkg['popular'] else 'rgba(255, 255, 255, 0.1)'
            shadow = f"box-shadow: 0 10px 30px {pkg['color']}33;" if pkg['popular'] else "box-shadow: 0 8px 20px rgba(0,0,0,0.3);"
            bg_color = "rgba(30, 41, 59, 0.45)"

            st.markdown(f"""
            <div style="background: {bg_color}; backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1.5px solid {border_col}; border-radius: 24px; padding: 30px 20px; text-align: center; {shadow} margin-bottom: 20px; position: relative; overflow: hidden;">
                {'<div style="background: linear-gradient(90deg, #FF8C00, #FFD700); color: #000; font-size: 0.75rem; font-weight: 800; padding: 6px 14px; border-radius: 20px; display: inline-block; margin-bottom: 15px; letter-spacing: 0.5px; box-shadow: 0 2px 10px rgba(255, 140, 0, 0.4);">🔥 EN POPÜLER</div>' if pkg['popular'] else '<div style="height: 33px; margin-bottom: 15px;"></div>'}
                <h2 style="color: #F8FAFC; font-weight: 800; font-size: 1.8rem; margin: 0; letter-spacing: 0.5px;">{pkg_name}</h2>
                <h3 style="background: {pkg['gradient']}; -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-weight: 900; font-size: 2.8rem; margin: 15px 0;">{pkg['price']} ₺</h3>
                <p style="color: #CBD5E1; margin-top: 15px; font-size: 0.95rem; font-weight: 500;">Anında Aktif Olur</p>
            </div>
            """, unsafe_allow_html=True)

            if st.button(f"Satin Al", key=f"buy_{pkg_name}", use_container_width=True):
                from yerimebak_ai_v5.services.payment_service import get_payment_service
                from yerimebak_ai_v5.dashboard.services.billing_service import get_billing_service

                billing = get_billing_service()
                ps = get_payment_service()
                pkg_key_map = {"1 Kredi": "tek", "5 Kredi": "besli", "10 Kredi": "onlu", "50 Kredi (Kurumsal)": "kurumsal"}
                pkg_key = pkg_key_map.get(pkg_name, "tek")
                user_id = user.get('id')

                if user_id:
                    order = ps.create_payment_order(user_id=user_id, package_key=pkg_key)
                    if order and "error" not in order:
                        st.success(f"Odeme talebi olusturuldu! (ID: {order.get('order_id', 'N/A')}) Admin onayi bekleniyor.")
                        st.info(f"Paket: {pkg_name} - {pkg['price']} TL. Odemeniz admin onayindan sonra aktif edilecektir.")
                    else:
                        st.error(f"Hata: {order.get('error', 'Bilinmeyen hata')}")
                else:
                    st.error("Kullanici ID bulunamadi. Lutfen tekrar giris yapin.")

    st.markdown("---")

    st.markdown("""
    <div style="background: rgba(30, 41, 59, 0.45); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 24px; padding: 30px; max-width: 800px; margin: 20px auto;">
        <h3 style="color: #F1F5F9; font-weight: 800; display: flex; align-items: center; gap: 8px; margin-bottom: 20px;">
            <span style="font-size: 1.4rem;">ℹ️</span> Kredi Kullanımı Hakkında
        </h3>
        <ul style="color: #CBD5E1; font-size: 1.05rem; line-height: 1.8; margin-left: 10px;">
            <li>Her bir <b>🔬 Yapay Zeka Analizi</b> sadece <b>1 kredi</b> düşer.</li>
            <li>Satın aldığınız kredilerin <b>kullanım süresi yoktur</b> (Sınırsız süreli geçerlidir).</li>
            <li>Chrome Uzantısını kullanarak girdiğiniz ilanlarda arka planda düşüm işlemi API anahtarınız üzerinden anında yapılır.</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)

    # Active Balance Display
    st.markdown(f"""
    <div style="background: rgba(16, 185, 129, 0.15); backdrop-filter: blur(10px); border: 1.5px solid rgba(16, 185, 129, 0.4); border-radius: 16px; padding: 25px; text-align: center; max-width: 500px; margin: 30px auto 0; box-shadow: 0 8px 25px rgba(16, 185, 129, 0.15);">
        <div style="color: #94A3B8; font-size: 1rem; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 5px;">Mevcut Krediniz</div>
        <div style="color: #10B981; font-weight: 900; font-size: 2.5rem; letter-spacing: 0.5px;">{user['credits']} <span style="font-size: 1.2rem; font-weight: 600; color: #6EE7B7;">KREDİ</span></div>
    </div>
    """, unsafe_allow_html=True)
