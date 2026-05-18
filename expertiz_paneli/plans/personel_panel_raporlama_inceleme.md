# Personel Paneli Raporlama Sistemi Inceleme Raporu

Tarih: 2026-05-11

Kapsam:

- `lib/personnel/personnel_dashboard.dart`
- `lib/screens/expertiz_akisi/*`
- `lib/screens/personel/expertiz_sihirbazi.dart`
- `lib/providers/expertiz_provider.dart`
- `lib/providers/admin_provider.dart`
- `lib/services/rapor_service.dart`
- `lib/services/personel_service.dart`
- `lib/services/repository/expertiz_repository.dart`
- `lib/models/expertiz/*`

## 1. Genel Sonuc

Personel panelinde raporlama sistemi teknik olarak var ve dusunulmus. Sistem ozellikle 5 adimli ekspertiz akisi uzerine kurulmus:

1. Arac ve satici bilgileri.
2. Dis ekspertiz.
3. Ic ekspertiz.
4. Boya / kaporta.
5. Kurumsal ekspertiz.

Bu yapi is hedefiyle uyumlu: personel sahada araci inceler, asamalari doldurur, kurumsal ekspertiz raporlarini ekler, sonra rapor admine gider.

Ancak mevcut durumda sistem tam operasyonel degil. En buyuk eksik, hazirlanan raporun Supabase uzerinden admin onay hattina ve musteri yayin hattina guvenilir sekilde baglanmamis olmasidir. Raporlama ekrani ve modeller guclu, ama kalici veri ve is akisi katmani halen local/mock agirlikli.

## 2. Aktif Personel Akisi

Ana uygulama personel paneli olarak `PersonnelDashboard` kullaniyor.

Aktif giris:

- `main.dart` icinde `/staff_dashboard` -> `PersonnelDashboard`.
- `app_router.dart` icinde personel route -> `PersonnelDashboard`.

Aktif gorev baslatma zinciri:

```text
PersonnelDashboard
  -> AdminProvider.talepler
  -> personele atanmis TalepModel listesi
  -> "GOREVI BASLAT"
  -> ExpertizBaslatSayfasi
  -> ExpertizProvider
  -> 5 adimli ekspertiz akisi
```

Bu dogru mimari yondur. Personel kendisine atanan talebi goruyor ve gorev uzerinden ekspertiz akisini baslatiyor.

## 3. Mevcut Guclu Taraflar

### 3.1 Gorev bazli personel paneli var

`PersonnelDashboard`, mevcut kullaniciyi `AuthServicePro().checkSession()` ile aliyor ve `AdminProvider.talepler` listesinden sadece kendisine atanmis talepleri filtreliyor.

Bu is kuralina uygun:

- Admin talebi personele atar.
- Personel sadece kendi gorevlerini gorur.
- Gorev tamamlanan/aktif olarak ayrilir.

Eksik taraf: veri kaynagi henuz Supabase gorev atama tablosu degil, `TalepService` / local yapi.

### 3.2 5 adimli rapor modeli kurulmus

`TamRaporModel`, tum adimlari tek raporda birlestiriyor:

- `Adim1AracSaticiModel`
- `Adim2DisEkspertizModel`
- `Adim3IcEkspertizModel`
- `Adim4BoyaKaportaModel`
- `Adim5KurumsalEkspertizModel`
- `AIAnalizSonucu`

Bu model dogru yerde duruyor. Nihai raporun ham saha verisi + AI analiz sonucu olarak temsil edilmesine izin veriyor.

### 3.3 Taslak kayit mantigi var

`ExpertizProvider`, her adim guncellendiginde `_saveDraft()` cagiriyor. Bu sayede teorik olarak personel yarim kalan goreve devam edebilir.

Bu operasyon icin cok degerli. Sahada baglanti kopabilir, personel formu yarim birakabilir. Taslak sistemi korunmali; sadece local yerine Supabase destekli hale getirilmeli.

### 3.4 Admin ilerleme bildirimi dusunulmus

`ExpertizProvider.updateAdim1...updateAdim5` metodlari `AdminProvider.updateGorevIlerleme` cagiriyor.

Bu fikir dogru:

- Adim 1 -> %20
- Adim 2 -> %40
- Adim 3 -> %60
- Adim 4 -> %80
- Adim 5 -> %100

Eksik taraf: bu ilerleme sadece provider state icinde kaliyor; Supabase'e yazilmadigi icin admin paneli gercek zamanli, kalici ve cihazlar arasi tutarli takip yapamaz.

### 3.5 Kurumsal ekspertiz adimi var

`Adim5KurumsalEkspertizModel` su alanlari destekliyor:

