#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Streamlit Cache Temizleyici
Bu script Streamlit cache'ini temizler ve yeniden başlatır.
"""

import os
import shutil
import sys

def clear_streamlit_cache():
    """Streamlit cache dizinlerini temizle"""
    
    # Streamlit cache dizinleri
    cache_dirs = []
    
    # Windows için
    if os.name == 'nt':
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            cache_dirs.extend([
                os.path.join(appdata, 'streamlit'),
                os.path.join(os.environ.get('LOCALAPPDATA', ''), 'streamlit')
            ])
    
    # Tüm cache dizinlerini temizle
    cleared = False
    for cache_dir in cache_dirs:
        if os.path.exists(cache_dir):
            try:
                print(f"🗑️  Temizleniyor: {cache_dir}")
                shutil.rmtree(cache_dir)
                cleared = True
                print(f"✅ Temizlendi: {cache_dir}")
            except Exception as e:
                print(f"⚠️  Hata: {e}")
    
    if cleared:
        print("\n✅ Streamlit cache temizlendi!")
        print("🔄 Lütfen Streamlit'i yeniden başlatın:")
        print("   streamlit run yerimebak_ai_v5/dashboard/app_v2.py")
    else:
        print("\n⚠️  Cache dizini bulunamadı veya zaten temiz.")
        print("🔄 Lütfen Streamlit'i yeniden başlatın:")
        print("   streamlit run yerimebak_ai_v5/dashboard/app_v2.py")

if __name__ == "__main__":
    print("=" * 60)
    print("🧹 Streamlit Cache Temizleyici")
    print("=" * 60)
    clear_streamlit_cache()
