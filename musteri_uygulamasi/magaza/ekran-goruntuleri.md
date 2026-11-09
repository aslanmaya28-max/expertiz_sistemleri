# Telefon ekran görüntüleri — 9 Kasım 2026

Sekiz dosya **1080×1920 PNG**; güncel uygulamanın gerçek Android emülatör akışından alınmıştır.
034 yeşil rapor tasarımı ve Raporlarım'daki Sil düğmesi bu sette yer alır.

| Dosya | Gösterilen gerçek ekran | Tema |
|---|---|---|
| `ekranlar/01-ana.png` | Bakiye, ilan bağlantısı ve yeni araç analizi, son Kamiq raporu | Açık |
| `ekranlar/02-ilan-okuma.png` | Aynı analiz akışının araç formundaki Boya ve değişen / kaporta şeması | Açık |
| `ekranlar/03-rapor-basi.png` | Skoda Kamiq başlık bandı, araç çipleri, adil fiyat aralığı | Koyu |
| `ekranlar/04-fiyat-ve-pazarlik.png` | İlan fiyatı, tavsiye alım fiyatı, üst sınır ve pazarlık üçlüsü | Açık |
| `ekranlar/05-satici-mesaji.png` | Ayrı mesaj balonu, Kopyala ve WhatsApp'ta paylaş | Açık |
| `ekranlar/06-enflasyon.png` | Üç enflasyon oranı, altı aylık/yıllık değer ve kazanç | Koyu |
| `ekranlar/07-model-riskleri.png` | Kaynakları ve önem rozetleriyle model şikâyetleri | Açık |
| `ekranlar/08-raporlarim.png` | Sentetik rapor kaydı ve Sil düğmesi | Açık |

01'de ilan linki alanı, 02'de aynı akışın elle giriş seçeneğiyle açılan gerçek araç formu gösterilir.
Fotoğraf/ekran görüntüsü yükleme arayüzü gösterilmez. Model şikâyetleri ile benzer ilanlar raporda
ayrı ve uzun bölümlerdir; sekiz mağaza dosyasından 07 şikâyetlere ayrılmıştır. Benzer ilanlar ve
kontrol sorularının ek gerçek çekimi teslim kanıtlarında `kopru/log/035-risks-listings-final.png` olarak bulunur.

Öne çıkan görsel: **`one-cikan-1024x500.png`**, 1024×500. Gerçek marka işareti, Inter fontu,
“Araç almadan önce doğru bilgiye ulaşın” metni ve 03 numaralı rapor ekranının telefon içindeki kırpığı.
Düzenlenebilir kaynak `one-cikan-1024x500.svg`; yeniden üretim:

```powershell
# musteri_uygulamasi klasöründen; Python Playwright + Chromium gerekir
python magaza/one-cikan-uret.py
```

SVG'ye gömülen Inter fontunun lisansı `Inter-OFL.txt` içinde korunmuştur.

## Veri ve çekim koşulları

- AVD: `yb_pixel`; ekran 1080×1920, yoğunluk 280 dpi, metin ölçeği %100.
- Debug APK: `API_BASE_URL=http://10.0.2.2:8001/api/v1`, `PLAY_SIMULASYON=true`.
- Yalnız yerel `ybapp` ve sentetik hesap kullanıldı; canlıda hesap/giriş/satın alma/değerleme yapılmadı.
- Rapor kaynağı: sitenin `frontend/public/ornek-rapor/degerleme.json` dosyasındaki 2025 Skoda Kamiq,
  18.000 km, 1.0 TSI Premium. Yerel sunucunun normal rapor kayıt servisiyle kaydedildi.
- Yerel aylık araç enflasyonu %0,58; kaynak notu VavaAI ikinci el araç fiyat endeksi, Ekim 2026 (%7,2 yıllık).
  Uygulamadaki yüzde yardımcıları aylık oranı yuvarlayarak %0,6 gösterir.
- Görsellerde karar, güven puanı, ödeme simülasyonu ekranı, kişisel veri ve gerçek ilan fotoğrafı yoktur.
- Kaynaklar metin bağlantılarıdır; üçüncü taraf firma logoları kullanılmadı.
- PNG'ler doğrudan `adb shell screencap` çıktısıdır; uygulama ekranları birleştirilmedi veya yeniden çizilmedi.
  Öne çıkan görsel yalnız SVG kompozisyonudur. Piksel ölçüleri, bayt boyutları ve SHA-256:
  `gorsel-manifest.json`.

## Yayın sürümü kontrolü

Canlı HTTPS API ile imzalı release APK emülatöre temiz kuruldu. Açılış, giriş ve kayıt formu,
canlı `/app/config`, Kullanım Koşulları ve KVKK bağlantıları kontrol edildi. Kayıt/giriş düğmeleri
gönderilmedi; satın alma veya değerleme yapılmadı. R8/kod küçültme kaynaklı çökme görülmedi.
Kanıtlar `kopru/log/035-release-*.png` ve teslim raporundadır. Bu dosyalar Play Console'a yüklenmedi.
