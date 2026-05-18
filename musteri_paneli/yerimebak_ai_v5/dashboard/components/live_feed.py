import streamlit as st
import html
import pandas as pd

def render_live_feed(latest_listings: pd.DataFrame):
    st.subheader("📡 Live Market Activity")
    
    if latest_listings.empty:
        st.write("Waiting for market activity...")
        return

    for _, row in latest_listings.head(10).iterrows():
        with st.container():
            # Görsel ve bilgileri yan yana göster
            col_img, col_info = st.columns([1, 5])
            
            with col_img:
                # Görsel URL'sini al ve validate et
                image_url = row.get('image_url', '')
                
                # Backend validasyon - favicon, logo, icon gibi URL'leri reddet
                is_valid_image = False
                if image_url and pd.notna(image_url) and image_url.strip():
                    url_lower = image_url.lower()
                    # Invalid keyword kontrolü
                    invalid_keywords = ['favicon', 'logo', 'icon', 'avatar', 'badge', 'banner', 'thumb', 'thumbnail']
                    has_invalid = any(kw in url_lower for kw in invalid_keywords)
                    # Minimum uzunluk kontrolü
                    is_long_enough = len(image_url) >= 50
                    # Araç fotoğrafı pattern kontrolü
                    has_valid_pattern = any(pattern in url_lower for pattern in [
                        '/ilanfotograflari/', '/images/', '/img/', 'arabam', 'cdn', 
                        'apollo', 'akamaized', 'picture', 'listing', 
                        'imvm', '/files/', 'image;s='
                    ])
                    
                    is_valid_image = not has_invalid and is_long_enough and has_valid_pattern
                
                if is_valid_image:
                    # Görseli göster
                    st.markdown(f"""
                    <a href="{row.get('url', '#')}" target="_blank">
                        <img src="{image_url}" 
                             style="width:100%; max-width:200px; height:auto; border-radius:8px; object-fit:cover;" 
                             alt="{row['brand']} {row['model']}"
                             onerror="this.style.display='none'">
                    </a>
                    """, unsafe_allow_html=True)
                else:
                    # Görsel yoksa veya invalidse ikon göster
                    st.markdown("""
                    <div style="text-align:center; padding:20px; background:#1e293b; border-radius:8px;">
                        <span style="font-size:48px;">🚗</span>
                    </div>
                    """, unsafe_allow_html=True)
            
            with col_info:
                # Kaynak ve detay bilgileri
                col1, col2 = st.columns([3, 2])
                
                with col1:
                    st.markdown(f"**{row['source'].upper()}** - {row['brand']} {row['model']} ({row['year']})")
                    st.caption(f"💰 {row['price']:,} TL | 📍 {row['km']:,} KM")
                    
                    # Yakıt ve vites bilgisi varsa
                    if 'fuel_type' in row and pd.notna(row['fuel_type']) and str(row['fuel_type']).lower() != 'standart':
                        st.caption(f"⛽ {row['fuel_type']} | ⚙️ {row.get('gear_type', 'Otomatik')}")
                
                with col2:
                    st.caption(f"🕒 {row['updated_at']}")
                    
                    # İlan linki
                    if 'url' in row and pd.notna(row['url']):
                        # 🔒 GÜVENLİK: XSS korumasi - URL'yi HTML escape et
                        safe_url = html.escape(str(row['url']))
                        st.markdown(f"<a href='{safe_url}' target='_blank' style='font-size:11px;'>🔗 İlanı Gör</a>", unsafe_allow_html=True)
            
            st.divider()
