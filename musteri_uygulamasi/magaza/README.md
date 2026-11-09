# Play Console hazırlık dosyaları

Sıra: `kapali-test-plani.md` → `listeleme.md` → `veri-guvenligi.md` → `icerik-derecelendirme.md` → `hedef-kitle.md` → `uygulama-erisimi.md` → `ekran-goruntuleri.md`.

## Hazır olanlar (9 Kasım 2026)

- İmzalama/R8, uyarlanabilir YerimeBak ikonu, Android açılış ekranı, 512px mağaza ikonu.
- Kalıcı yükleme anahtarıyla imzalanmış AAB. Anahtar depo dışında ve yedekli (`C:\Users\alial\yerimebak-anahtarlar`, `E:\yerimebak-anahtarlar`); `key.properties` şifresi hiçbir belgeye yazılmaz. Play App Signing açılmalı.
- Canlı API (`https://api.yerimebak.com.tr`), yasal sayfalar ve `/app/config` canlıda. İmzalı yayın APK'sı canlı API ile emülatörde açılış/giriş/kayıt/yasal sayfa denemesinden geçti (035).
- Sekiz telefon ekran görüntüsü ve 1024×500 öne çıkan görsel: `ekran-goruntuleri.md`.

## Console'a yüklemeden önce

- Geliştirici hesabı (kurumsal ya da bireysel) açılmalı.
- Play ürünleri (`paket1`, `paket5`, `paket10`) oluşturulup etkinleştirilmeli; Play hizmet hesabı JSON'u Render ortam değişkenine eklenmeli.
- Canlıda inceleme hesabı açılıp yeterli kredi verilmeli; `uygulama-erisimi.md` içindeki köşeli alanlar gerçek bilgilerle doldurulmalı.
- Anketler fiilî davranışı beyan etmeli. Özellikle üçüncü taraf ilan WebView erişimini ve OpenRouter/model sağlayıcısı aktarımını saklamayın. Yasal/saklama metinlerini gerçek işletme düzeniyle eşleştirin.
- Kapalı test: en az 12 testçinin kesintisiz 14 günlük katılımı gerekir.

Hiçbir mağaza kaydı yayınlanmadı; testçilere mesaj gönderilmedi.
