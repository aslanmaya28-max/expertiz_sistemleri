import streamlit as st

def render_analytics_cards(metrics: dict):
    """Türkçe pazar analizi metrik kartları"""
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            label="💰 Ortalama Fiyat", 
            value=f"{metrics.get('avg_price', 0):,.0f} ₺",
            delta="Pazar ortalaması",
            help="Tüm kaynaklardaki ortalama araç fiyatı"
        )
    with col2:
        st.metric(
            label="📊 Medyan Fiyat", 
            value=f"{metrics.get('median_price', 0):,.0f} ₺",
            delta="Orta değer",
            help="Fiyatların medyan değeri"
        )
    with col3:
        st.metric(
            label="📈 Volatilite", 
            value=f"%{metrics.get('volatility', 0):.1f}",
            delta_color="inverse",
            help="Fiyat dalgalanması (düşük = stabil)"
        )
    with col4:
        st.metric(
            label="⚡ Likidite Skoru", 
            value=f"{metrics.get('liquidity_score', 0)}/100",
            help="Pazar likidite skoru (yüksek = hızlı satış)"
        )

def render_system_kpis(stats: dict):
    """Türkçe sistem metrik kartları"""
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            label="🚗 Toplam İlan", 
            value=f"{stats.get('total_listings', 0):,.0f}",
            delta="Veritabanındaki toplam ilan"
        )
    with col2:
        delta_24h = stats.get('listings_24h', 0)
        st.metric(
            label="🕐 Son 24 Saat", 
            value=f"{delta_24h:,.0f}",
            delta=f"+{delta_24h:,.0f}" if delta_24h > 0 else "0",
            help="Son 24 saatte eklenen yeni ilan"
        )
    with col3:
        st.metric(
            label="💾 DB Boyutu", 
            value=f"{stats.get('db_size_mb', 0)} MB",
            help="Veritabanı boyutu"
        )
    with col4:
        # Gerçek cache hit oranı hesapla - FIXED v2.1
        cache_hits = stats.get('cache_hits', 0)
        cache_total = stats.get('cache_total', 0)
        cache_hit_rate = (cache_hits / cache_total * 100) if cache_total > 0 else 0.0
        
        # Delta mesajını dinamik yap
        delta_msg = "Yüksek performans" if cache_hit_rate >= 90 else "İyileştirme gerekli" if cache_hit_rate >= 70 else "Düşük performans"
        delta_color = "normal" if cache_hit_rate >= 90 else "inverse"
        
        st.metric(
            label="🎯 Cache Hit",
            value=f"{cache_hit_rate:.1f}%",
            delta=delta_msg,
            delta_color=delta_color,
            help=f"Cache hit oranı: {cache_hits:,}/{cache_total:,} (yüksek = hızlı)"
        )

def render_market_kpis(metrics: dict):
    """Pazar fırsat metrik kartları"""
    col1, col2, col3, col4, col5, col6 = st.columns(6)
    
    with col1:
        st.metric(
            label="🔥 Fırsatlar", 
            value=f"{metrics.get('opportunities', 0)}",
            delta="İyi fiyatlı araç",
            help="Pazar ortalamasının altındaki araçlar"
        )
    with col2:
        st.metric(
            label="⭐ Premium", 
            value=f"{metrics.get('premium', 0)}",
            delta="Yüksek fiyatlı",
            help="Pazar ortalamasının üzerindeki araçlar"
        )
    with col3:
        st.metric(
            label="📊 Fiyat Trendi", 
            value=f"%{metrics.get('price_trend', 0):.1f}",
            delta="Artış" if metrics.get('price_trend', 0) > 0 else "Düşüş",
            delta_color="normal" if metrics.get('price_trend', 0) > 0 else "inverse",
            help="Son 7 günlük fiyat trendi"
        )
    with col4:
        st.metric(
            label="⚡ Aktif Worker", 
            value=f"{metrics.get('active_workers', 3)}/{metrics.get('total_workers', 3)}",
            delta="Çalışıyor" if metrics.get('active_workers', 3) > 0 else "Durduruldu",
            help="Aktif scraper worker sayısı"
        )
    with col5:
        st.metric(
            label="📱 Güncel İlan", 
            value=f"%{metrics.get('fresh_listing_rate', 0):.1f}",
            delta="Son 3 gün",
            help="Son 3 günde eklenen ilan oranı"
        )
    with col6:
        st.metric(
            label="🎯 Başarı", 
            value=f"%{metrics.get('success_rate', 92.5):.1f}",
            delta="Yüksek" if metrics.get('success_rate', 92.5) >= 90 else "Normal",
            help="Scraping başarı oranı"
        )