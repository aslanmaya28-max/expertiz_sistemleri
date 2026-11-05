# Telefon ekran görüntüleri

Hedef 1080×1920 piksel, PNG; gerçek uygulama arayüzü. Kişisel veri yerine sentetik araç, örnek e-posta ve örnek rapor kullanın. Geliştirme hata bandı/Flutter logosu/ödeme simülasyonu rozeti görünmemeli.

1. Ana sayfa: YerimeBak bandı, kredi bakiyesi, yeni araç analizi.
2. İlan okuma ve doğrulanan araç formu; kaporta şeması.
3. Rapor başı: karar, açıklama, hesaplanan değer, adil fiyat aralığı.
4. Pazarlık planı ve satıcı mesajı.
5. Benzer ilanlar ve kaynaklı model riskleri.
6. Raporlarım: sentetik kayıtlar.
7. Kredi: Play'den gelen gerçek ürün adları/fiyatları; satın alma bilgisi.

Önerilen ilk üç görsel: ana sayfa, rapor başı, pazarlık planı. En az iki telefon ekran görüntüsü yükleyin. Açık/koyu temayı karışık sunabilirsiniz. Başkasının ilan fotoğrafını veya firmaların logosunu izinsiz mağaza görseli yapmayın.

Emülatör örneği:

```powershell
adb shell wm size 1080x1920
adb shell wm density 420
adb shell screencap -p /sdcard/yb-store.png
adb pull /sdcard/yb-store.png magaza/ekranlar/01-ana.png
adb shell wm size reset
adb shell wm density reset
```

028'in golden dosyaları tasarım doğrulama görüntüleridir; mağazaya gerçek sürüm ekranı yerine otomatik yüklenmez. Yüklemeye uygun 512×512 ikon `magaza/ikon-512.png` içindedir. Öne çıkan görsel 1024×500 ayrıca hazırlanabilir; gerçek özelliği olmayan vaat veya sıralama iddiası eklemeyin.

## Bu görevde alınan taslaklar

`ekranlar/01-rapor-koyu.png` ve `ekranlar/02-satici-mesaji-koyu.png`: yerel sunucuda normal analiz akışıyla üretilen sentetik 2024 Seat Ibiza raporundan, 1080×1920. Uygulamanın gerçek debug arayüzü; banner kapalı. Ödeme simülasyonu ekranı mağaza görseli yapılmadı. Üretim dağıtımı tamamlandığında son release arayüzüyle tekrar çekip inceleyebilirsiniz.
