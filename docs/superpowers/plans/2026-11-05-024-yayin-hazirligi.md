# 024 — Android yayın hazırlığı

Onaylı köprü şartnamesi uygulanır. Başlangıç 432e05b; önceki 028 tasarımı ve 021/022 mantığı korunur.

- [x] İmza yapılandırması; gerçek yükleme anahtarı yoksa sessiz debug imzası kullanma. Depo dışı geçici anahtarla doğrula, sırları gösterme/commit etme.
- [x] Site sembolünün koddan üretilen yeşil marka varlıkları; adaptive ikon, Android 12 dahil açılış ekranı.
- [x] En az izin ve yedek dışlama; R8 açık release App Bundle ve APK.
- [x] Koddan veri envanteri; güncel resmî Play kurallarıyla mağaza metinleri ve kapalı test planı.
- [x] Sürüm/destek/yasal profil bilgilerinin kontrolü; güncel README ve yayın öncesi kontrol komutu.
- [x] Analiz, test, release AAB; mümkünse emülatörde soğuk açılış ölçümü. İnceleme, Türkçe commit, köprü raporu.

12 testçi / 14 gün şartı ve hedef API36 resmî Google belgelerinden doğrulandı (5 Kasım 2026). Mağaza cevaplarında beyan ve kullanıcı tarafından doldurulması gereken gerçek hesap bilgileri ayrılır; gerçekleşmemiş test geri bildirimleri uydurulmaz.

## Son doğrulamalar
- R8 açık imzalı AAB ve APK geçti. Asıl paket com.yerimebak.app /1.0.0+1 /API24–36, 16KB zipalign geçti; AAB HTTPS üretim adresi ve RSA girdisi doğrulandı.
- İnceleme P2: üst Gradle görevinden imza atlama açığı görev grafiği kontrolüyle kapandı. Gerçek assemble dry-run eski=0, yeni=1 (imza hatası), RED→GREEN.
- Yerel emülatör: Play simülasyonu +1 (5→6); normal API sentetik analiz −1 (6→5), 27,1sn; liste/karar/grafik ve PDF görüntüleyici doğru. Koyu tercih yeniden açılışta korundu.
- Manuel bulgular: tam boy hata kartı ve mesaj kısayolunun gereksiz planla başlaması düzeltildi; regresyonlar yeşil. Son Flutter test 71/71 ve analiz temiz. İkonun dairesel güvenli alanı düzeltildi.
- Release emülatör ölçümü ayrı .dogrulama paketinde (eski uygulama imzasını/verilerini korumak için): ilk8,739sn; tekrar1,823/1,827/1,698sn. Yerel devam notuna göre asıl ekran denemeleri debug+8001 ile yapıldı; release yerel HTTP için gevşetilmedi.
- Canlı API henüz kurulmamış; hesap-silme üretimde404. İleri dağıtım ön koşulları Claude008 notunda; yerel sunucuya dokunulmadı.

- Son kaynak AAB: 46,0MB; üretim HTTPS adresi ve yerel8001adresinin bulunmadığı arm64 ELF içinde doğrulandı. Gerçek mağaza PNGleri taze Android ağacından sonra çekilip1080×1920 ölçüsü doğrulandı. Emülatör Sistem teması ve doğal ekran boyutuna geri alındı.
