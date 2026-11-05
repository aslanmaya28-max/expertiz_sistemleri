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

Yayın imzası ve mağaza hazırlığı aşağıdaki 024 adımlarındadır. Anahtar, keystore, key.properties ve google-services.json depoya girmez.

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
- İlan okuma, araç analizi ve Google Play kredi satışı hazırdır. Ekspertiz akışı 023 kapsamındadır.

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
API hata/yenileme ve oturum yarışları, sürüm kapısı, profil silme, müşteriye açık karar/rapor alanları, sayfalama, PDF ve yüzde 130 yazı ölçeği sınanır.
Açık/koyu ana bileşen golden referansları `test/goldens/` altındadır. Kasıtlı tasarım değişiminde görselleri inceleyerek:

```sh
flutter test test/theme_golden_test.dart --update-goldens
```

`PlatformServices`, `TokenStore`, HTTP istemcisi ve Riverpod sağlayıcıları testlerde değiştirilebilir.
Tema seçimi shared_preferences ile kalıcıdır; ilk açılış varsayılanı sistem temasıdır.

## İlan okuma, analiz ve Google Play (021–022)

- **Akış:** link yapıştır ya da ilan uygulamasında *Paylaş → YerimeBak* → `/analiz/oku` (önce sunucu `GET /valuation/prefill`;
  sahibinden.com'da ya da sunucu okuyamazsa ilan telefonda görünmeyen WebView'de açılır, ilan numarası/tarihi görülünce metin
  `POST /valuation/prefill-text`'e gider) → dolu form → `POST /valuation/analyze` (tek `request_id`, 200 sn zaman aşımı, bağlantı
  koparsa aynı numarayla 6 deneme) → rapor detayı. Sayfa çerez onayı/doğrulama isterse müşteriye gösterilir; okuma kendiliğinden sürer.
- **Kredi:** Google Play tüketilebilir ürünleri `paket1/5/10`. Satın alma `autoConsume: false`; kredi yalnız sunucu
  `POST /payments/google-play/verify` sonrası yüklenmiş sayılır, tüketmeyi sunucu yapar. Uygulama açılışında yarım kalan satın almalar
  `restorePurchases` ile yeniden doğrulanır. Uygulama web ödemesine link vermez.
- **Emülatörde uçtan uca deneme:**
  ```sh
  # Sunucu (ayrı veritabanı; 10.0.2.2 izni şart, yoksa "Invalid host header" 400)
  cd musteri_paneli && EXTRA_ALLOWED_HOSTS=10.0.2.2 DATABASE_URL=postgresql://postgres:test@localhost:55432/ybapp \
    PAYMENT_SIMULATION=true GOOGLE_PLAY_SIMULATION=true MEDIA_STORAGE=local python -m uvicorn yerimebak_ai_v5.main:app --host 0.0.0.0 --port 8001
  # Uygulama (Google Play'siz deneme satın alması yalnız debug'da)
  flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1 --dart-define=PLAY_SIMULASYON=true
  # Paylaşım denemesi
  adb shell "am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT '<ilan linki>' -n com.yerimebak.app/.MainActivity"
  ```
- **Marka/model kataloğu** web'den üretilir: `python tool/katalog_uret.py ../musteri_paneli/frontend/src/lib/aracFormu.ts lib/analiz/arac_katalogu.dart`.

### Emülatörden yerel API

Android emülatörü için API adresi `http://10.0.2.2:8000/api/v1` olur. Sunucuyu `EXTRA_ALLOWED_HOSTS=10.0.2.2` ortam değişkeniyle başlatın; aksi halde Host başlığı 400 ile reddedilir. `.env` dosyasını değiştirmek gerekmez.

## Play yayını (024)

Mağaza alanlarının kopyalanabilir metinleri `magaza/` içindedir. Kalıcı inceleme hesabı, Play Console ürünleri ve üretim sunucusu kurucu tarafından hazırlanır; bu görev dış servise yükleme yapmaz.

### Yükleme anahtarı

