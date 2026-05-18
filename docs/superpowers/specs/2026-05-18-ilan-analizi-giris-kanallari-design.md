# Ilan Analizi Giris Kanallari Tasarimi

## Amac

`expertiz_sistemleri` icinde `Ekspertiz Talebi` ile `Ilan Analizi` urunlerini net bicimde ayirmak ve ilan analizine uc farkli giris kanali eklemek:

- mobil paylasim
- web panelinde manuel link yapistirma
- mevcut Chrome eklentisi

Uc kanal da ayni merkezi analiz hattina baglanacak, kredi mantigi tek yerde yonetilecek ve sonuclar musteri panelindeki `Analizlerim` bolumunde tutulacak.

## Temel Urun Kararlari

- `Ekspertiz Talebi`, fiziksel hizmet akisidir ve analiz urununden ayri kalir.
- `Ilan Analizi`, dijital kredi bazli urundur.
- Mobilde kullanici paylastigi ilanla ekspertiz talebine degil, analiz akisina girer.
- Mobil paylasim ilk surumde yalnizca URL alir.
- Mobil paylasim sonrasi kullaniciya sadece kisa onay verilir:
  - `Ilan alindi, analiz tamamlaninca panelinizde gorunecek.`
- Analiz sonucu mobilde zorla acilmaz; musteri panelindeki `Analizlerim` listesine duser.
- PC tarafinda Chrome eklentisi korunur, ayrica eklenti kuramayanlar icin manuel link girisi bulunur.

## Onerilen Mimari

Ana karar: tum analiz girisleri ayni merkezi analiz omurgasini kullanir. Girdinin farki yalnizca `source` alanidir.

Desteklenen kaynaklar:

- `mobile_share`
- `manual_paste`
- `chrome_extension`

Ortak analiz hatti:

1. Girdi alinir.
2. URL ve kaynak dogrulanir.
3. Kredi kontrolu yapilir.
4. Analiz kaydi olusturulur.
5. Analiz basarili olursa kredi dusulur.
6. Sonuc tek tip analiz kaydi olarak saklanir.
7. Musteri panelindeki `Analizlerim` listesine yansir.

Bu yaklasimla mobil, web ve eklenti birbirinden kopuk uc sistem olmaz; ayni servis, ayni kurallar ve ayni veri modeli korunur.

## Giris Akislari

### Mobil Paylasim

1. Kullanici ilan linkini telefondan paylasir.
2. YerimeBak uygulamasi linki alir.
3. Link backend'e `mobile_share` kaynagiyla gonderilir.
4. Kullaniciya kisa onay mesaji gosterilir.
5. Analiz arka planda islenir.
6. Sonuc musteri panelindeki `Analizlerim` bolumune eklenir.

### Web Manuel Link Girisi

1. Kullanici musteri panelindeki `Ilan Analizi` ekranina gider.
2. Ilan linkini yapistirir.
3. Link backend'e `manual_paste` kaynagiyla gonderilir.
4. Analiz sonucu `Analizlerim` listesine kaydedilir.

### Chrome Eklentisi

1. Kullanici desteklenen ilan sayfasinda eklentiyi calistirir.
2. Eklenti mevcut davranisiyla zengin ilan verisi gonderebilir.
3. Backend sonucu `chrome_extension` kaynagiyla merkezi analiz kaydina baglar.
4. Sonuc yine `Analizlerim` listesinde gorunur.

## Kullanici Deneyimi

### Musteri Paneli

`Analizlerim` ana arsivdir. Her analiz ayri satir veya kart olarak gosterilir:

- arac basligi
- kaynak
- tarih
- durum
- kisa karar ozeti

Kart acildiginda detay analiz ekranina gidilir.

### Ilan Analizi Ekrani

Web tarafinda ekspertiz talep ekranindan ayri bir ekran olur. Kullanici linki buraya yapistirir. Ekran sade tutulur ve fiziksel ekspertiz akisi ile karistirilmaz.

### Ekspertiz Talep Ekrani

Mevcut talep akisi korunur. Bu ekranin urun amaci fiziksel ekspertiz hizmetidir; analiz urunuyle birlestirilmez.

## Veri Modeli

Her analiz kaydinda en az su alanlar bulunur:

- `user_id`
- `source`
- `url`
- `status`
- `credits_charged`
- `vehicle_snapshot`
- `analysis_result`
- `created_at`
- `completed_at`

`status` degerleri:

- `queued`
- `processing`
- `completed`
- `failed`

## Hata Yonetimi

- Gecersiz URL: kullaniciya anlasilir hata mesaji doner.
- Desteklenmeyen site: acikca belirtilir.
- Yetersiz kredi: analiz baslamadan reddedilir.
- Analiz hatasi: kredi dusulmez, kayit `failed` durumuna alinabilir.
- Ayni link tekrar gonderilirse sistem son analizi gosterebilir; kullanici isterse yeniden analiz baslatabilir.

## Ilk Surum Kapsami

### Dahil

- Mobil paylasimla yalnizca URL alma
- Webde manuel link girisi
- Chrome eklentisinin korunmasi
- Uc kaynagin merkezi analiz altyapisina baglanmasi
- Sonuclarin `Analizlerim` listesinde gosterilmesi
- Kredi dusumunun merkezi backend mantigiyla yonetilmesi

### Kapsam Disi

- Mobil paylasimda baslik, gorsel, fiyat gibi on bilgileri aninda cekmek
- Push bildirimleri
- Fiyat alarmi
- Mobilde analiz detay ekranini otomatik acmak
- Ekspertiz talebi ile analiz akislarini birlestirmek

## Test Stratejisi

### Backend

- Gecerli URL analiz kuyruguna dusurulur.
- Basarili analizde kredi dusulur.
- Basarisiz analizde kredi dusulmez.
- `mobile_share`, `manual_paste`, `chrome_extension` kaynaklari dogru kaydedilir.
- Hatali URL ve yetersiz kredi dogru yanit verir.

### Flutter

- Paylasilan URL yakalanir.
- Kisa onay mesaji gosterilir.

### Web

- Manuel link girisi calisir.
- `Analizlerim` listesi yeni sonucla guncellenir.

### Regresyon

- Mevcut Chrome eklentisi bozulmaz.
- Mevcut ekspertiz talep akisi etkilenmez.

## Teknik Notlar

- Mevcut `/api/v1/extension/analyze` hatti zengin ilan verisi kabul ediyor. Uygulamada hedef, bu mantigi zamanla ortak bir `analysis intake` servisine tasimak ve mobil/web girislerini ayni cekirdege baglamaktir.
- Ilk uygulama diliminde gereksiz buyuk refaktor yerine, ortak veri modeli ve ortak kayit mantigi once kurulmalidir.
