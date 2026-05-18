import streamlit as st
from datetime import datetime

def render_error_monitor(errors: list):
    """
    Görsel olarak iyileştirilmiş, kullanıcı dostu hata monitörü.
    WCAG AA uyumlu renkler ve açıklayıcı mesajlar.
    """
    
    # Başlık - yüksek kontrastlı
    st.markdown("""
    <div style='background: linear-gradient(90deg, rgba(220, 38, 38, 0.1), rgba(220, 38, 38, 0.05));
                padding: 15px; border-radius: 10px; 
                border-left: 4px solid #DC2626; margin-bottom: 20px;'>
        <h2 style='color: #FCA5A5; margin: 0; font-size: 18px;'>
            🚨 Sistem Hata Monitörü
        </h2>
        <p style='color: #E5E7EB; margin: 5px 0 0 0; font-size: 12px;'>
            Son 24 saat içindeki hatalar
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    if not errors:
        # Başarılı durum - yüksek kontrast
        st.markdown("""
        <div style='background: rgba(5, 150, 105, 0.1);
                    padding: 15px; border-radius: 10px;
                    border-left: 4px solid #059669;'>
            <p style='color: #6EE7B7; margin: 0; font-size: 14px;'>
                ✅ Sistem sağlıklı. Son 24 saat içinde hata bildirilmedi.
            </p>
        </div>
        """, unsafe_allow_html=True)
        return

    # Hata listesi
    for idx, err in enumerate(errors):
        severity = err.get('severity', 'medium')
        
        # Şiddete göre renk belirleme (WCAG AA uyumlu)
        if severity == 'critical':
            bg_color = "rgba(220, 38, 38, 0.15)"
            border_color = "#DC2626"
            text_color = "#FCA5A5"
            icon = "🔴"
        elif severity == 'high':
            bg_color = "rgba(217, 119, 6, 0.15)"
            border_color = "#D97706"
            text_color = "#FCD34D"
            icon = "🟠"
        else:
            bg_color = "rgba(100, 116, 139, 0.15)"
            border_color = "#64748B"
            text_color = "#CBD5E1"
            icon = "⚪"
        
        # Hata kartı
        st.markdown(f"""
        <div style='background: {bg_color};
                    padding: 15px; border-radius: 10px;
                    border-left: 4px solid {border_color}; margin-bottom: 10px;'>
            <div style='display: flex; justify-content: space-between; align-items: center;'>
                <div>
                    <h3 style='color: {text_color}; margin: 0 0 5px 0; font-size: 14px;'>
                        {icon} <strong>{err.get('module', 'Bilinmeyen Modül')}</strong>
                    </h3>
                    <p style='color: #E5E7EB; margin: 5px 0; font-size: 13px;'>
                        {err['message']}
                    </p>
                    <small style='color: #9CA3AF; font-size: 11px;'>
                        🕒 {err.get('timestamp', datetime.now().strftime('%d.%m.%Y %H:%M:%S'))}
                    </small>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        # Teknik detaylar (expander)
        with st.expander(f"🔧 Teknik Detaylar #{idx+1}", expanded=False):
            st.markdown(f"""
            <div style='background: rgba(0, 0, 0, 0.3);
                        padding: 10px; border-radius: 5px;
                        border: 1px solid rgba(255, 255, 255, 0.1);'>
                <p style='color: #9CA3AF; margin: 0 0 5px 0; font-size: 11px;'>
                    <strong>Modül:</strong> {err.get('module', 'N/A')}
                </p>
                <p style='color: #9CA3AF; margin: 0 0 5px 0; font-size: 11px;'>
                    <strong>Şiddet:</strong> {severity.upper()}
                </p>
                <p style='color: #9CA3AF; margin: 0 0 5px 0; font-size: 11px;'>
                    <strong>Zaman:</strong> {err.get('timestamp', 'N/A')}
                </p>
            </div>
            """, unsafe_allow_html=True)
            
            # Stacktrace (koduyla göster, kullanıcılara uygun)
            stacktrace = err.get('stacktrace', 'Detay yok')
            st.code(stacktrace, language='python', line_numbers=False)
            
            # Kullanıcı için aksiyon önerisi
            st.markdown("""
            <div style='background: rgba(59, 130, 246, 0.1);
                        padding: 10px; border-radius: 5px;
                        border-left: 3px solid #3B82F6; margin-top: 10px;'>
                <p style='color: #93C5FD; margin: 0; font-size: 12px;'>
                    💡 <strong>Öneri:</strong> Bu hata otomatik olarak teknik ekibimize iletildi. 
                    Gerekirse destek@yerimebak.ai adresinden iletişime geçebilirsiniz.
                </p>
            </div>
            """, unsafe_allow_html=True)
    
    # Özet bilgi
    st.markdown(f"""
    <div style='background: rgba(100, 116, 139, 0.1);
                padding: 10px; border-radius: 8px; margin-top: 15px;'>
        <p style='color: #94A3B8; margin: 0; font-size: 12px; text-align: center;'>
            ⚠️ Toplam <strong>{len(errors)}</strong> hata tespit edildi. 
            En kritik: <strong>{err.get('severity', 'medium').upper()}</strong>
        </p>
    </div>
    """, unsafe_allow_html=True)
