import streamlit as st
import time

def render_kayit_page():
    st.markdown("""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');
    
        .stApp, .stAppViewContainer {
            background: transparent !important;
            font-family: 'Inter', sans-serif !important;
            color: #e0e0e0;
        }
        header, #MainMenu, footer { visibility: hidden !important; }
    
        .animated-bg {
            position: fixed; top: 0; left: 0; right: 0; bottom: 0;
            z-index: -10; overflow: hidden;
            background: linear-gradient(135deg, #0a0a1a 0%, #0d1b2a 25%, #1b0a2e 50%, #0d1b2a 75%, #0a0a1a 100%);
            background-size: 400% 400%; animation: gradientShift 15s ease infinite;
        }
        @keyframes gradientShift { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        .particle { position: absolute; width: 4px; height: 4px; background: rgba(255, 215, 0, 0.3); border-radius: 50%; animation: float linear infinite; }
        @keyframes float { 0% { transform: translateY(100vh) rotate(0deg); opacity: 0; } 10% { opacity: 1; } 90% { opacity: 1; } 100% { transform: translateY(-100vh) rotate(720deg); opacity: 0; } }
    
        @keyframes slideInUp { from { transform: translateY(40px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        @keyframes shimmer { 0% { background-position: -200% center; } 100% { background-position: 200% center; } }
    
        /* Glassmorphism Container */
        div[data-testid="column"]:has(.auth-card) {
            background: rgba(30, 41, 59, 0.45) !important;
            backdrop-filter: blur(16px) !important;
            -webkit-backdrop-filter: blur(16px) !important;
            border: 1px solid rgba(255, 255, 255, 0.1) !important;
            border-radius: 24px !important; 
            padding: 40px !important;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4) !important;
            animation: slideInUp 0.8s ease-out; margin-top: 20px;
        }
        
        .stTextInput > div > div > input {
            background: rgba(15, 23, 42, 0.6) !important;
            border: 1px solid rgba(148, 163, 184, 0.3) !important;
            border-radius: 10px !important; color: #F8FAFC !important;
            padding: 14px !important; font-size: 1rem !important;
        }
        .stTextInput > div > div > input:focus {
            border-color: #ffd700 !important;
            box-shadow: 0 0 15px rgba(255, 215, 0, 0.3) !important;
        }
        .stTextInput label {
            color: #CBD5E1 !important;
            font-size: 0.9rem !important;
            font-weight: 500 !important;
        }
        
        .stButton > button {
            background: linear-gradient(90deg, #FF8C00, #FF4500) !important;
            color: #FFFFFF !important; border: none !important; border-radius: 50px !important;
            font-weight: 800 !important; font-size: 1.15rem !important;
            padding: 18px 24px !important; width: 100%; transition: all 0.3s ease !important;
            letter-spacing: 0.5px !important;
            box-shadow: 0 6px 20px rgba(255, 69, 0, 0.3) !important;
        }
        .stButton > button:hover { 
            transform: translateY(-2px) !important; 
            box-shadow: 0 8px 25px rgba(255, 69, 0, 0.5) !important; 
        }

        /* Info Cards */
        .info-card {
            background: rgba(15, 23, 42, 0.6);
            border-left: 4px solid #3b82f6;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            transition: all 0.3s ease;
        }
        .info-card:hover {
            transform: translateX(5px);
            background: rgba(30, 41, 59, 0.8);
        }
        .info-card h4 {
            color: #F8FAFC;
            font-size: 1.1rem;
            margin: 0 0 8px 0;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .info-card p {
            color: #94A3B8;
            font-size: 0.95rem;
            margin: 0;
            line-height: 1.5;
        }
    </style>
    <div class="animated-bg">
        <div class="particle" style="left:10%; animation-duration:12s; animation-delay:0s;"></div>
        <div class="particle" style="left:30%; animation-duration:15s; animation-delay:4s;"></div>
        <div class="particle" style="left:50%; animation-duration:14s; animation-delay:3s;"></div>
        <div class="particle" style="left:70%; animation-duration:13s; animation-delay:2.5s;"></div>
        <div class="particle" style="left:90%; animation-duration:19s; animation-delay:4.5s;"></div>
    </div>
    """, unsafe_allow_html=True)
    
    try:
        from yerimebak_ai_v5.dashboard.services.auth_service import get_auth_service
        auth = get_auth_service()
        _AUTH_OK = True
    except Exception as e:
        _AUTH_OK = False
        auth = None
        st.error(f"Auth servisi yüklenemedi: {e}")
    
    if "auth_step" not in st.session_state: st.session_state["auth_step"] = "phone"
    if "auth_mode" not in st.session_state: st.session_state["auth_mode"] = "register"
    if "auth_phone" not in st.session_state: st.session_state["auth_phone"] = ""
    if "logged_in_user" not in st.session_state: st.session_state["logged_in_user"] = None
    
    col_info, col_center, _pad = st.columns([1.1, 1.2, 0.1], gap="large")
    
    with col_info:
        st.markdown("""
        <div style="margin-top: 40px; margin-bottom: 30px;">
            <h1 style="color: #F1F5F9; font-size: 2.2rem; font-weight: 900; line-height: 1.2; margin-bottom: 10px;">
                Neden YERİMEBAK AI'a<br><span style="color:#60A5FA;">Kayıt Olmalıyım?</span>
            </h1>
            <p style="color: #94A3B8; font-size: 1.05rem; margin-bottom: 30px;">
                Galericiler ve al-sat uzmanları için tasarlanmış ekosisteme dahil olarak rekabette her zaman önde olun.
            </p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
        <div class="info-card">
            <h4><span style="font-size: 1.5rem;">🧩</span> Her İlanda Anında Değerleme</h4>
            <p>Siz sahibinden veya arabam.com'da gezinirken <b>Chrome Uzantımız</b> arka planda otomatik analiz yapar ve size piyasa ortalaması ile net kâr marjını sunar.</p>
        </div>
        <div class="info-card" style="border-left-color: #10B981;">
            <h4><span style="font-size: 1.5rem;">🛡️</span> Yapay Zeka Risk & Hasar Analizi</h4>
            <p>KM düşürülmesi ihtimali, boyalı parça etkisi ve hasar kayıtlarının aracın gelecekteki satış hızını (likiditesini) ne kadar etkilediğini önceden öğrenin.</p>
        </div>
        <div class="info-card" style="border-left-color: #F59E0B;">
            <h4><span style="font-size: 1.5rem;">💎</span> Ücretsiz Başlangıç Paketi</h4>
            <p>Kayıt olduğunuz an <b>3 Sorgu Kredisi</b> anında hesabınıza tanımlanır. Hiçbir ödeme yapmadan kendi gözlerinizle test edip fırsatları yakalayın.</p>
        </div>
        """, unsafe_allow_html=True)

    with col_center:
        st.markdown("<div class='auth-card'></div>", unsafe_allow_html=True)
        is_register = st.session_state["auth_mode"] == "register"
        mode_title = "Kayıt Ol" if is_register else "Giriş Yap"
        
        st.markdown(f"""
            <div style='text-align: center; margin-bottom: 25px;'>
                <div style='display: flex; justify-content: center; align-items: center; gap: 8px; margin-bottom: 15px;'>
                    <span style='font-size: 1.6rem;'>🖼️</span>
                    <span style='font-size: 1.6rem; font-weight: 800; color: #F8FAFC; letter-spacing: 0.5px;'>YERİMEBAK AI</span>
                    <span style='background: #4F46E5; color: white; padding: 2px 8px; border-radius: 8px; font-size: 0.75rem; font-weight: bold;'>v8.0</span>
                </div>
                <h2 style='color: #F1F5F9; font-size: 1.7rem; font-weight: 800; margin-bottom: 5px;'>
                    {mode_title}
                </h2>
                <p style='color: #94A3B8; font-size: 0.9rem;'>
                    {('İlk kayıtta <strong style="color:#ffd700;">3 sorgu ücretsiz!</strong>' if is_register else 'Tekrar hoş geldin!')}
                </p>
            </div>
        """, unsafe_allow_html=True)
        
        if st.session_state["auth_step"] == "phone":
            if is_register:
                name_input = st.text_input("Ad Soyad", placeholder="Adınız Soyadınız")
            
            phone_input = st.text_input("Cep Telefonu", placeholder="5XX XXX XX XX")

            _is_admin_attempt = bool(phone_input and ("admin" in phone_input.lower() or "@" in phone_input))

            if _is_admin_attempt:
                st.warning("⚠️ Admin girişi için lütfen aşağıdaki **🔐 Admin Girişi** butonunu kullanın.")
            
            if st.button("📱 SMS ile Devam Et", use_container_width=True):
                if _is_admin_attempt:
                    st.session_state["auth_step"] = "admin_login"
                    st.rerun()
                elif is_register and not name_input:
                    st.error("Lütfen adınızı girin.")
                elif not phone_input or len(phone_input) < 10:
                    st.error("Geçerli bir telefon numarası girin.")
                else:
                    if _AUTH_OK:
                        otp = auth.generate_otp(phone_input)
                        st.session_state["auth_phone"] = phone_input
                        if is_register:
                            st.session_state["auth_name"] = name_input
                        st.session_state["debug_otp"] = otp
                        st.session_state["auth_step"] = "otp"
                        st.rerun()
                        
            st.markdown("""<div style="display: flex; align-items: center; text-align: center; margin: 20px 0;">
                            <hr style="flex-grow: 1; border: 0; border-top: 1px solid rgba(255,255,255,0.2);">
                            <span style="padding: 0 15px; color: #94A3B8; font-size: 0.9em;">VEYA</span>
                            <hr style="flex-grow: 1; border: 0; border-top: 1px solid rgba(255,255,255,0.2);">
                        </div>""", unsafe_allow_html=True)
                        
            if st.button("🌐 Google ile Devam Et", use_container_width=True):
                st.session_state["auth_step"] = "google_auth"
                st.rerun()
            
            st.markdown("""<div style="display: flex; align-items: center; text-align: center; margin: 15px 0;">
                            <hr style="flex-grow: 1; border: 0; border-top: 1px solid rgba(255,255,255,0.1);">
                        </div>""", unsafe_allow_html=True)

            st.markdown("""
            <div style='background:rgba(239,68,68,0.1); border:1px solid rgba(239,68,68,0.3); border-radius:12px; padding:12px; text-align:center; margin-bottom:8px;'>
                <span style='color:#f87171; font-weight:700;'>🔐 Yönetici misiniz?</span>
            </div>
            """, unsafe_allow_html=True)
            if st.button("🔐 Admin Girişi", use_container_width=True):
                st.session_state["auth_step"] = "admin_login"
                st.rerun()
            
            st.markdown("<div style='text-align:center; margin-top:20px;'>", unsafe_allow_html=True)
            if st.button("Zaten hesabınız var mı? Giriş Yap" if is_register else "Hesabınız yok mu? Kayıt Ol", key="switch_auth_mode"):
                st.session_state["auth_mode"] = "login" if is_register else "register"
                st.rerun()
            st.markdown("</div>", unsafe_allow_html=True)
            
        elif st.session_state["auth_step"] == "admin_login":
            st.markdown("""
                <div style='background:rgba(239,68,68,0.1); border:1px solid rgba(239,68,68,0.3); border-radius:12px; padding:15px; margin-bottom:20px; text-align:center;'>
                    <span style='color:#f87171; font-weight:700;'>🔐 Admin Girişi</span>
                </div>
            """, unsafe_allow_html=True)
            
            admin_email = st.text_input("📧 Email", value="admin@yerimebak.com", key="admin_email")
            admin_pw = st.text_input("🔑 Şifre", type="password", key="admin_password")
            
            col_adm1, col_adm2 = st.columns([1, 2])
            with col_adm1:
                if st.button("⬅️ Geri Dön"):
                    st.session_state["auth_step"] = "phone"
                    st.rerun()
            with col_adm2:
                if st.button("🔐 Admin Girişi", use_container_width=True):
                    if not admin_email or not admin_pw:
                        st.error("Email ve şifre gerekli.")
                    else:
                        try:
                            from yerimebak_ai_v5.services.auth_service import get_auth_service as get_svc_auth
                            svc_auth = get_svc_auth()
                            result = svc_auth.login(admin_email, admin_pw)
                            if result.get("success"):
                                user = result["user"]
                                if str(user.get("role", "")).lower().strip() == "admin" or str(user.get("email", "")).lower().strip() == "admin@yerimebak.com":
                                    st.session_state["logged_in_user"] = {
                                        "user_id": user["id"],
                                        "full_name": user.get("full_name", "Admin"),
                                        "email": user["email"],
                                        "api_key": user.get("api_key"),
                                        "credits": user.get("credits", 999),
                                        "tier": user.get("tier", "enterprise"),
                                        "role": user.get("role", "admin"),
                                    }
                                    st.session_state["menu_selection"] = "🛡️ Admin Panel"
                                    st.success("✅ Admin girişi başarılı!")
                                    time.sleep(0.5)
                                    st.rerun()
                                else:
                                    st.error("Bu hesap admin yetkisine sahip değil.")
                            else:
                                st.error(f"❌ {result.get('error', 'Giriş başarısız')}")
                        except Exception as e:
                            st.error(f"Admin giriş hatası: {e}")
            
            st.markdown("""
            <div style='margin-top:15px; padding:12px; background:rgba(15,23,42,0.5); border-radius:10px; border:1px solid rgba(148,163,184,0.1);'>
                <p style='color:#94A3B8; font-size:0.8rem; margin:0;'>
                💡 <b>İlk kez mi?</b> Admin hesabı oluşturmak için terminalde:<br>
                <code style='color:#fbbf24;'>POST /api/v1/auth/admin/create</code>
                </p>
            </div>
            """, unsafe_allow_html=True)

        elif st.session_state["auth_step"] == "google_auth":
            st.markdown("""
            <div style="background: rgba(255,255,255,0.9); padding: 20px; border-radius: 12px; text-align: center; margin-bottom: 20px;">
                <img src="https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg" width="40" style="margin-bottom:10px;">
                <h3 style="color: #333; margin:0;">Google ile Oturum Aç</h3>
                <p style="color: #666; font-size:13px; margin-top:5px;">Lütfen Gmail adresinizi doğrulayın.</p>
            </div>
            """, unsafe_allow_html=True)
            
            g_email = st.text_input("Gmail Adresiniz", placeholder="isim@gmail.com")
            
            col_g1, col_g2 = st.columns([1, 2])
            with col_g1:
                if st.button("⬅️ Geri Dön"):
                    st.session_state["auth_step"] = "phone"
                    st.rerun()
            with col_g2:
                if st.button("✅ Hesabı Bağla", use_container_width=True):
                    if not g_email or "@" not in g_email:
                        st.error("Lütfen geçerli bir e-posta girin.")
                    else:
                        if is_register:
                            name = st.session_state.get("auth_name", g_email.split('@')[0])
                            res = auth.register_with_google(g_email, name)
                            if res.get("success"):
                                st.session_state["logged_in_user"] = auth.login_with_google(g_email)
                                st.session_state["menu_selection"] = "🏪 Vitrin"
                                st.success("✅ Google ile Kayıt başarılı! 3 Sorgu hediyeniz tanımlandı.")
                                time.sleep(1)
                                st.switch_page("app_v2.py")
                            else:
                                # Zaten kayıtlıysa direkt giriş yap
                                st.session_state["logged_in_user"] = auth.login_with_google(g_email)
                                st.session_state["menu_selection"] = "🏪 Vitrin"
                                st.success(f"✅ Hoş geldin!")
                                time.sleep(1)
                                st.switch_page("app_v2.py")
                        else:
                            res = auth.login_with_google(g_email)
                            if res.get("success"):
                                st.session_state["logged_in_user"] = res
                                st.session_state["menu_selection"] = "🏪 Vitrin"
                                st.success(f"✅ Hoş geldin {res['full_name']}!")
                                time.sleep(1)
                                st.switch_page("app_v2.py")
                            else:
                                st.error(res.get("error"))
    
        elif st.session_state["auth_step"] == "otp":
            st.markdown(f"""
                <div style='background:rgba(255,215,0,0.1); border:1px solid rgba(255,215,0,0.3); border-radius:12px; padding:15px; margin-bottom:20px; text-align:center;'>
                    <span style='color:#ffd700; font-weight:600;'>{st.session_state['auth_phone']}</span> numarasına gönderilen 6 haneli kodu girin.
                </div>
            """, unsafe_allow_html=True)
            
            otp_input = st.text_input("6 Haneli Kod", max_chars=6)
            debug_otp = st.session_state.get("debug_otp", "")
            
            with st.expander("🛠️ Sistem Yöneticisi: Demo Modu OTP", expanded=True):
                st.code(debug_otp, language="text")
            
            col_b, col_v = st.columns([1, 2])
            with col_b:
                if st.button("⬅️ Geri"):
                    st.session_state["auth_step"] = "phone"
                    st.rerun()
            with col_v:
                if st.button("✓ Doğrula ve Başla"):
                    if not otp_input or len(otp_input) != 6:
                        st.error("❌ 6 haneli kodu eksiksiz girin.")
                    elif _AUTH_OK and (auth.verify_otp(st.session_state['auth_phone'], otp_input) or otp_input == debug_otp):
                        if is_register:
                            name = st.session_state.get("auth_name", "Kullanıcı")
                            result = auth.register_user(name, st.session_state['auth_phone'])
                            if result["success"]:
                                login = auth.login_with_phone(st.session_state['auth_phone'])
                                st.session_state["logged_in_user"] = login
                                st.session_state["menu_selection"] = "🏪 Vitrin"
                                st.success("✅ Kayıt başarılı! 3 Sorgu hediyeniz tanımlandı.")
                                time.sleep(1)
                                st.switch_page("app_v2.py")
                            else:
                                st.error(result["error"])
                        else:
                            result = auth.login_with_phone(st.session_state['auth_phone'])
                            if result["success"]:
                                st.session_state["logged_in_user"] = result
                                st.session_state["menu_selection"] = "🏪 Vitrin"
                                st.success(f"✅ Hoş geldin {result['full_name']}!")
                                time.sleep(1)
                                st.switch_page("app_v2.py")
                            else:
                                st.error(result["error"])
                    else:
                        st.error("❌ Hatalı veya süresi geçmiş kod.")

if __name__ == "__main__":
    st.set_page_config(page_title="Kayıt Ol | YERİMEBAK AI", page_icon="🚗", layout="wide")
    render_kayit_page()
