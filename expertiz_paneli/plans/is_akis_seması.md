# YerimeBak Sistemleri - İş Akış Şeması

## 📊 Sistem Genel Bakış

Bu doküman, YerimeBak Sistemleri'nin tam iş akışını ve kullanıcı rolleri arasındaki etkileşimleri gösterir.

---

## 🔄 Ana İş Akışı

```mermaid
graph TD
    Start[Uygulama Başlat] --> Splash[Splash Screen]
    Splash --> LoginCheck{Oturum Açık mı?}
    
    LoginCheck -->|Evet| RoleCheck{Kullanıcı Rolü}
    LoginCheck -->|Hayır| LoginScreen[Giriş Ekranı]
    
    LoginScreen --> LoginAction{Giriş Yap}
    LoginAction -->|Admin| AdminPanel[Admin Paneli]
    LoginAction -->|Personel/Teknisyen| PersonelPanel[Personel Paneli]
    LoginAction -->|Müşteri| MusteriPanel[Müşteri Paneli]
    
    RoleCheck -->|admin/yonetici| AdminPanel
    RoleCheck -->|teknisyen| PersonelPanel
    RoleCheck -->|user| MusteriPanel
    
    AdminPanel --> AdminFlow
    PersonelPanel --> PersonelFlow
    MusteriPanel --> MusteriFlow
```

---

## 👤 Müşteri İş Akışı

```mermaid
graph TD
    MusteriPanel[Müşteri Ana Sayfa] --> YeniTalep{Yeni Talep Oluştur?}
    
    YeniTalep -->|Evet| TalepEkrani[Yeni Talep Ekranı]
    YeniTalep -->|Hayır| Islemlerim[Son İşlemlerim]
    
    TalepEkrani --> Adim1[Adım 1: Araç Bilgileri]
    Adim1 --> Adim2[Adım 2: Lokasyon & Firma Seçimi]
    Adim2 --> Adim3[Adım 3: Ödeme]
    Adim3 --> TalepKaydet[Talep Kaydet]
    
    TalepKaydet --> TalepBekle[Talep Beklemede]
    TalepBekle --> TalepAta{Admin Personel Atadı mı?}
    
    TalepAta -->|Evet| TalepIncelemede[Talep İncelemede]
    TalepAta -->|Hayır| TalepBekle
    
    TalepIncelemede --> RaporHazir{Rapor Hazır mı?}
    RaporHazir -->|Evet| RaporGonder[Rapor Gönderildi]
    RaporHazir -->|Hayır| TalepIncelemede
    
    Islemlerim --> RaporGoruntule[Raporları Görüntüle]
    RaporGoruntule --> MusteriPanel
```

### Müşteri Akışı Detayları

**1. Giriş ve Ana Sayfa**
- Kullanıcı giriş yapar → [`MusteriAnaSayfa`](lib/screens/musteri_ana_sayfa.dart:6)
- Hoş geldiniz mesajı ve hızlı aksiyon kartları

**2. Yeni Talep Oluşturma**
- "Yeni Ekspertiz Talebi" butonuna tıklama
- [`YeniTalepEkrani`](lib/screens/talep_olustur_ekrani.dart:3) açılır
- 3 adımlı süreç:
  - **Adım 1:** Araç bilgileri (ilan linki veya manuel giriş)
  - **Adım 2:** Şehir ve kurumsal firma seçimi
  - **Adım 3:** Ödeme (hizmet bedeli + firma ücreti)

**3. Talep Durumları**
- Beklemede → İncelemede → Hazır → Gönderildi
- Müşteri taleplerini "Son İşlemlerim" bölümünden takip eder

---

## 👷 Personel İş Akışı

