# Market Veri Kotasi ve Guncellik Tasarimi

## Amac

`yerimebak_sistemleri` Docker/Postgres veri merkezindeki arac ilanlarini daha dengeli, guncel ve AI analizine uygun hale getirmek. Merkezi AI piyasa degerini hesaplarken rastgele veya bozuk marka/model gruplarina degil, hedef marka/model ve yas bandi bazli saglikli referans havuzuna dayanacak.

## Problem

Mevcut DB'de 4314 arac kaydi var, ancak marka/model kalitesi tutarsiz. Ornek kontrolde `RENAULT / 1.5 dCi` gibi motor bilgisinin model yerine yazildigi gruplar goruldu. Bu durum piyasa ortalamasi hesaplarken Clio, Megane, Fluence gibi gercek model ayrimini bozabilir.

Ayrica mevcut `MarketReferenceService` ayni marka/model icin 3 kayit buldugunda referans uretiyor. Bu, resmi ekspertiz AI icin alt sinir olarak zayif. Hedef, populer marka/model icin daha tutarli ve guncel referans havuzu kurmak.

## Ana Karar

Sistem, hedef marka/model listesi icin aktif referans kotasi tutacak:

- Her populer marka/model toplam minimum 30 aktif referans.
- Her 5 yillik yas bandi minimum 10 aktif referans.
- 27 gunden eski listing kayitlari otomatik silinecek.
- Temizlikten sonra eksilen kota otomatik backfill kuyruğuna alinacak.
- Vites ve yakit verisi kota sayimini tamamen bolmeyecek, ancak segment bazli denge hedefi olarak kullanilacak.

## Yas Bantlari

Ana yil bantlari:

- `2012-2016`
- `2017-2021`
- `2022-2026`

EV segmenti icin uygulanacak bantlar daha dar olabilir, cunku eski EV hacmi dusuktur:

- `2020-2022`
- `2023-2026`

Ilk fazda mevcut `turkey_targets.py` hedef listesi korunur. Hedef liste daha sonra admin/data ekranindan yonetilebilir hale getirilebilir.

## Segment Bazli Denge Politikasi

### Otomobil ve SUV

Otomobil ve SUV modellerde hedef dagilim:

- Yakit: %50 benzin, %50 dizel.
- Vites: %50 otomatik, %50 manuel.

10 referanslik yas bandi icin hedef:

- 5 benzin, 5 dizel.
- 5 otomatik, 5 manuel.

Bu dagilim katı blokaj degildir. Sistem once toplam 10 gercek referansi doldurur, sonra eksik yakit/vites dagilimini sonraki backfill turlarinda onceliklendirir.

### Ticari Araclar

Ticari modellerde piyasa gercegi dizel ve manuel agirliklidir. Hedef dagilim:

- Yakit: %70 dizel, %30 benzin veya diger.
- Vites: %60 manuel, %40 otomatik.

10 referanslik yas bandi icin hedef:

- 7 dizel, 3 diger.
- 6 manuel, 4 otomatik.

Bu da katı blokaj degildir. Ornegin Fiat Doblo bandinda 10 dizel ve 9 manuel veri varsa sistem bunu gercek piyasa uyumlu kabul edebilir, ancak raporda dagilim farkini gosterir.

### EV

EV modellerde yakit dengesi uygulanmaz. Yakit `electric` kabul edilir. Vites dagilimi de klasik manuel/otomatik dengesi gibi degerlendirilmez. EV icin odak:

- marka/model toplam aktif referans,
- yil bandi aktif referans,
- kaynak guncelligi,
- fiyat dagilimi kalitesi.

## Coverage Durumlari

Her marka/model/yas bandi icin coverage satiri uretilir:

```json
{
  "brand": "Renault",
  "model": "Megane",
  "segment": "C",
  "year_bucket": "2017-2021",
  "active_count": 8,
  "target_count": 10,
  "missing_count": 2,
  "fuel_balance": {
    "petrol": 2,
    "diesel": 6,
    "target_petrol": 5,
    "target_diesel": 5,
    "status": "imbalanced"
  },
  "transmission_balance": {
    "automatic": 3,
    "manual": 5,
    "target_automatic": 5,
    "target_manual": 5,
    "status": "imbalanced"
  },
  "coverage_status": "underfilled"
}
```

Durumlar:

- `healthy`: Toplam kota dolu ve dagilim hedefe yakin.
- `filled_imbalanced`: Toplam kota dolu ama yakit/vites dagilimi hedefin disinda.
- `underfilled`: Toplam aktif referans hedefin altinda.
- `stale`: Kayitlar var ama 27 gun sinirina yaklasmis veya asmis.
- `unknown_model`: Marka/model normalizasyonu guvenilir degil.

## Marka/Model Normalizasyonu

Yeni coverage sistemi ham `brand` ve `model` alanlarina dogrudan guvenmemeli. Normalize edilmis alanlar kullanilmali:

