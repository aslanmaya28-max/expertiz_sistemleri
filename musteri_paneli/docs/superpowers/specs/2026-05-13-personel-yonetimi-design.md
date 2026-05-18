# Personel Yonetimi Tasarimi

## Amaç

Admin panelindeki personel bolumu, sadece personel ekleme-silme alani degil, saha operasyon kapasitesini yoneten merkezi bir kontrol paneli olacak. Admin personelin hesabini, aktiflik durumunu, il/ilce sorumlulugunu, sifre resetini ve il bazli personel eksikligini tek ekrandan gorecek.

## Ana Karar

Personel kaydi yerel `SharedPreferences` verisi olarak tutulmayacak. Merkezi API ve veritabani yetkili kaynak olacak. Flutter admin paneli personel verisini API'den okuyacak ve tum kritik islemleri API uzerinden yapacak.

## Personel Hesabi

Admin personel eklerken ad soyad, e-posta, telefon, il, ilce, uzmanlik alani ve gecici sifre girer. Backend kullanici kaydini guvenli sifre hash'iyle olusturur, personel profilini `profiles` ve gerekli oldugunda `users` tablolariyla esler. Sistem mevcut sifreyi hicbir zaman geri gostermez.

Admin sifre sifirlayabilir. Sifre sifirlamada yeni gecici sifre verilir ve personelin ilk giriste kendi sifresini degistirmesi zorunlu olur.

## Aktif/Pasif Kontrolu

Personel pasife alindiginda bu sadece listede pasif gorunmesi anlamina gelmez. Yeni giris engellenir, mevcut token/API islemleri `aktif_mi` veya `is_active` kontroluyle reddedilir. Gecmis raporlar, gorevler ve hakedisler korunur.

Pasife alma sebebi zorunlu tutulur. Islem audit log'a admin bilgisi, tarih, personel id ve sebep ile yazilir. Admin daha sonra personeli tekrar aktif edebilir.

Kalici silme sadece hic gorevi/raporu olmayan yanlis veya test kayitlari icin ayricalikli aksiyon olarak tutulur.

## Il ve Ilce Yonetimi

Personelin il ve ilce bilgisi merkezi profilde saklanir. Il/ilce degisikligi gelecekteki atamalari etkiler. Acik gorevleri otomatik tasimaz; acik gorev varsa admin ekranda uyarilir.

Atama algoritmasi sadece aktif personeli dikkate alir. Talebin iliyle eslesen aktif personel varsa oncelik onlara verilir.

## Kapasite Dashboard'u

Admin personel ekraninda su bilgiler gorunur:

- Toplam personel
- Aktif personel
- Pasif personel
- Kapsanan il sayisi
- Personel olmayan iller
- Minimum hedefe gore personel eksigi olan iller
- Il bazli aktif/pasif personel sayisi
- Il bazli acik talep sayisi

Minimum hedef ilk fazda basit kural ile hesaplanir: buyuksehirler icin 3, orta yogunluklu iller icin 2, diger iller icin 1 aktif personel. Kural daha sonra ayarlanabilir hale getirilebilir.

## API Tasarimi

Yeni admin personel API'leri:

- `GET /api/v1/personnel/admin/personnel`
- `POST /api/v1/personnel/admin/personnel`
- `PUT /api/v1/personnel/admin/personnel/{personnel_id}`
- `POST /api/v1/personnel/admin/personnel/{personnel_id}/activate`
- `POST /api/v1/personnel/admin/personnel/{personnel_id}/deactivate`
- `POST /api/v1/personnel/admin/personnel/{personnel_id}/reset-password`
- `GET /api/v1/personnel/admin/coverage`

Tum admin endpointleri `get_admin_user` ile korunur.

## Hata Davranisi

E-posta tekrarliysa 409 doner. Pasif personel login olamaz. Personel bulunamazsa 404 doner. Pasife alma sebebi bos ise 400 doner. Il/ilce bos veya gecersizse 400 doner.

## Test Stratejisi

Backend unit testleri once yazilacak. Testler personel olusturma, tekrarli e-posta engeli, pasife alma, pasif personelin token/API yetkisinin kesilmesi, sifre reseti ve il bazli coverage hesaplamasini dogrulayacak.

Flutter tarafinda servis testleri API path ve payload dogrulamasina odaklanacak. UI davranisi daha sonra widget testleriyle genisletilebilir.
