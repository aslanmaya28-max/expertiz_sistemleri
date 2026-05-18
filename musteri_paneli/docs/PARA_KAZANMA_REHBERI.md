# 💰 YerimeBak AI — Para Kazanma Rehberi & Eksiklik Analizi

**Tarih:** 23 Nisan 2026  
**Durum:** Sistem altyapısı hazır, ticarileşme için kritik eksiklikler mevcut

---

## 📊 MEVCUT DURUM ANALİZİ

### ✅ Çalışan Altyapı
| Bileşen | Durum | Açıklama |
|---------|-------|----------|
| Docker Altyapısı | ✅ Çalışıyor | 5 container aktif (app, dashboard, postgres, redis, workers) |
| Scraper'lar | ✅ Çalışıyor | Arabam (349 ilan), Borusan (12 ilan) çekiyor |
| AI Motoru | ✅ Çalışıyor | OpenRouter API aktif, analiz üretiyor |
| Dashboard | ✅ Çalışıyor | Streamlit tabanlı, port 8501 |
| Kredi Sistemi | ✅ Kodlandı | 1/5/10 kredi paketleri tanımlı |
| Kayıt/Giriş | ✅ Kodlandı | WhatsApp OTP tabanlı kimlik doğrulama |
| Chrome Extension | ✅ Kodlandı | Sahibinden.com'dan analiz tetikleme |

### ❌ KRİTİK EKSİKLİKLER (Para Kazanmayı Engelleyen)

| # | Eksiklik | Öncelik | Tahmini Maliyet | Etki |
|---|----------|---------|-----------------|------|
| 1 | **Online Ödeme Entegrasyonu** | 🔴 P0 | 0 TL (iyzico) | Müşteri kendi kendine ödeme yapamaz → GELİR = 0 |
| 2 | **SMS Provider Aktif Değil** | 🔴 P0 | ~500 TL/ay (Netgsm) | WhatsApp OTP çalışmaz → KAYIT = 0 |
| 3 | **Sahibinden Scraper Yok** | 🟡 P1 | 0 TL | En büyük ikinci el pazarı eksik |
| 4 | **Landing Page / Pazarlama** | 🟡 P1 | Domain: 100 TL/yıl | Müşteri bulma kanalı yok |
| 5 | **WhatsApp Bot Entegrasyonu** | 🟡 P1 | Meta API ücretsiz | En büyük dağıtım kanalı kullanılmıyor |
| 6 | **Hukuki Altyapı** | 🟡 P1 | ~2000 TL | KVKK aydınlatma, kullanım şartları |
| 7 | **Otomatik Fırsat Bildirimi** | 🟢 P2 | 0 TL | Kullanıcı bağlılığını artırır |

---

## 🚀 PARA KAZANMA STRATEJİSİ — 3 AŞAMALI PLAN

### ══════════════════════════════════════════
### AŞAMA 1: "İlk Para" (1-2 Hafta)
### Hedef: İlk 10 müşteri, İlk 1000 TL gelir
### ══════════════════════════════════════════

#### Adım 1.1: iyzico Online Ödeme Entegrasyonu
**Neden:** Manuel havale/EFT ile müşteri kaybı %80'dir. İnsanlar anında almak ister.
**Ne Yapılacak:**
- iyzico hesabı aç (ücretsiz, %2.9 + 0.45 TL komisyon)
- iyzico JS/REST API entegrasyonu yap
- Kredi satın alma → iyzico checkout → otomatik kredi yüklemesi
- **Tahmini süre:** 2-3 gün kodlama

**Teknik Detay:**
```
Kullanıcı "Popüler Paket" butonuna basar
  → iyzico payment form açılır (iframe/popup)
  → Ödeme başarılı → webhook tetiklenir
  → Billing service krediyi otomatik ekler
  → SMS/WhatsApp ile onay mesajı
```

#### Adım 1.2: Netgsm SMS Aktifleştirme
**Neden:** OTP doğrulama olmadan kayıt olmaz.
**Ne Yapılacak:**
- Netgsm.com'dan hesap aç (aylık ~500 TL paket)
- `.env` dosyasına ekle:
  ```
  SMS_PROVIDER=netgsm
  NETGSM_API_KEY=sizin-anahtariniz
  NETGSM_HEADER=YERIMEBAK
  ```