- `normalized_brand`
- `normalized_model`
- `normalized_segment`
- `model_confidence`

Ornek normalizasyonlar:

- `RENAULT / 1.5 dCi` tek basina model kabul edilmez. Baslik veya URL'den Clio, Megane, Fluence gibi gercek model bulunamazsa `unknown_model` olur.
- `Renault Megane Sedan` -> `Renault Megane`
- `VW Golf 1.6 TDI` -> `Volkswagen Golf`
- `BMW 320i` -> `BMW 3 Serisi`
- `Mercedes C 200` -> `Mercedes C-Class`

AI referansi resmi hesapta normalizasyon sonucu guvenilir kayitlari oncelikli kullanir. Guven dusuk kayitlar coverage doldurmak icin kullanilmaz veya dusuk agirlikla kullanilir.

## Backfill Akisi

`MarketCoverageService` DB'deki aktif listing kayitlarini okur ve coverage matrisini cikarir.

`MarketBackfillWorker` su sirayla eksik hedefleri isler:

1. Toplam aktif referansi 10 altinda olan yil bandi.
2. Toplam dolu ama segment denge hedefi bozuk olan band.
3. 27 gun sinirina yaklasan band.
4. Oncelik seviyesi yuksek hedef modeller.

Backfill hedefi ornegi:

```json
{
  "brand": "Renault",
  "model": "Megane",
  "segment": "C",
  "year_min": 2017,
  "year_max": 2021,
  "missing_count": 2,
  "preferred_fuel": "petrol",
  "preferred_transmission": "automatic",
  "priority": 1
}
```

Scraper veri bulamazsa hedef basarisiz sayilmaz. Coverage raporunda eksiklik kalir ve sonraki turda tekrar denenir. Bu sayede piyasa gercekte veri uretmiyorsa sistem sahte veri veya zorlama fallback ile DB doldurmaz.

## 27 Gunluk Veri Yasam Dongusu

Mevcut `cleanup_worker.py` 21 gunluk temizlik yapiyor. Yeni kural:

- `listings.updated_at < now - 27 gun` olan kayitlar silinir.
- `price_history` icin ayni retention uygulanabilir.
- Silme islemi sonrasi coverage yeniden hesaplanir.
- Eksilen marka/model/yil bandi backfill kuyruğuna alinir.

Temizlik, DB'yi kucuk tutmaktan cok piyasa verisini guncel tutmak icindir.

## MarketReferenceService Degisikligi

Mevcut servis 3 kayitla referans uretiyor. Yeni hedef:

- Oncelik: ayni normalized brand/model ve ayni 5 yillik yil bandi.
- Saglikli referans: en az 10 aktif kayit.
- Kabul edilebilir referans: 5-9 aktif kayit, dusuk/orta guven.
- Son care fallback: DB'de yeterli gercek referans yoksa ilan fiyatinin %3 alti, `confidence=20` ve `source=last_resort_listed_price`.

Yakit/vites AI eslestirmesinde filtreyi daraltmak icin degil, skorlamak icin kullanilir. Ornegin ayni yakit/vites kayitlari varsa agirligi artar, yoksa tum band tamamen bos sayilmaz.

## Admin/Data Gozlem Ciktisi

Ilk fazda API veya CLI raporu yeterlidir. Daha sonra admin dashboard vitrin/veri merkezi sekmesine tasinabilir.

Ornek saglikli cikti:

```text
Renault Megane
2012-2016: 10/10 | yakit dengeli | vites dengeli
2017-2021: 10/10 | yakit dengesiz | vites dengeli
2022-2026: 10/10 | saglikli
Durum: Dolu, kismi denge uyarisi
```

Ornek eksik cikti:

```text
Renault Kadjar
2017-2021: 3/10
Eksik: 7
Aksiyon: backfill kuyruğuna alindi
```

## Kapsam Disi

- Sahte/sentetik arac verisi uretmek.
- Her yakit/vites kombinasyonu icin katı 10 kayit istemek.
- Tum marka/model sozlugunu ilk fazda admin UI'dan duzenlenebilir yapmak.
- 27 gunden eski veriyi archive tablosuna tasimak. Ilk fazda silme yeterlidir.

## Basari Kriterleri

- Hedef listedeki populer marka/model icin coverage raporu uretilebilir.
- Her hedef model icin toplam 30 ve her yil bandi icin 10 hedefi izlenir.
- Otomobil/SUV icin 50/50 yakit ve 50/50 vites denge durumu raporlanir.
- Ticari icin 70/30 yakit ve 60/40 vites denge durumu raporlanir.
- EV icin yakit/vites denge zorunlulugu uygulanmaz.
- 27 gunden eski listing kayitlari temizlenir.
- Temizlik veya eksik coverage sonrasi backfill hedefleri uretilir.
- MarketReferenceService 3 kayit yerine coverage kalitesini dikkate alir ve resmi AI sonucunda referans kalitesini metadata olarak dondurur.