```mermaid
graph TD
    PersonelPanel[Personel Paneli] --> Dashboard[Dashboard]
    PersonelPanel --> Gorevler[Görevler]
    PersonelPanel --> Profil[Profil]
    
    Gorevler --> AtananGorevler[Atanan Görevler]
    Gorevler --> TamamlananGorevler[Tamamlanan Görevler]
    
    AtananGorevler --> GorevSec{Görev Seç}
    GorevSec --> GorevBaslat[Görevi Başlat]
    
    GorevBaslat --> ExpertizAkisi[Expertiz Akışı Başlat]
    ExpertizAkisi --> Adim1[Adım 1: Araç & Satıcı Bilgileri]
    
    Adim1 --> Adim1Valid{Validasyon}
    Adim1Valid -->|Geçti| Adim2[Adım 2: Dış Ekspertiz]
    Adim1Valid -->|Başarısız| Adim1
    
    Adim2 --> Adim2Valid{Validasyon}
    Adim2Valid -->|Geçti| Adim3[Adım 3: İç Ekspertiz]
    Adim2Valid -->|Başarısız| Adim2
    
    Adim3 --> Adim3Valid{Validasyon}
    Adim3Valid -->|Geçti| Adim4[Adım 4: Boya & Kaporta]
    Adim3Valid -->|Başarısız| Adim3
    
    Adim4 --> Adim4Valid{Validasyon}
    Adim4Valid -->|Geçti| Adim5[Adım 5: Kurumsal Ekspertiz]
    Adim4Valid -->|Başarısız| Adim4
    
    Adim5 --> Adim5Valid{Validasyon}
    Adim5Valid -->|Geçti| RaporTamamla[Raporu Tamamla]
    Adim5Valid -->|Başarısız| Adim5
    
    RaporTamamla --> AIAnaliz[AI Analizi Başlat]
    AIAnaliz --> RaporOnayBekliyor[Rapor Onay Bekliyor]
    RaporOnayBekliyor --> AdminOnay{Admin Onayı}
    
    AdminOnay -->|Onaylandı| RaporMusteriyeGonder[Rapor Müşteriye Gönderildi]
    AdminOnay -->|Reddedildi| Duzeltme[Düzeltme Gerekli]
    
    Duzeltme --> ExpertizAkisi
    RaporMusteriyeGonder --> TamamlananGorevler
```

### Personel Akışı Detayları

**1. Giriş ve Dashboard**
- Personel giriş yapar → [`PersonelPaneli`](lib/screens/personel_paneli.dart:49)
- Dashboard: Atanan görev sayısı, tamamlanan görev sayısı, toplam görev

**2. Görev Yönetimi**
- **Atanan Görevler:** Admin tarafından atanmış görevler
- **Tamamlanan Görevler:** Personel tarafından tamamlanan görevler

**3. Expertiz Akışı (5 Adım)**
- [`ExpertizBaslatSayfasi`](lib/screens/expertiz_akisi/expertiz_baslat_sayfasi.dart:12) üzerinden yönetilir
- **Adım 1:** [`Adim1Sayfasi`](lib/screens/expertiz_akisi/adim1_sayfasi.dart:1) - Araç ve satıcı bilgileri
- **Adım 2:** [`Adim2Sayfasi`](lib/screens/expertiz_akisi/adim2_sayfasi.dart:1) - Dış ekspertiz kontrolü
- **Adım 3:** [`Adim3Sayfasi`](lib/screens/expertiz_akisi/adim3_sayfasi.dart:1) - İç ekspertiz kontrolü
- **Adım 4:** [`Adim4Sayfasi`](lib/screens/expertiz_akisi/adim4_sayfasi.dart:1) - Boya ve kaporta kontrolü
- **Adım 5:** [`Adim5Sayfasi`](lib/screens/expertiz_akisi/adim5_sayfasi.dart:1) - Kurumsal ekspertiz

**4. AI Analiz Süreci**
- Rapor tamamlandıktan sonra AI analizi başlatılır
- AI sonuçları rapora eklenir
- Admin onayı beklenir

**5. Rapor Durumları**
- Personele Atandı → Expertiz İçinde → Onay Bekliyor → Tamamlandı/Reddedildi

---

## 👨‍💼 Admin İş Akışı

```mermaid
graph TD
    AdminPanel[Admin Paneli] --> Dashboard[Dashboard]
    AdminPanel --> AracYonetimi[Araç Yönetimi]
    AdminPanel --> PersonelYonetimi[Personel Yönetimi]
    AdminPanel --> MusteriYonetimi[Müşteri Yönetimi]
    AdminPanel --> Raporlar[Raporlar]
    AdminPanel --> Ayarlar[Ayarlar]
    
    Dashboard --> Istatistikler[İstatistikler]
    Dashboard --> AIAnalizleri[AI Analizleri]
    Dashboard --> AktifRaporlar[Aktif Raporlar]
    Dashboard --> HizliIslemler[Hızlı İşlemler]
    
    MusteriYonetimi --> GelenRaporlar[Gelen Raporlar]
    MusteriYonetimi --> GonderilecekRaporlar[Gönderilecek Raporlar]
    
    GelenRaporlar --> PersonelAta{Personel Ata}
    PersonelAta --> PersonelSecim[Personel Seç]
    PersonelSecim --> GorevAta[Görevi Ata]
    GorevAta --> Incelemede[İncelemede]
    
    Raporlar --> TamRaporlar[Tam Raporlar]
    Raporlar --> SahaRaporlari[Saha Raporları]
    Raporlar --> KurumsalRaporlar[Kurumsal Expertiz]
    Raporlar --> IcDisRaporlar[İç/Dış Expertiz]
    Raporlar --> BoyaKaportaRaporlari[Boya/Kaporta]
    
    TamRaporlar --> RaporIncele{Rapor İncele}
    RaporIncele --> AIDuzenle[AI Sonuçlarını Düzenle]
    RaporIncele --> MusteriyeGonder[Müşteriye Gönder ve Arşivle]
    
    AIDuzenle --> PuanDuzenle[Puan Düzenle]
    AIDuzenle --> OzetDuzenle[Özet Düzenle]
    PuanDuzenle --> MusteriyeGonder
    OzetDuzenle --> MusteriyeGonder
    
    PersonelYonetimi --> PersonelEkle[Personel Ekle]
    PersonelYonetimi --> PersonelDuzenle[Personel Düzenle]
    PersonelYonetimi --> PersonelSil[Personel Sil]
    PersonelYonetimi --> PersonelAktiflik[Personel Aktiflik Değiştir]
```

