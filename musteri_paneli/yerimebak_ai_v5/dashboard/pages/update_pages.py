# -*- coding: utf-8 -*-
"""
Tüm sayfa dosyalarını Türkçe başlık ve CSS ile güncelle
"""
import os

pages = {
    'database.py': {
        'title': 'Veritabanı Yönetimi',
        'icon': '🗄️',
        'page_title': 'Veritabanı Yönetimi'
    },
    'errors.py': {
        'title': 'Hata Takibi',
        'icon': '❌',
        'page_title': 'Hata Takibi'
    },
    'listings.py': {
        'title': 'İlan Yönetimi',
        'icon': '🚗',
        'page_title': 'İlan Yönetimi'
    },
    'live_feed.py': {
        'title': 'Canlı Akış',
        'icon': '⚡',
        'page_title': 'Canlı Akış'
    },
    'overview.py': {
        'title': 'Genel Bakış',
        'icon': '📁',
        'page_title': 'Genel Bakış'
    },
    'system.py': {
        'title': 'Sistem Durumu',
        'icon': '⚙️',
        'page_title': 'Sistem Durumu'
    },
    'vehicle_search.py': {
        'title': 'Araç Arama',
        'icon': '🔍',
        'page_title': 'Araç Arama'
    },
    'worker.py': {
        'title': 'İşçi Yönetimi',
        'icon': '👷',
        'page_title': 'İşçi Yönetimi'
    }
}

CSS = """
<style>
.stRadio > label {
    color: #F59E0B !important;
    font-size: 14px;
    font-weight: 500;
    transition: color 0.2s ease;
}
.stRadio > label:hover {
    color: #FBBF24 !important;
}
.stRadio > label[data-selected="true"] {
    color: #FBBF24 !important;
    font-weight: 700;
}
</style>
"""

for filename, info in pages.items():
    filepath = f'yerimebak_ai_v5/dashboard/pages/{filename}'
    
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if not content.strip() or len(content.strip()) < 50:
            icon = info['icon']
            title = info['title']
            page_title = info['page_title']
            
            new_content = f'''import streamlit as st

st.set_page_config(
    page_title="{page_title} | YERİMEBAK AI",
    page_icon="{icon}",
    layout="wide"
)

st.markdown("""
{CSS}
""", unsafe_allow_html=True)

st.title("{icon} {title}")

st.info("🚧 Bu sayfa yakında eklenecek...")
'''
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            print(f"✅ {filename} güncellendi")
        else:
            print(f"⚠️ {filename} dolu, atlanıyor")
    else:
        print(f"❌ {filename} bulunamadı")

print("\n✨ Tamamlandı!")