- Container'ı yeniden başlat

#### Adım 1.3: Galeri Sektörüne Doğrudan Satış
**Neden:** En hızlı para, B2B müşterilerden gelir.
**Hedef Kitle:** 2. el araç galerileri
**Satış Stratejisi:**
- Telefonla veya yüz yüze git
- Demo yap: "Bir ilanın analizini yapayım" de
- İlk 3 analiz ücretsiz (zaten kodda var)
- **Fiyatlandırma galeriler için:** Aylık 2000-5000 TL (sınırsız analiz)

**Galeri Satış Scripti:**
```
"Merhaba, ben YerimeBak AI'dan Ali. 
Araç ekspertizini yapay zeka ile yapıyoruz. 
İlk 3 analiz ücretsiz deneyin — sadece bir ilan linki gönderin yeter.
Boya, hasar, piyasa fiyatı, kar marjı analizi 30 saniyede hazır."
```

---

### ══════════════════════════════════════════
### AŞAMA 2: "Büyüme" (2-4 Hafta)
### Hedef: 50 müşteri, 10.000 TL/ay gelir
### ══════════════════════════════════════════

#### Adım 2.1: WhatsApp Bot
**Neden:** Türkiye'de herkes WhatsApp kullanır. Uygulama indirme engeli kalkar.
**Neden Önemli:** Bir araç galericisi linki WhatsApp'tan gönderir → analiz geri gelir → kredi düşer.
**Ne Yapılacak:**
- Meta Business API'den WhatsApp Business hesabı aç
- Webhook endpoint'i yaz (FastAPI'ye ekle)
- `sahibinden.com/ilan/...` linki geldiğinde analiz tetikle
- Sonuçları WhatsApp mesajı olarak geri gönder

**Kullanıcı Akışı:**
```
Kullanıcı WhatsApp'tan → "Merhaba" yazar
Bot → "Hoş geldiniz! Araç linkini gönderin, analiz edelim." 
Kullanıcı → "sahibinden.com/ilan/..." gönderir
Bot → "Analiz başladı... 30 saniye içinde hazır."
Bot → [Detaylı analiz raporu gönderir]
Bot → "Kalan krediniz: 4. Daha fazla analiz için tıklayın."
```

#### Adım 2.2: Sahibinden Scraper
**Neden:** Arabam.com tek başına yeterli değil. Sahibinden Türkiye'nin en büyük 2. el pazarı.
**Ne Yapılacak:**
- Playwright tabanlı scraper (mevcut altyapıda zaten var)
- Kategori sayfalarını tara
- Fiyat/lokasyon/yıl/marka/model çek
- Mevcut `listings` tablosuna kaydet

#### Adım 2.3: Sosyal Medya Pazarlama
**Kanallar:**
- Instagram Reels: "Bu arabayı alınca ne kadar kazanırız?" formatı
- YouTube Shorts: Araç analiz videoları
- TikTok: Hızlı araç inceleme
- LinkedIn: Galeri sahiplerine B2B satış

**İçerik Fikirleri:**
```
1. "2024 Golf'i 800K'ya aldık, 1 yıl sonra ne oldu?"
2. "Bu araç %15 piyasanın altında — neden?"
3. "Galerici bunu bilmiyor ama AI biliyor"
4. "5 araç al-sat rekoru ve AI nasıl buldu"
```

---

### ══════════════════════════════════════════
### AŞAMA 3: "Ölçekleme" (1-3 Ay)
### Hedef: 200+ müşteri, 50.000+ TL/ay gelir
### ══════════════════════════════════════════

#### Adım 3.1: API Satışı (B2B)
- Galeri yazılımlarına (otoBYS vb.) API entegrasyonu
- Per-query pricing: 50-75 TL/sorgu
- Aylık minimum garanti paketleri

#### Adım 3.2: Premium Özellikler
| Özellik | Fiyat | Açıklama |
|---------|-------|----------|
| Toplu Analiz | +500 TL | Excel'den 50 araç linki yükle |
| Fırsat Alarmı | +300 TL/ay | Kriterlere uygun araç anında WhatsApp |
| Portföy Takip | +200 TL/ay | "Aldığım araçlar ne kadar etti?" |
| Beyaz Etiket | +2000 TL/ay | Galeri kendi logosuyla satış |