### Admin Akışı Detayları

**1. Dashboard**
- İstatistik kartları: Toplam Araç, Aktif Rapor, Personel, Müşteri
- Finansal istatistikler: Toplam Ciro, KDV, Personel Payı, Hakediş Borcu
- Son AI analizleri
- Aktif raporlar listesi
- Hızlı işlemler

**2. Araç Yönetimi**
- Araç listesi (gelen ve gönderilecek raporlar)
- Arama ve filtreleme
- Personel atama
- Rapor detayları

**3. Personel Yönetimi**
- Personel listesi (aktif/pasif)
- Personel ekleme/düzenleme/silme
- Bölge bazlı filtreleme
- [`PersonelBolgePaneli`](lib/screens/personel_bolge_sistemi.dart:1) entegrasyonu

**4. Müşteri Yönetimi**
- Gelen raporlar (müşteri talepleri)
- Gönderilecek raporlar (hazırlanmış raporlar)
- Personel atama
- Rapor gönderme

**5. Rapor Yönetimi**
- **Tam Raporlar:** 5 adımlı expertiz akışından gelen raporlar
- **Saha Raporları:** Saha personeli raporları
- **Kurumsal Expertiz:** Kurumsal müşteri raporları
- **İç/Dış Expertiz:** İç ve dış ekspertiz raporları
- **Boya/Kaporta:** Boya ve kaporta raporları

**6. AI Analiz İş Akışı**
- Rapor tamamlandıktan sonra AI analizi başlar
- AI sonuçları: Genel puan, Araç durumu, Motor/mekanik, Hasar durumu
- Admin AI sonuçlarını düzenleyebilir
- Müşteriye gönderme ve arşivleme

**7. Ayarlar**
- Tema ayarları (Aydınlık/Gece modu)
- Genel ayarlar (Bildirimler, Dil, Veri yedekleme)
- Güvenlik ayarları (Şifre değiştir, İki aşamalı doğrulama)
- Sistem bilgileri

---

## 🔐 Kimlik Doğrulama Akışı

```mermaid
graph TD
    LoginScreen[Giriş Ekranı] --> EmailSifre[E-posta ve Şifre Gir]
    EmailSifre --> AuthService[AuthService.login]
    
    AuthService --> AdminCheck{Admin mi?}
    AdminCheck -->|Evet| AdminPasswordCheck[Admin Şifre Kontrolü]
    AdminPasswordCheck -->|Başarılı| AdminSession[Admin Oturumu]
    AdminPasswordCheck -->|Başarısız| HataMesaji[Hata Mesajı]
    
    AdminCheck -->|Hayır| PersonelCheck{Personel mi?}
    PersonelCheck -->|Evet| PersonelPasswordCheck[Personel Şifre Kontrolü]
    PersonelPasswordCheck -->|Başarılı| PersonelSession[Personel Oturumu]
    PersonelPasswordCheck -->|Başarısız| HataMesaji
    
    PersonelCheck -->|Hayır| UserCheck{Kullanıcı mı?}
    UserCheck -->|Evet| UserPasswordCheck[Kullanıcı Şifre Kontrolü]
    UserPasswordCheck -->|Başarılı| UserSession[Kullanıcı Oturumu]
    UserPasswordCheck -->|Başarısız| HataMesaji
    
    UserCheck -->|Hayır| HataMesaji
    
    AdminSession --> AdminPanel
    PersonelSession --> PersonelPanel
    UserSession --> MusteriPanel
    
    HataMesaji --> LoginScreen
```

### Kimlik Doğrulama Detayları