- Ruhsat dosyasi.
- Bakim defteri.
- Sigorta policesi.
- Muayene belgesi.
- Motor/sanziman/fren/direksiyon/elektrik durumu.
- Elektrikli arac alanlari.
- Genel puan.
- Ozet not.
- Oneriler.
- Fotograf/dosya listeleri.

Bu, musteri talebindeki "kurumsal ekspertiz raporlarini da sisteme yuklesin" ihtiyacina yakindir.

Eksik taraf: dosya secimi/yukleme gercek storage entegrasyonuna baglanmamis. Listeye URL ekleme modeli var ama Supabase Storage veya dosya secici tam operasyonel gorunmuyor.

## 4. Kritik Eksikler

### 4.1 Rapor kaydi canli veritabanina gitmiyor

`RaporService.saveReport(TamRaporModel)` halen SharedPreferences kullaniyor.

Bu, personelin hazirladigi raporun:

- admin cihazinda gorunmesini,
- musteri hesabina yayinlanmasini,
- AI isleme kuyruguna alinmasini,
- audit/log gecmisine girmesini,
- dosya ve fotograf kanitlariyla iliskilenmesini

garanti etmez.

Supabase metodu var: `saveReportToSupabase(AracRapor)`. Ancak personel akisi bu metodu kullanmiyor.

### 4.2 `ExpertizRepository` Hive kullaniyor

`ExpertizRepository.analyzeAndSaveReport` AI analizini calistirip raporu Hive'a yaziyor.

Bu, local demo icin yeterli olabilir; ancak ana sistemde yanlis katman. Personel raporu tamamladiginda kayit merkezi veritabanina gitmeli:

- `field_assignments`
- `inspection_steps`
- `inspection_media`
- `corporate_expertise_reports`
- `reports`
- `ai_report_reviews`

### 4.3 Iki ayri ekspertiz akisi var

Kodda iki benzer yol bulunuyor:

1. Aktif yola daha yakin:
   - `ExpertizBaslatSayfasi`
   - `ExpertizProvider`
   - `Adim1Sayfasi...Adim5Sayfasi`

2. Alternatif/eski yol:
   - `screens/personel/expertiz_sihirbazi.dart`
   - kendi icinde 5 adim state tutuyor
   - `PersonelService.submitTamRapor` ile kayit ediyor

Bu ikinci yol tehlikeli, cunku `submitTamRapor` raporu `jsonEncode(tamRapor.toString())` ile kaydediyor. Bu gercek JSON rapor degil; rapor verisi geri okunabilir sekilde korunmuyor.

Entegrasyonda tek resmi akisa karar verilmeli. Oneri:

```text
Resmi akis = ExpertizBaslatSayfasi + ExpertizProvider + Adim1-5 sayfalari
ExpertizSihirbazi = kaldirilacak veya bu resmi provider akisini kullanacak sekilde refactor edilecek
```

### 4.4 Personel raporu tamamlayinca talep durumu otomatik kapanmiyor

`AdminProvider.raporTamamlandi(talepId, personelId)` metodu var ve talep durumunu `Raporlandi` yapiyor. Ancak `ExpertizProvider.completeGorev()` veya `Adim5Sayfasi` son butonu bunu dogrudan kullanmiyor.

Bu nedenle personel raporu doldursa bile admin tarafinda talebin "personel raporu geldi / AI bekliyor / admin onayi bekliyor" durumuna gecmesi garanti degil.

### 4.5 AI analiz noktasi ikiye bolunmus

Bir yolda `ExpertizProvider.completeGorev()` icinde `AIEngineService.analyzeReport` cagriliyor.

Diger yolda `Adim5Sayfasi` icinde `ExpertizRepository.analyzeAndSaveReport` cagriliyor ve bu `AIAnalizService.analizEtTamRapor` kullaniyor.

Bu iki AI motorunun teklesmesi gerekir. Nihai mimaride dogru akis su olmali:

```text
Personel raporu tamamlar
  -> Supabase'e ham saha raporu kaydedilir
  -> durum = pending_ai
  -> AI backend raporu analiz eder
  -> ai_report_reviews kaydi olusur
  -> durum = pending_admin
  -> admin onaylar
  -> durum = published
  -> musteri panelinde yayinlanir
```

Personel cihazinda dogrudan final AI kararini uretmek operasyonel olarak risklidir. AI analizi backend/service tarafinda merkezi calismali.

### 4.6 Validasyon sahaya gore zayif

`ExpertizProvider.allStepsValid` tum adim modellerinin `isValid` olmasini bekliyor. Ancak aktif UI ve adim validasyonlari operasyonel kalite icin yeterince sert degil.

Ornek eksikler:

