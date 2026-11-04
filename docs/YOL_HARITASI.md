# YerimeBak yol haritası (4 Kasım 2026)

Karar: önce az parayla çalışan ve gelir getiren parça çıkar. **Mobil uygulamadaki kredili araç değerleme**
nakit akışını sağlar. Ekspertiz (yerinde inceleme), şirket kuruluşu ve PayTR bu gelirle kurulur.

## Aşama 1 — Sunucu (uygulama buna bağlanır)
- `degerleme-web-kaynak` dalı `main`'e birleşir (Render ve Vercel `main`'den yayınlar). Yalnız kullanıcı onayıyla.
- Supabase (PostgreSQL + dosya deposu) ve Render (API) kurulumu: `musteri_paneli/docs/CANLIYA_CIKIS.md`.
- `api.yerimebak.com.tr` DNS kaydı.
- Maliyet: Render Starter ~7 $/ay, Supabase başlangıçta ücretsiz, OpenRouter rapor başına ~0,03 $.

## Aşama 2 — Müşteri uygulaması (para akışı)
Yeni Flutter projesi `musteri_uygulamasi/`, önce Android. Paket adı `com.yerimebak.app` (Play'de yayınlandıktan sonra değişmez).
Admin/personel paneli (`expertiz_paneli/`) ayrı kalır; müşteri uygulamasına admin kodu girmez.

| Görev | İş | Bağımlılık |
|---|---|---|
| 019 | Sunucu: Google Play satın alma doğrulama, `/app/config` ayarları, hesap silme (API + site sayfası) | — |
| 020 | Uygulama iskeleti: giriş/kayıt, e-posta doğrulama, kredi bakiyesi, raporlarım, rapor detayı + PDF, hesap silme | 019 ile paralel |
| 021 | İlan okuma (paylaş menüsü + WebView + metin yapıştırma), analiz formu, analiz ve sonuç | 020 |
| 022 | Google Play ile kredi satışı (uygulama tarafı) | 019, 021 |
| 023 | Ekspertiz talep ekranı, sunucu ayarıyla **kapalı** başlar | 020 |
| 024 | Yayın hazırlığı: ikon, imza, mağaza metinleri, veri güvenliği formu notları | 021, 022 |

| 025 | Ekspertiz raporu fotoğrafından kaporta ve bulguları okuma (sunucu + web; uygulamaya sonra) | — |
| 026 | Kronik arızalarda kaynaklı masraf aralığı, kilometre ve kategori | 025'ten sonra (aynı dosya) |

**Rakip ve fiyat kararı (4 Kasım 2026):** UstamVar (iOS + Android, 1 analiz 39,99 TL) inceledi. Kullanıcı kararı: **fiyatta taviz yok**
(100 / 400 / 750 TL); raporumuz daha işlevsel. Rakibin iyi yanları entegre edilir: ekspertiz raporu fotoğrafı (025), kronik arıza
masraf/km/kategori (026); sonra: iki aracı karşılaştırma ("Hangisini alayım?"), model bazlı arıza rehberi sayfaları (SEO), iOS.
Mesaj: "Önce rapor, sonra gerçek ekspertiz" — rakip fiziksel ekspertizin yerini tutmadığını kendisi söylüyor.

Kurallar:
- Dijital ürün (analiz kredisi) uygulama içinde **yalnız Google Play Faturalandırma** ile satılır. Uygulama web ödeme sayfasına
  yönlendirmez, link vermez. Web'de alınan kredi uygulamada kullanılabilir (aynı hesap).
- Fiziksel hizmet (yerinde inceleme) Google Play dışı ödemeyle (PayTR) alınabilir.
- Uygulama rapor rakamlarını kendisi hesaplamaz; sunucunun döndürdüğünü web ile aynı kurallarla gösterir.
- Google Play kapalı testi: yeni kişisel geliştirici hesabında üretime çıkmadan önce **en az 12 test kullanıcısı, kesintisiz 14 gün**.
  Bu süre takvime eklenmeli; test kullanıcıları erken bulunmalı.
- Play komisyonu: yıllık ilk 1 milyon $ için %15. Uygulama içi kredi fiyatı buna göre belirlenir (kullanıcı kararı).
- Uygulama gelirinin vergisi (GVK 20/B istisnası ya da şahıs şirketi) mali müşavirle netleşir.

## Aşama 3 — Ekspertiz (ikinci gelir kapısı)
- **İş modeli (4 Kasım 2026):** saha incelemesi ve cihazlı ekspertizi faturalı, anlaşmalı **kurumsal ekspertiz firmaları** yapar (B2B);
  kendi saha personeli yok ya da yalnız İstanbul pilotunda. Para akışı **toplu satış**: müşteri hizmet bedeli + firma paketini YerimeBak'a öder,
  firma ekspertiz ücretini YerimeBak'a fatura eder. YerimeBak'ın farkı: uzaktaki müşteri için organizasyon (satıcıyla randevu, yapay zekâ
  raporu, beyanla karşılaştırma, tek ödeme), sonra vekaletle alım (araç doğrudan müşteri adına) ve kurumsal çekiciyle ile sevk.
  Personel paneli "firma kullanıcısı" olarak kullanılabilir. Açık sorular: toplu satışın KDV/fatura biçimi (mali müşavir), vekaletle alım için
  yetki belgesi (avukat), firmalarla sözleşme ve sorumluluk maddesi.
- Şahıs şirketi, mali müşavir, PayTR üye işyeri, e-Arşiv fatura, ETBİS kaydı.
- Yasal sayfalarda şirket bilgileri (Vercel `COMPANY_*` değişkenleri).
- Web ekspertiz akışının son testleri: ödeme, personel ataması, admin onayı. Talep formu hâlâ `/expertiz/requests/unpaid` kullanıyor; ödemeli akışa geçer.
- Uygulamada `expertiz_enabled` açılır, Firebase push bildirimleri eklenir.
- Personel paneli web'den ya da APK ile devreye girer.

## Bilinen eksikler
- Vercel'de `COMPANY_*` yok: yasal sayfalarda adres, vergi no, MERSİS "—" görünür.
- 3 PDF testi Linux'ta başarısız (örnek PDF Windows Arial ile üretildi), canlıyı etkilemez.
- Uygulamada push bildirimi yok (Aşama 3).