**1. Varsayılan Kullanıcılar**
- **Admin:** admin@yerimebak.com / 123456
- **Personel:** ahmet@yerimebak.com / 123456, fatma@yerimebak.com / 123456

**2. Oturum Yönetimi**
- [`AuthService`](lib/services/auth_service.dart:4) ile yönetilir
- Oturum bilgileri SharedPreferences'te saklanır
- Otomatik giriş desteği

**3. Rol Bazlı Yönlendirme**
- **admin/yonetici:** [`AnaSayfa`](lib/screens/ana_sayfa.dart:1) → [`AdminPaneli`](lib/screens/admin_paneli.dart:96)
- **teknisyen:** [`PersonelAnaSayfa`](lib/screens/personel_ana_sayfa.dart:1) → [`PersonelPaneli`](lib/screens/personel_paneli.dart:49)
- **user:** [`MusteriAnaSayfa`](lib/screens/musteri_ana_sayfa.dart:6)

---

## 📊 Rapor Durumları ve Geçişleri

```mermaid
stateDiagram-v2
    [*] --> Beklemede: Talep Oluşturuldu
    Beklemede --> PersoneleAtandi: Admin Personel Atadı
    PersoneleAtandi --> Incelemede: Personel Görevi Başlattı
    Incelemede --> ExpertizAkisi: Expertiz Başlatıldı
    ExpertizAkisi --> OnayBekliyor: Expertiz Tamamlandı
    OnayBekliyor --> Tamamlandi: Admin Onayladı
    OnayBekliyor --> Reddedildi: Admin Reddetti
    Reddedildi --> ExpertizAkisi: Düzeltme Yapıldı
    Tamamlandi --> [*]: Müşteriye Gönderildi
```

### Rapor Durumları Açıklaması

| Durum | Açıklama | Sorumlu |
|-------|----------|---------|
| **Beklemede** | Müşteri tarafından talep oluşturuldu | Müşteri |
| **Personele Atandı** | Admin tarafından personele atandı | Admin |
| **İncelemede** | Personel görevi başlattı | Personel |
| **Expertiz İçinde** | 5 adımlı expertiz akışı devam ediyor | Personel |
| **Onay Bekliyor** | Expertiz tamamlandı, AI analizi yapıldı | Admin |
| **Tamamlandı** | Admin onayladı, müşteriye gönderildi | Admin |
| **Reddedildi** | Admin reddetti, düzeltme gerekli | Admin |

---

## 🤖 AI Analiz İş Akışı

```mermaid
graph TD
    ExpertizTamam[Expertiz Tamamlandı] --> FotoğrafYukle[Fotoğraflar Yükle]
    FotoğrafYukle --> AIAnaliz[AI Analiz Servisi]
    
    AIAnaliz --> FotografAnalizi[Fotoğraf Analizi]
    AIAnaliz --> HasarTespiti[Hasar Tespiti]
    AIAnaliz --> Degerleme[Değerleme]
    
    FotografAnalizi --> SkorHesapla[Skor Hesapla]
    HasarTespiti --> SkorHesapla
    Degerleme --> SkorHesapla
    
    SkorHesapla --> GenelPuan[Genel Puan]
    SkorHesapla --> AracDurumuPuan[Araç Durumu Puanı]
    SkorHesapla --> MotorMekanikPuan[Motor/Mekanik Puan]
    SkorHesapla --> HasarPuan[Hasar Puan]
    
    GenelPuan --> RaporOzeti[Rapor Özeti Oluştur]
    RaporOzeti --> Oneriler[Öneriler Oluştur]
    
    Oneriler --> AIAnalizSonucu[AI Analiz Sonucu]
    AIAnalizSonucu --> RaporEkle[Rapora Ekle]
    
    RaporEkle --> AdminOnay[Admin Onayı Bekliyor]
    
    AdminOnay --> AIDuzenle{AI Sonuçlarını Düzenle}
    AIDuzenle -->|Evet| PuanDuzenle[Puan Düzenle]
    AIDuzenle -->|Hayır| MusteriyeGonder[Müşteriye Gönder]
    
    PuanDuzenle --> OzetDuzenle[Özet Düzenle]
    OzetDuzenle --> MusteriyeGonder
```

### AI Analiz Detayları

**1. AI Analiz Bileşenleri**
- [`AIAnalizService`](lib/services/ai/ai_analiz_service.dart:1) - Ana analiz servisi
- [`AIFotografAnalizService`](lib/services/ai/ai_fotograf_analiz_service.dart:1) - Fotoğraf analizi
- [`AIOneriService`](lib/services/ai/ai_oneri_service.dart:1) - Öneri servisi
- [`AIPuanlamaService`](lib/services/ai/ai_puanlama_service.dart:1) - Puanlama servisi