- Fotograf zorunlulugu yok.
- Kritik hasar alanlari icin minimum not/foto sarti yok.
- Kurumsal rapor secildiyse dosya/PDF yukleme zorunlulugu net degil.
- Linkten gelen arac ile personelin sahada girdigi plaka/marka/model uyusmazsa kontrol yok.
- Il/ilce/personel gorev bolgesi eslesme kontrolu yok.

### 4.7 Dosya yukleme sadece UI seviyesinde

`DosyaYuklemeWidget` guzel bir UI bileseni. Ancak gercek dosya secme, upload, storage path, dosya tipi, boyut limiti, public/private URL, silme yetkisi gibi kurumsal kisimlar tamamlanmamis.

Bu sistemde belge/fotograf kanit niteliginde oldugu icin dosya katmani kritik.

## 5. Hedef Entegrasyon Icin Onerilen Yeni Akis

### 5.1 Personel gorev listesi

Personel paneli gorevleri `TalepService` yerine Supabase'den almali:

```text
field_assignments
  join reports
  join customers/profiles
  join vehicles/listing_snapshot
```

Filtre:

```text
personnel_id = current_user.id
status in ('assigned', 'inspection_in_progress', 'pending_personnel_upload')
```

### 5.2 Gorev baslatma

Personel "Gorevi Baslat" dediginde:

1. `field_assignments.status = inspection_in_progress`
2. `reports.status = inspection_in_progress`
3. `inspection_steps` icinde 5 adim icin kayitlar olusur veya var olan taslaklar yuklenir.

### 5.3 Adim kayitlari

Her adim kaydi Supabase'e gitmeli:

```text
inspection_steps
  report_id
  step_no
  step_name
  status
  payload_json
  completed_at
```

Fotograf/PDF:

```text
inspection_media
  report_id
  step_no
  file_url
  file_type
  uploaded_by
```

### 5.4 Kurumsal raporlar

Adim 5, `corporate_expertise_reports` tablosuna baglanmali:

```text
corporate_expertise_reports
  report_id
  company_id
  package_id
  document_url
  price
  status
```

### 5.5 Personel tamamlama

Personel "Tum Raporlari Kaydet ve Gonder" dediginde:

1. Tum adimlar validasyon kontrolunden gecer.
2. Eksik fotograf/belge varsa personel uyarilir.
3. `reports.status = pending_ai`
4. `field_assignments.status = submitted`
5. AI analiz kuyrugu tetiklenir.
6. Admin panelinde "AI bekliyor" veya "Admin onayi bekliyor" olarak gorunur.

### 5.6 Admin onayi ve musteri yayini

AI analiz tamamlaninca:

1. `ai_report_reviews` kaydi olusur.
2. `reports.status = pending_admin`
3. Admin raporu inceler.
4. Admin onaylarsa `reports.status = published`
5. Musteri panelinde nihai rapor gorunur.

## 6. Kod Seviyesinde Yapilacaklar

### Oncelik 1: Tek resmi personel akisini sec

Resmi akis:

```text
PersonnelDashboard
  -> ExpertizBaslatSayfasi
  -> ExpertizProvider
  -> Adim1-5 sayfalari
```

`ExpertizSihirbazi` ya kaldirilmali ya da ayni provider ve servisleri kullanacak sekilde donusturulmeli.

### Oncelik 2: `RaporService.saveReport(TamRaporModel)` Supabase'e baglanmali

Mevcut SharedPreferences legacy kalabilir ama aktif personel akisinda kullanilmamali.

Yeni servis onerisi:

```text
InspectionReportService
  saveDraftStep(reportId, stepNo, payload)
  uploadMedia(reportId, stepNo, file)
  submitForAi(reportId)
  getAssignedReport(reportId)
```

### Oncelik 3: `ExpertizProvider` local admin provider yerine merkezi servis kullanmali

Su an `AdminProvider()` yeni instance olarak uretiliyor. Bu, uygulamadaki aktif provider instance'i ile ayni olmayabilir.

Ilerleme bilgisi Supabase'e yazilmali:

```text
inspection_steps.status
reports.progress_percent
reports.status
```

### Oncelik 4: `Adim5Sayfasi` son butonu merkezi akisa baglanmali

Mevcut:

```text
ExpertizRepository.analyzeAndSaveReport(tamRapor)
```

Hedef:

```text
InspectionReportService.submitCompletedReport(tamRapor)
  -> Supabase kayit
  -> status pending_ai
  -> AI backend job
  -> admin review queue
```

### Oncelik 5: Dosya upload gercek hale getirilmeli

`DosyaYuklemeWidget` korunabilir. Ancak arkasina:

- dosya secici,
- Supabase Storage upload,
- MIME/type kontrolu,
- boyut limiti,
- private bucket policy,
- signed URL,
- silme yetkisi

