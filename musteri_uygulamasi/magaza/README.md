# Play Console hazırlık dosyaları

Sıra: `kapali-test-plani.md` → `listeleme.md` → `veri-guvenligi.md` → `icerik-derecelendirme.md` → `hedef-kitle.md` → `uygulama-erisimi.md` → `ekran-goruntuleri.md`.

## Hazır olanlar

İmzalama/R8, uyarlanabilir YerimeBak ikonu, Android açılış ekranı, 512px mağaza ikonu ve sentetik rapor ekran taslakları. Yerel sunucuda bakiye/simülasyon satın alımı, rapor, PDF ve kalıcı tema denendi. Test hesabı sonunda 5 kredi ve 1 sentetik rapor içeriyor.

## Console'a yüklemeden önce

- Kalıcı yükleme anahtarınızı depo dışında üretin, Play App Signing kullanın ve anahtarı yedekleyin. Bu görevdeki AAB **geçici doğrulama anahtarıyla** derlendi; onu kalıcı yayın anahtarınız sanmayın. README komutuyla kendi anahtarınızla yeniden derleyin.
- Canlı API henüz kurulmadı. Üretim API, yasal sayfalar ve gerçek inceleme hesabı hazır olmalı. Yerel HTTP/Play simülasyonu Play'e yüklenmez.
- Gerçek Play ürünlerini etkinleştirin; inceleme hesabını doğrulayıp yeterli kredi verin. Mağaza erişim belgesindeki köşeli alanları gerçek bilgilerle doldurun.
- Anketler fiilî davranışı beyan etmeli. Özellikle üçüncü taraf ilan WebView erişimini ve OpenRouter/model sağlayıcısı aktarımını saklamayın. Yasal/saklama metinlerini gerçek işletme düzeniyle eşleştirin.
- Gerçek 12+ testçinin kesintisiz 14 günlük katılımı ve geri bildirimi bu kod teslimiyle tamamlanmış sayılmaz.

Hiçbir mağaza kaydı yayınlanmadı; testçilere mesaj gönderilmedi.
