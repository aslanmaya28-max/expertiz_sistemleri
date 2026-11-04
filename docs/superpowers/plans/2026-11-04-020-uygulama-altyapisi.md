# 020 — Android müşteri uygulaması altyapısı

**Amaç:** Mevcut sunucuya bağlanan, sade ve tasarımı değiştirilebilir müşteri uygulaması.
**Şartname:** Ana kökte `kopru/codex_icin/020-musteri-uygulamasi-iskelet.md`.
**Mimari:** http istemcisi + güvenli belirteç deposu; Riverpod oturum ve veri sağlayıcıları; go_router oturum/sürüm kapısı. Ekranlar hesaplama yapmaz, sunucunun raporunu bölüm bileşenleriyle gösterir. Material 3 tema değerleri tek dosyada.
**Sınırlar:** Yalnız Android, com.yerimebak.app; sunucu/site/admin kodu değiştirilmez. Ana sunucular ve ybdemo kullanılmaz. Kredi satışı ve analiz sonraki görevlerin yer tutucularıdır; web ödemesine bağlantı yok.

## Uygulama sırası
- [x] Projeyi oluştur, paketleri çözümle; Android kimliği, debug-only HTTP, yedek dışı belirteç, asgari izinleri ayarla.
- [x] API hata modeli, tek yenileme ve eşzamanlı istekler için tek refresh; ağ/zaman aşımı, 402/429, binary PDF. Önce testler, kırmızı sonucu, sonra uygulama.
- [x] Kullanıcı/config/rapor/sayfa modelleri; semantik sürüm karşılaştırması; repository'ler ve güvenli oturum yaşam döngüsü. Oturum testleri: açılış/giriş/kayıt/çıkış/gecikmiş yanıt/kalıcı oturum iptali.
- [x] Türkçe giriş, kayıt, şifre sıfırlama, ana ekran ve sayfalanan raporlar; e-posta doğrulama uyarısı.
- [x] Web ile aynı sıra/gizleme kurallarıyla rapor bölümleri; kimlikli PDF indirip geçici dosyadan aç. Boş/eski/tam sentetik rapor widget testleri.
- [x] Profil, şifre değiştirme, kredi geçmişi, hesap silme ve sürüm kapısı; hassas işlemlerde onay, veri/ekran ayrımı.
- [x] Flutter analyze ve tüm testler; mümkünse debug APK ve emülatör. JDK/AVD eksikse gerçek sonucu raporla; tahmini başarı iddiası yok.
- [x] README, AGENTS.md yapı/test satırı; sunucu eksiklerini Claude köprüsüne bildir; bağımsız inceleme ve Türkçe commit/teslim.

## İnceleme odağı
- 401 fırtınası tek refresh üretmeli; giriş isteği yenilemeye düşmemeli; çıkış sonrasında geciken yanıt oturumu canlandırmamalı.
- Sunucu rapor rakamları korunmalı, admin karar alanları web'deki gibi gizlenmeli, düşük güvenli model riskleri gösterilmemeli.
- Yeni oturum başka müşterinin rapor önbelleğini görmemeli; yenileme/ağ hatası kullanıcıya tekrar deneme sunmalı.
- Güncelleme kapısı doğrudan rota üzerinden atlanmamalı; 019 olmayan eski sunucuda silme gizlenmeli.
- Güvenli depolama/PDF/URL işlemleri değiştirilebilir arayüzlerle test edilmeli, şifreler saklanmamalı.

## Uygulama ve inceleme kaydı (5 Kasım 2026)
- Kullanıcının 4 Kasım ek yönlendirmesiyle ana kökteki TASARIM_SISTEMI.md 3/5/6/12 bölümleri esas alındı: iki YbRenkler örneği ve lerp, bütün yazı rolleri için YbYazi, merkezi Olcu, gömülü Inter/OFL ve iki golden referansı. Ekranlar sade kaldı.
- API oturum kuşağı; ilk belirteç okuması,401 sonrası depo okuması, refresh yazması,401 temizliği ve dış PDF açılışında denetlenir. Bağımsız incelemede bulunan üç yarış için önce kırmızı test alındı; sonra düzeltildi. Son incelemede önemli açık kalmadı.
- flutter analyze temiz, tüm 31 test geçti. Yeni projeye ait debug APK üretildi. JDK 17 yalnız görev geçici klasörüne kuruldu; global JAVA_HOME/Flutter sürümü değiştirilmedi.
- Mevcut Android SDK ilk derlemede NDK 28.2, SDK 35 ve CMake 3.22.1 bileşenlerini tamamladı. Hazır Android emülatörü/sistem imajı yok; cihazda uçtan uca deneme yapılamadı. Sahte HTTP ile giriş→raporlarım→detay→kimlikli PDF ve hesap silme akışları widget testinde doğrulandı.
- `/credits/history` yalnız analiz döndürüyor; 007-020-kredi-gecmisi-sozlesmesi.md notuyla Claude'a iletildi. Sunucu/site/admin kodu değiştirilmedi.
- Başlangıç dal 1811e4a, teslim dal codex/020-musteri-uygulamasi-iskelet. Son rapor ve commit köprü sonuç dosyasında.