#### Adım 3.3: Rakip Analizi ve Fiyatlandırma Optimizasyonu
| Rakip | Model | Fiyat |
|-------|-------|-------|
| TÜV Türkiye | Per rapor | 300-500 TL |
| Otopratik | Per rapor | 200-400 TL |
| KBB Turkey | Abonelik | 500-2000 TL/ay |
| **YerimeBak (Hedef)** | Kredi | 75-100 TL/sorgu |

**Rekabet Avantajımız:** AI tabanlı, anında sonuç, WhatsApp entegrasyonu, piyasa karşılaştırma.

---

## 💸 GELİR MODELİ ÖZETİ

### Minimum Gelir Tahmini (Konservatif)
```
Ay 1: 10 müşteri × 5 kredi × 80 TL = 4.000 TL
Ay 2: 30 müşteri × 5 kredi × 80 TL = 12.000 TL
Ay 3: 80 müşteri × 5 kredi × 80 TL = 32.000 TL
Ay 6: 200 müşteri × 5 kredi × 80 TL = 80.000 TL
```

### Maliyetler
```
Sunucu (VDS):           500-1.000 TL/ay
Netgsm SMS:             500 TL/ay
OpenRouter AI:          200-1.000 TL/ay
Domain + SSL:           100 TL/yıl
Toplam:                 ~1.500-2.500 TL/ay
```

### Net Kar
```
Ay 1: 4.000 - 2.500 = 1.500 TL
Ay 3: 32.000 - 2.500 = 29.500 TL
Ay 6: 80.000 - 3.000 = 77.000 TL
```

---

## 🔧 HEMEN YAPILACAKLAR (Öncelik Sırası)

### Bu Hafta (Hafta 1)
- [ ] **iyzico hesabı aç** → API key al
- [ ] **Netgsm hesabı aç** → SMS_PROVIDER=netgsm yapılandır
- [ ] **Manuel galericileri ara** → 5 galeriye demo teklif et
- [ ] **Instagram hesabı aç** → @yerimebak.ai

### Gelecek Hafta (Hafta 2)
- [ ] **iyzico ödeme entegrasyonu** kodla
- [ ] **WhatsApp Business** hesabı aç
- [ ] **Landing page** tasarla (yerimebak.com)
- [ ] İlk 3 müşteriyi manuel analiz yap

### Hafta 3-4
- [ ] **WhatsApp Bot** geliştir
- [ ] **Sahibinden scraper** ekle
- [ ] **Sosyal medya içerikleri** üret
- [ ] **KVKK aydınlatma metni** hazırla

---

## ⚠️ RİSKLER VE ÖNERİLER

| Risk | Etki | Çözüm |
|------|------|-------|
| Sahibinden bot koruması | Scraper engellenebilir | Playwright stealth + proxy rotasyonu |
| iyzico hesap onayı | 1-2 hafta sürebilir | Hesap açmayı hemen başlat |
| Galerci güveni | Yeni bir araca güvenmezler | Ücretsiz demo ile kanıtla |
| AI maliyeti | OpenRouter token tüketimi | Sonuçları cache'le, aynı araç için tekrar sorma |
| Hukuki risk | KVKK, tüketici hakları | Hukuk danışmanlığı al |

---

## 📞 HEMEN BAŞLANGIÇ İÇİN

### Şu an yapabileceğin 3 şey:
1. **iyzico.com** → "Hesap Aç" → Bireysel/Şahıs firması → API key al
2. **netgsm.com** → Kayıt ol → SMS paketi al → API key al  
3. **5 tane araç galerisini ara** → "Ücretsiz AI ekspertiz yapıyorum" de → Demo yap

### En hızlı para:
**Manuel analiz satışı.** Sistemi kullan, galericilere birebir sat:
- Galeriye git → "Arabalarınızı AI ile analiz edeyim"
- Her araç için 100 TL
- 10 araç × 100 TL = 1.000 TL (ilk gün)
- Beğenirlerse → aylık paket sat (2.000-5.000 TL)

---

*Bu doküman canlıdır. Gelişmelere göre güncellenecektir.*