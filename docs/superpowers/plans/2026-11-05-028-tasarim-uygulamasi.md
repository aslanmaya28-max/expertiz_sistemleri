# 028 — Onaylı uygulama tasarımının uygulanması

**Amaç:** A açık ve C koyu tasarımını mevcut Flutter ekranlarına ve yeniden kullanılabilir bileşenlere taşımak.
**Şartname:** Ana kök `kopru/codex_icin/028-uygulama-tasarim-uygulamasi.md`; `docs/TASARIM_SISTEMI.md` tamamı.
**Mimari:** Mevcut repository, oturum ve rapor verileri korunur. Görünüm bileşenleri yalnız sunucu değerlerini gösterir; fiyat çubuğunun konumu görselleştirme ölçeğidir. Tercih saklama, yeni `lib/tema/gorunum.dart` sağlayıcısında yapılır; `lib/api` ve `lib/oturum` değişmez.

- [x] Başlangıç31testini doğrula. Yeni bileşen davranış testlerini önce çalıştır: karar eşlemesi, fiyat sınırları,13 parça döngü/uzun basma, çift tıklama, kalıcı tema ve hata sınıfları.
- [x] Tema ölçü/renklerini genişlet; AnaButon, IkincilButon, MetinKutusu, Kart, ListeSatiri, rozetler, FiyatAraligi, PazarlikUclusu, AltEylemCubugu, AltMenu, BosDurum/Hata, Yukleniyor ve KaportaSemasi dosyaları.
- [x] Site sembolünü SVG olarak taşı; Lucide ikonları. Ana ekran açık marka bandı/koyu kredi hapı, analiz linki/yapıştır ve son raporlar. Hizmetler bölümü yok.
- [x] Giriş ailesini marka bandı/slogan/kart düzenine geçir; profil satırları ve kalıcı Sistem/Açık/Koyu tercihi.
- [x] Rapor başı karar/açıklama/hesaplanan değer/fiyat aralığı; talep edilen bölüm sırası, pazarlık kutuları, kopyala/paylaş, kısaltılmış listeler ve sabit mesaj/PDF eylemleri. Sonraki adım023'e kadar gizli.
- [x] Bütün ortak bileşenler ve4ekran için iki temada golden; yüzde130 metin ve etkileşim testleri. Görselleri inceleyerek düzelt, tolerans ekleme.
- [x] flutter analyze, tüm testler ve debug APK. README'ye EXTRA_ALLOWED_HOSTS=10.0.2.2 notu. Bağımsız inceleme, Türkçe commit ve köprü raporu.

## İnceleme odağı
- Yanlış/verisiz fiyat aralığı ve uçtaki ilan işaretleri taşmaz; sunucu rakamları aynen kalır.
- Tema ilk yüklemesi yeni seçimi ezmez; başarısız depolama kullanıcıya bildirilir.
- Renk tek başına durum taşımaz; kaporta13parçası ayrısemantik/dokunma hedefidir, kullanıcı callback dışında veriyi değiştirmez.
- Sabit eylem çubuğu içeriği örtmez; büyük metin/yatay dar ekranda taşma yok.
- Değişen gereksinim doğrultusunda karar ve açıklama artık gösterilir; diğer admin alanları gösterilmez.

## Devam ve doğrulama kaydı
- Claude devam notuyla 021/022 (e20601a) 33dfcfe birleşiminde korundu; analiz ve kredi ekranları da kapsandı. Yasaklı mantık dosyalarında fark yok.
- Son analiz temiz; güncellemesiz normal test 69/69, iki tema + yüzde130. APK ilk koşu başarılı, son ikon değişikliği için artımlı koşu yapılıyor.
- Bağımsız inceleme önemli/engelleyici kusur bulmadı. Tasarım URL içeriğine erişilemediğinden belgenin ölçüleri esas alındı.