eklenmeli.

## 7. Nihai Degerlendirme

Personel panelindeki raporlama sistemi sifirdan yazilacak kadar kotu degil; tam tersine iyi bir iskelet var. Fakat mevcut hali demo/local calisma seviyesinde.

Kusursuz entegrasyon icin asil yapilacak is, UI'yi buyutmek degil; mevcut rapor akisini Supabase merkezli operasyon sozlesmesine baglamaktir.

En kritik karar:

```text
Personel raporu = local/Hive/SharedPreferences kaydi degil,
Supabase uzerinde admin onay hattina bagli saha kanit paketi olmali.
```

Bu karar uygulanirsa mevcut 5 adimli raporlama yapisi ana sisteme cok iyi oturur.

## 8. Uygulanan Duzeltmeler

Bu inceleme sonrasi ilk karisiklik giderme paketi uygulandi:

1. `screens/personel/expertiz_sihirbazi.dart`
   - Eski kendi state'ini tutan ve `PersonelService.submitTamRapor` hattina giden sihirbaz kaldirildi.
   - Dosya artik sadece uyumluluk wrapper'i olarak calisiyor.
   - Cagrildiginda resmi akisa yonlendiriyor:

```text
ExpertizSihirbazi
  -> ExpertizBaslatSayfasi
  -> ExpertizProvider
  -> Adim1-5 resmi rapor akisi
```

2. `screens/expertiz_akisi/adim5_sayfasi.dart`
   - Adim 5 icindeki eski `ExpertizRepository.analyzeAndSaveReport` cagrisi kaldirildi.
   - Sayfa icindeki ikinci "rapor gonder" butonu kaldirildi.
   - Gonderim icin tek resmi aksiyon `ExpertizBaslatSayfasi` alt barindaki `Bitir ve Gonder` butonudur.
   - Bu buton `ExpertizProvider.completeGorev()` ve ardindan `AdminProvider.raporTamamlandi()` kullanir.
   - Boylece rapor kaydi, AI analizi ve admin bildirim/durum guncellemesi tek zincire baglandi.

2.1. `screens/expertiz_akisi/adim1_sayfasi.dart` - `adim4_sayfasi.dart`
   - Adim 1-4 icindeki islevsiz/sahte "Tum Raporlari Kaydet ve Gonder" butonlari kaldirildi.
   - Bu butonlar gercek kayit yapmadan sadece snack mesaj gosteriyordu ve personel icin yanlis tamamlandi algisi olusturuyordu.
   - Adim 1 sayfasi sade ve saglam form + paket ozeti yapisiyla yeniden duzenlendi.

3. `models/expertiz/tam_rapor_model.dart`
   - `copyWith` icindeki `baslangicZamani` ve `bitisZamani` kaybi duzeltildi.
   - Rapor tamamlanma zamani artik copy islemlerinde kaybolmaz.

4. `services/personel_service.dart`
   - Eski `submitTamRapor` metodu yanlislikla kullanilsa bile artik `tamRapor.toString()` yerine `tamRapor.toJson()` saklar.
   - Bu, veri kaybi riskini azaltir.

5. `services/rapor_service.dart`
   - `RaporService.saveReport(TamRaporModel)` once Supabase'e yazmayi dener.
   - `gorevId`, mevcut `reports.id` olarak kabul edilir.
   - Varsa mevcut `reports.data` korunur ve uzerine `tam_rapor`, `personel_id`, tamamlanma bilgisi, fotograf sayisi ve hasar sayisi eklenir.
   - AI sonucu `ai_analiz_detay`, `ai_piyasa_degeri`, `ai_analizi_yapildi_mi` alanlarina islenir.
   - Supabase kaydi bulunamazsa veya baglanti yoksa eski local kayit fallback olarak calisir.

6. `main.dart`
   - `RaporService.initSupabase(Supabase.instance.client)` eklendi.
   - Gercek Supabase URL/key girildiginde rapor servisi merkezi Supabase client'i kullanabilecek.

7. `providers/expertiz_provider.dart`
   - Her adimda yeni `AdminProvider()` olusturan sahte ilerleme bildirimi kaldirildi.
   - Bu instance uygulamadaki gercek provider olmadigi icin admin ekranina guvenilir veri tasimiyordu.
   - Gercek admin bildirimi final akista `ExpertizBaslatSayfasi` icinden mevcut context provider'i ile yapilir.

Bu paketle personel panelinde tek resmi raporlama akisi olusturuldu ve bu akisin rapor kaydi Supabase'e baglanmaya basladi. Bir sonraki teknik adim, musteri talebi olusurken `reports.id` ile personel gorevindeki `gorevId` degerinin kesin ayni sozlesmeye baglanmasidir.