JDK17 `keytool` ile **proje klasörü dışında** anahtar üretin. Parolayı komuta yazmayın; araç etkileşimli sorar:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE/yerimebak-anahtarlar"
keytool -genkeypair -v -keystore "$env:USERPROFILE/yerimebak-anahtarlar/upload.jks" -alias upload -keyalg RSA -keysize 2048 -validity 10000
Copy-Item android/key.properties.example android/key.properties
```

`android/key.properties` dosyasına `storeFile=C:/Users/KULLANICI/yerimebak-anahtarlar/upload.jks`, `keyAlias=upload`, gerçek `storePassword` ve `keyPassword` girin. Windows yolunda `/` kullanın. Dosya ve keystore Git'te yok sayılır; parola/anahtarları sohbete veya commit'e koymayın. Alternatif: `YB_ANDROID_KEY_PROPERTIES` ortam değişkeniyle depo dışındaki özellik dosyasının tam yolunu verin.

**Play App Signing kullanın; yükleme anahtarını ve parolaları güvenli iki yerde yedekleyin.** Anahtar kaybı yeni sürüm yüklemesini engeller ve Console kurtarma süreci gerektirebilir. Doğrulama sırasında oluşturulan geçici anahtar yayın anahtarı değildir.

### Yayın derlemesi

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yerimebak.com.tr/api/v1
# Soğuk açılış / yerel sürüm denemesi için:
flutter build apk --release --dart-define=API_BASE_URL=https://api.yerimebak.com.tr/api/v1
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`. R8 küçültme ve kaynak daraltma açıktır. API HTTPS zorunludur; `PLAY_SIMULASYON` release'de kapalıdır. İmza eksikse derleme durur; debug anahtarına geri düşmez. Sürüm `pubspec.yaml` içindeki `1.0.0+1` değerinden gelir; her sonraki Console yüklemesinde `+` sonrasındaki kodu artırın. Paket adı `com.yerimebak.app`, minimum API24, hedef API36.

Release APK ile:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop com.yerimebak.app
adb shell am start -W -n com.yerimebak.app/.MainActivity
```

`TotalTime` ilk Android görüntüsüne kadar geçen süredir; ağdan config/oturum yanıtının gelmesi ayrıca ölçülmelidir. Debug süresiyle karşılaştırıp kullanıcıya release süresi diye sunmayın. İnternet kapalı testte açılış marka ekranından sonra anlaşılır hata ekranına geçmelidir.

### Marka kaynaklarını yenileme

Sitedeki SVG sembolü aynı path ile kullanılır; renkler tasarım sisteminin marka bandı ve vurgu değerleridir. Bitmap kaynakları kodla vektörden üretilir:

```powershell
flutter test tool/marka_uret_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Uyarlanabilir/tek renk ikon, Android12 ve eski Android açılış ekranı üretilir. Paketlerde yalnız Android hedefi açık; iOS/web eklenmez. `allowBackup=false` ve XML yedek/cihaz aktarım dışlamaları oturum belirteçlerini korur. Kamera, konum, rehber veya galeri izni yoktur.

### Console sırası

Geliştirici hesabı ve doğrulama → ödeme profili → uygulama oluşturma → Play App Signing/ürünler → listeleme ve veri güvenliği/erişim formları → AAB ile kapalı test → 12+ kesintisiz testçiyle 14 gün → gerçek geri bildirimlerle üretim erişimi başvurusu. Ayrıntılar `magaza/kapali-test-plani.md` içinde. Testçilere mesaj otomatik gönderilmez.

024 yerel ekran denemesi: mevcut sunucu `http://10.0.2.2:8001/api/v1`; yalnız debug için `--dart-define=PLAY_SIMULASYON=true`. Release HTTPS zorunluluğu korunur; yerel HTTP denemesi için bu kuralı gevşetmeyin. Sunucuyu başlatma/durdurma 024 kapsamı değildir.

### Hizmetler ve yerinde ekspertiz (023)

`lib/hizmetler/` katalog, sunucu fiyat teklifi, talep, PayTR, fiziksel rapor/dosya ve uygulama içi bildirim akışlarını içerir. `expertiz_enabled=false` iken hizmet tanıtımı görünür; derin bağlantı ve doğrudan repository çağrısı dahil yeni talep/ödeme engellenir. Açılınca firma/paket → araç/adres/zaman → sözleşmeler ve ödeme adımları kullanılır. Not/adres/zaman mevcut API'nin `note` alanında etiketlenerek iletilir. Fiyat veya KDV istemcide hesaplanmaz; KDV dahil hizmet tutarı `service_fee_incl_vat_tl` alanından beklenir (köprü isteği009). Alan eksikse tutar uydurulmaz.

PayTR dönüş adresi yalnız dönüş sinyalidir; başarı durumu API sipariş durumundan doğrulanır. Dosyalar yalnız API'nin kendi imzalı medya yollarından indirilir. Okundu bildirimleri `/expertiz/notifications/read` üzerinden işaretlenir; push kurulmaz. Vekalet ve çekici tanıtım olarak kalır. İlgi kaydı ucu gelene kadar destek e-postası taslağı kullanılır.
