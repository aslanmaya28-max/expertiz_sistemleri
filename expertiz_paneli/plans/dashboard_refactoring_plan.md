# Dashboard Refactoring Plan

## Kırmızı Çizgiler (Asla Bozulmayacak)

### 1. Fonksiyonel Koruma
- ✅ `MarketRadarService.calculateIntegratedValue()` - Birebir korunacak
- ✅ `ExpertizProvider` içindeki veri toplama mantığı - Birebir korunacak
- ✅ AI analiz fonksiyonları - Birebir korunacak
- ✅ Sadece çıktıları GlassCard widget'ları içinde gösterilecek

### 2. Rol Bazlı Yetki
- ✅ Admin Paneli: Tüm yönetim yetkileri, personel atama, rapor onaylama
- ✅ Personel Paneli: Görev yönetimi, expertiz akışı, profil
- ✅ Müşteri Paneli: Talep oluşturma, rapor görüntüleme, AI oto-analiz
- ✅ BaseScaffold UserRole enum - Role-based routing hatasız yönetmeli

### 3. Veri Akışı
- ✅ Personelin girdiği donanım verileri → MarketRadar'a
- ✅ Müşteri Dashboard'unda doğru görünmesi
- ✅ Tüm mevcut servisler ve provider'lar çalışmaya devam edecek

## Yeni Dosyalar Oluşturulacak

### 1. Admin Dashboard (`lib/admin/admin_dashboard.dart`)
- **Mantık Aynı**: Mevcut AdminPaneli tüm fonksiyonları koruyacak
- **Görsel Değişim**: Daha güçlü grafikler, neon istatistik kartları
- **Özellikler**:
  - GlassCard ile istatistik kartları
  - NeonButton ile aksiyon butonları
  - Mevcut tüm fonksiyonlar: Personel yönetimi, rapor yönetimi, finansal veriler
  - AdminStatsCard → GlassCardStatsCard (yeni widget)
  - AdminCharts → GlassCardCharts (yeni widget)

### 2. Personnel Dashboard (`lib/personnel/personnel_dashboard.dart`)
- **Görevler Aynı**: Mevcut PersonelPaneli tüm fonksiyonları koruyacak
- **Görsel Değişim**: İş odaklı, göz yormayan ama teknolojik listeler
- **Özellikler**:
  - GlassCard ile görev kartları
  - NeonButton ile görev başlatma butonları
  - Mevcut tüm fonksiyonlar: Dashboard, Görevler, Profil
  - _buildStatCard → GlassCardStatCard (yeni widget)
  - _buildGorevCard → GlassCardGorevCard (yeni widget)

### 3. Customer Dashboard (`lib/customer/customer_dashboard.dart`)
- **Raporlar Aynı**: Mevcut MusteriAnaSayfa tüm fonksiyonları koruyacak
- **Görsel Değişim**: "Günlük Kalite" - Elegant, teknolojik ve güven ver
- **Özellikler**:
  - GlassCard ile premium kartlar
  - NeonButton ile aksiyon butonları
  - Mevcut tüm fonksiyonlar: AI Oto-Analiz, Yeni Talep, Son İşlemler
  - _buildIslemCard → GlassCardIslemCard (yeni widget)

### 4. BaseScaffold Güncellemeleri (`lib/core/layout/base_scaffold.dart`)
- **UserRole enum** - Zaten tanımlı, korunacak
- **Role-based routing** - Zaten çalışıyor, korunacak
- **Sidebar** - Zaten oluşturuldu, korunacak

## Mevcut Dosyaların Durumu

### Oluşturulmuş Dosyalar (Korunacak)
- ✅ `lib/core/theme/futuristic_theme.dart`
- ✅ `lib/core/widgets/glass_card.dart`
- ✅ `lib/core/widgets/neon_button.dart`
- ✅ `lib/core/widgets/sidebar.dart`
- ✅ `lib/core/layout/base_scaffold.dart`
- ✅ `lib/auth/login_screen.dart`
- ✅ `lib/customer/customer_dashboard.dart` (Güncellenecek)
- ✅ `lib/main.dart`

### Mevcut Dashboard'lar (Referans Alınacak, Değiştirilmeyecek)
- 📋 `lib/screens/admin_paneli.dart` - Referans alınacak, değiştirilmeyecek
- 📋 `lib/screens/personel_paneli.dart` - Referans alınacak, değiştirilmeyecek
- 📋 `lib/screens/musteri_ana_sayfa.dart` - Referans alınacak, değiştirilmeyecek

## Uygulama Sırası

1. ✅ Admin Dashboard oluştur (`lib/admin/admin_dashboard.dart`)
2. ✅ Personnel Dashboard oluştur (`lib/personnel/personnel_dashboard.dart`)
3. ✅ Customer Dashboard güncelle (`lib/customer/customer_dashboard.dart`)
4. ✅ Flutter analyze ve doğrulama

## Önemli Notlar

- **Mevcut dosyalar SİLİNMEYECEK** - Yeni dosyalar oluşturulacak
- **Eski dosyalar referans olarak kalacak** - Gerekirse geri dönüş mümkün
- **Tüm servisler ve provider'lar korunacak** - Sadece import'lar güncellenecek
- **Fonksiyonellık KORUNACAK** - Sadece görsel yapı güncellenecek
