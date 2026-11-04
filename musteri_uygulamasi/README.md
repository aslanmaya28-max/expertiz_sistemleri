# YerimeBak — Android müşteri uygulaması

Bağımsız Flutter projesi; admin/personel uygulamasına bağımlı değildir. Paket: `com.yerimebak.app`, sürüm: `1.0.0+1`.
Ekranlar sade tutulur. API, oturum ve veri sağlayıcıları görünümden ayrıdır; rapor fiyatı/pazarlık hesabı telefonda yapılmaz.

## Kurulum ve çalıştırma

Flutter 3.38.8 / Dart 3.10.7 ile doğrulanır. Android derlemesi JDK17, Android SDK ve lisanslarını ister.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
```

Android emülatöründeki `10.0.2.2`, bilgisayardaki sunucudur. Fiziksel cihazda geliştiricinin yerel ağ IP'sini kullanın.
Derleme tanımı yoksa geliştirme varsayılanı `http://10.0.2.2:8000/api/v1` olur. HTTP izni yalnız debug manifestindedir.
Üretim adresi `https://api.yerimebak.com.tr/api/v1`; release modunda HTTPS zorunludur:

```sh
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yerimebak.com.tr/api/v1
```

Yayın imzası ve mağaza hazırlığı 024 görevidir. Anahtar, keystore, key.properties ve google-services.json depoya girmez.

Yerel sunucuyu ana demo 8000/3000 ve `ybdemo` üzerinde çalıştırmayın. Kendi PostgreSQL veritabanınızı (`ybapp_020` gibi)
oluşturup API'yi 8001'de açın; ayrı test kullanıcısı kaydedin. Test için `PYTHON_DOTENV_DISABLED=1`, `SECRET_KEY=test`,
`MEDIA_STORAGE=local`, `PAYMENT_SIMULATION=true`, boş `OPENROUTER_API_KEY` ve yalnız kendi test DB adresinizi kullanın.
Bu uygulama kredi satın almak için web ödemesine yönlendirmez.

## Ekranlar

- Giriş, kayıt (ad/soyad, telefon, sözleşme onayı), şifremi unuttum.
- Ana sayfa: bakiye, doğrulama e-postasını yeniden gönderme, son raporlar.
- Raporlarım: sayfalama, aşağı çekip yenileme; rapor detayı ve kimlikli PDF indirip açma.
- Profil: ad/telefon, şifre değişikliği, analiz kredi geçmişi, yasal/destek bağlantıları, sürüm, açık/koyu/sistem tema seçimi.
- Hesap silme: şifre ve açık onay sonrası sunucuya istek, başarıda güvenli belirteci temizleyip çıkış.
- Asgari sürüm kapısı; eski sunucuda `/app/config` 404 ise hesap silme gizlenir.
- Araç analizi (021) ve Play kredi satışı (022) için yer tutucu ekranlar. Ekspertiz akışı 023 kapsamındadır.

## Kod düzeni

- `lib/api`: HTTP/hata ve repository'ler, kullanıcı/config/rapor modelleri, Riverpod veri sağlayıcıları ve rapor sayfalama denetleyicisi.
- `lib/oturum`: `TokenStore` arayüzü, güvenli Android depolaması, oturum denetleyicisi ve form doğrulaması.
- `lib/ekranlar`: yalnız görünüm/form durumu, sağlayıcı ve eylem bağlantıları.
- `lib/bilesenler`: rapor bölümleri ve ortak görünüm elemanları.
- `lib/tema`: TASARIM_SISTEMI.md 3/5/6/12 renkleri (ThemeExtension), Inter tipografisi, ölçüler, açık/koyu Material3 temaları.
- `assets/fonts`: gömülü Inter değişken fontu (400/500/600/700), OFL lisansı; çalışma anında font indirilmez.

Belirteç yalnız `flutter_secure_storage` içinde tutulur; şifre kaydedilmez. Android yedekleme kapalıdır.
401 yanıtında tek refresh denenir; eşzamanlı istekler aynı oturum kuşağındaki yenilemeyi paylaşır. Yeni giriş/çıkış eski
isteklerin belirteç yazmasını, yeni oturumu kapatmasını veya eski PDF'yi dış görüntüleyicide açmasını engeller.
PDF uygulamanın geçici özel klasörüne yazılır; yalnız HTTP/HTTPS kaynak ve mailto destek bağlantıları açılır.

Sunucunun mevcut `/credits/history` ucu yalnız analiz geçmişi sağlar. Satın alma/iade hareketleri için köprüde
`007-020-kredi-gecmisi-sozlesmesi.md` bırakıldı; sunucu bu görevde değiştirilmedi.

## Test

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Testler API'yi taklit eder; gerçek satın alma, model çağrısı, hesap silme veya demo DB işlemi yapmaz.
API hata/yenileme ve oturum yarışları, sürüm kapısı, profil silme, rapor gizleme, sayfalama, PDF ve yüzde 130 yazı ölçeği sınanır.
Açık/koyu ana bileşen golden referansları `test/goldens/` altındadır. Kasıtlı tasarım değişiminde görselleri inceleyerek:

```sh
flutter test test/theme_golden_test.dart --update-goldens
```

`PlatformServices`, `TokenStore`, HTTP istemcisi ve Riverpod sağlayıcıları testlerde değiştirilebilir.
Tema seçimi bu altyapı sürümünde geçerli uygulama oturumu boyunca korunur; yeniden açılış varsayılan olarak sistem temasını izler.