**2. AI Skorları**
- **Genel Puan:** 0-100 arası
- **Araç Durumu Puanı:** Araç genel durumu
- **Motor/Mekanik Puanı:** Motor ve mekanik durum
- **Hasar Puanı:** Hasar durumu

**3. AI Önerileri**
- Kritik sorunlar
- Bakım önerileri
- Değerlendirme önerileri

**4. Admin Müdahalesi**
- AI sonuçlarını düzenleme
- Puanları manuel güncelleme
- Özetleri değiştirme

---

## 💰 Finansal İş Akışı

```mermaid
graph TD
    TalepOlustur[Talep Oluştur] --> Odeme[Ödeme]
    Odeme --> HizmetBedeli[Hizmet Bedeli]
    Odeme --> FirmaUcreti[Firma Ücreti]
    
    HizmetBedeli --> ToplamTutar[Toplam Tutar]
    FirmaUcreti --> ToplamTutar
    
    ToplamTutar --> OdemeBasarili[Ödeme Başarılı]
    OdemeBasarili --> TalepKayit[Talep Kayıt]
    
    RaporTamamlandi[Rapor Tamamlandı] --> FaturaOlustur[Fatura Oluştur]
    FaturaOlustur --> KDVHesapla[KDV Hesapla]
    
    KDVHesapla --> PersonelPayi[Personel Payı Hesapla]
    PersonelPayi --> HakedisBorcu[Hakediş Borcu]
    
    HakedisBorcu --> PersonelOdeme[Personel Ödeme]
    PersonelOdeme --> OdemeTamam[Ödeme Tamamlandı]
```

### Finansal Detaylar

**1. Ücretlendirme**
- **Hizmet Bedeli:** 6.500 TL (şirket hizmet bedeli)
- **Firma Ücreti:** Kurumsal firmaya göre değişir (3.000-4.500 TL)
- **Toplam Tutar:** Hizmet bedeli + Firma ücreti

**2. Finansal Hesaplamalar**
- **KDV:** %20
- **Personel Payı:** %25
- **Hakediş Borcu:** Personel ödenmemiş hak edişleri

**3. Finansal Servis**
- [`FinanceService`](lib/services/finance_service.dart:1) ile yönetilir
- Finansal özet raporları
- Ciro, KDV, personel payı, hakediş borcu hesaplamaları

---

## 📱 Ekran Geçişleri

### Müşteri Ekranları
1. **Login Screen** → MusteriAnaSayfa
2. **MusteriAnaSayfa** → YeniTalepEkrani
3. **YeniTalepEkrani** → MusteriAnaSayfa (talep oluşturulduktan sonra)

### Personel Ekranları
1. **Login Screen** → PersonelPaneli
2. **PersonelPaneli** → ExpertizBaslatSayfasi (görev başlat)
3. **ExpertizBaslatSayfasi** → Adim1-Adim5 (expertiz akışı)
4. **ExpertizBaslatSayfasi** → PersonelPaneli (görev tamamlandı)

### Admin Ekranları
1. **Login Screen** → AnaSayfa → AdminPaneli
2. **AdminPaneli** → PersonelBolgePaneli (personel yönetimi)
3. **AdminPaneli** → DetailedReportView (rapor detayı)
4. **AdminPaneli** → LoginScreen (çıkış)

---

## 🔗 Servis Entegrasyonları

### Ana Servisler
- **AuthService:** Kimlik doğrulama ve oturum yönetimi
- **PersonelService:** Personel yönetimi
- **RaporService:** Rapor yönetimi
- **TalepService:** Talep yönetimi
- **FinanceService:** Finansal işlemler
- **AI Analiz Servisleri:** AI analizi

### Veri Saklama
- **SharedPreferencesManager:** Yerel veri saklama
- Oturum bilgileri
- Kullanıcı verileri
- Personel verileri

---

## 📝 Özet

Bu YerimeBak Sistemleri, üç ana kullanıcı rolü (Müşteri, Personel, Admin) arasında koordineli bir iş akışı sağlar:

1. **Müşteri:** Araç ekspertiz talebi oluşturur ve ödeme yapar
2. **Admin:** Talebi inceleyip personele atar
3. **Personel:** 5 adımlı expertiz sürecini gerçekleştirir
4. **AI Analiz:** Raporu analiz eder ve puanlar
5. **Admin:** AI sonuçlarını inceleyip onaylar
6. **Müşteri:** Raporu alır

Sistem, Flutter tabanlı çoklu platform desteği sunar ve yerel veri saklama (SharedPreferences) kullanır.
