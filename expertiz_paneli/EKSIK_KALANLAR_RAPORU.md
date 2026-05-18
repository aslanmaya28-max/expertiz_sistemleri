# EKSİK KALANLAR RAPORU — SADECE TAMAMLANMAMIŞ SİSTEMLER
**Tarih:** 14 Mayıs 2026

---

## 1. AUTH / ROL

| # | Eksik | Şiddet | Detay |
|---|-------|--------|-------|
| 1.1 | **Rol isim karmaşası** | 🟢 DÜŞÜK | `UserProvider`'da hem `isFieldStaff`/`isPersonel` (legacy), hem `isCustomer`/`isMusteri` (legacy) getter'ları paralel var. Legacy olanlar (`isPersonel`, `isMusteri`) temizlenmeli. |

---

## 2. ADMIN PANEL

| # | Eksik | Şiddet | Detay |
|---|-------|--------|-------|
| 2.1 | **Personel pasife alma → açık görev akışı** | 🟡 ORTA | `deactivatePersonel()` metodu var ama pasife alınan personelin açık görevleri için uyarı/yeniden atama akışı yok. |
| 2.2 | **Finansal veri çift kaynak** | 🟡 ORTA | Dashboard truth layer RPC'si ile `FinanceService().getFinansalOzet()` paralel çalışıyor. Tek kaynağa indirgenmeli. |
| 2.3 | **Ayarlar tab'ı boş** | 🟢 DÜŞÜK | `const Text('Ayarlar')` placeholder. |
| 2.4 | **Dashboard stat kartları kaynağı net değil** | 🟢 DÜŞÜK | `AdminProvider.loadTalepler()` → `TalepService.getTalepler()` Supabase'den mi local'den mi çekiyor belli değil. |
| 2.5 | **Personel atama dialog hata yönetimi** | 🟢 DÜŞÜK | `atananPersonelGuncelle()` başarısız olursa dialog kapanıyor ama hata mesajı gösterilmiyor. |

---

## 3. MÜŞTERİ PANEL

| # | Eksik | Şiddet | Detay |
|---|-------|--------|-------|
| 3.1 | **Favori araç/liste mekanizması** | 🟢 DÜŞÜK | `is_favorite` yaklaşımından bahsedilmiş ama kodda favori mekanizması yok. |
| 3.2 | **Token localStorage'da tutuluyor** | 🟢 DÜŞÜK | httpOnly cookie veya daha güvenli session modeli yok. |
| 3.3 | **Mesajlar sayfası placeholder** | 🟢 DÜŞÜK | Hızlı İşlemler'de "Mesajlar" butonu `() {}` boş callback. |
| 3.4 | **Raporlarım yanlış yönlendirme** | 🟢 DÜŞÜK | "Raporlarım" butonu rapor listesine değil `ReportUploadScreen`'e yönlendiriyor. |

---

## 4. AI / ANALİZ

| # | Eksik | Şiddet | Detay |
|---|-------|--------|-------|
| 4.1 | **AIEngineService mock veri** | 🔴 KRİTİK | `bazFiyat = 850000.0` sabit, `mekanikPuan = 85.0`/`kozmetikPuan = 90.0` mock, `aylikEnflasyon = 0.035` sabit. Gerçek Supabase verisi çekilmiyor. |
| 4.2 | **AIEngineService Future.delayed** | 🟡 ORTA | `analyzeReport()` içinde `await Future.delayed(Duration(milliseconds: 1500))` — simüle edilmiş AI işlem süresi. |
| 4.3 | **AIAnalizService legacy metod** | 🟡 ORTA | `analizEt()` (eski adım tabanlı) ile `analizEtVeKaydet()` (GLM-4.7 yeni) paralel var. Eski metod temizlenmeli. |
| 4.4 | **GLM-4.7 API Key güvenli depolama** | 🟡 ORTA | `setApiKey()` ile runtime'da ayarlanıyor. Environment variable veya Supabase Vault kullanılmıyor. |
| 4.5 | **MarketRadarService test verisi** | 🟡 ORTA | Canlı 4000 araç verisiyle test raporu çıkarılmamış. |
| 4.6 | **%3 alt fiyat fallback testi** | 🟢 DÜŞÜK | Sadece "referans bulunamadı" halinde devreye girdiği canlı testle kanıtlanmamış. |
| 4.7 | **Vision Engine Python entegrasyonu** | 🟢 DÜŞÜK | Python servisi mevcut ama Flutter ile REST API veya doğrudan çağrı bağlantısı net değil. |

---

## 5. REPO / TEKNİK BORÇ

| # | Eksik | Şiddet | Detay |
|---|-------|--------|-------|
| 5.1 | **yerimebak_sistemleri commitlenmemiş** | 🟡 ORTA | Ayrı repo, cache temizlenmiş ama kod değişiklikleri commitlenmemiş. |
| 5.2 | **frontend/, chrome-extension/ untracked** | 🟡 ORTA | Sistemin parçası ama git'e eklenmemiş. |
| 5.3 | **Test coverage çok düşük** | 🟡 ORTA | Sadece 3 test dosyası var. Auth, admin, customer, AI servisleri için test yok. |
| 5.4 | **Eski debug scriptleri** | 🟢 DÜŞÜK | `scratch/` dizininde `fix_opacity.ps1`, `market_sniper.py`, `update_function.bat` gibi geçici scriptler. |
| 5.5 | **Migration dosyası yanlış yerde** | 🟢 DÜŞÜK | `supabase_migration_add_status.sql` kök dizinde, `supabase/migrations/` içine taşınmamış. |
| 5.6 | **Kök dizinde AlertDialog( dosyası** | 🟢 DÜŞÜK | Yanlışlıkla oluşturulmuş dosya, silinmeli. |

---

## ÖZET: KRİTİKLİK DAĞILIMI

| Şiddet | Adet | Açıklama |
|--------|------|----------|
| 🔴 KRİTİK | 1 | AIEngineService mock veri (üretimde çalışmaz) |
| 🟡 ORTA | 8 | Pasife alma akışı, finans çift kaynak, Future.delayed, legacy metod, API Key, test verisi, repo commit, test coverage |
| 🟢 DÜŞÜK | 12 | Rol getter, Ayarlar tab, favori, token güvenlik, mesajlar, yönlendirme, fallback test, Python entegrasyon, debug scriptler, migration yeri, AlertDialog dosyası |

**Toplam eksik: 21 madde**
