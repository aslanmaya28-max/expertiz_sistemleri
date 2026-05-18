# Merkezi AI Tek Cati Tasarimi

## Amac

`yerimebak_sistemleri` merkezi AI ve musteri paneli katmani olacak. `yerimebak_sistemleri` admin/personel operasyon paneli olarak kalacak. Resmi ekspertiz raporu yayinlama yetkisi sadece merkezi AI sonucu ureten backend akisiyle tamamlanmis raporlara verilecek.

## Ana Karar

Ana kural: merkezi AI yoksa resmi rapor yayinlanmaz.

Flutter icindeki AI hesaplari silinmeyecek, ancak resmi rapor kaynagi olmayacak. Bu hesaplar sadece admin ekraninda gecici on analiz olarak gosterilebilir. Bu on analiz musteriye acilmaz, `published` durumuna gecis saglamaz ve resmi AI alanlarini doldurmaz.

## AI Kaynak Kurallari

- `central_ai`: Resmi kaynak. `yerimebak_sistemleri` worker/API tarafindan uretilir.
- `flutter_fallback`: Gecici admin on izlemesi. Resmi degildir.
- `none`: Henuz AI yok.

Bir raporun yayinlanabilmesi icin su kosullar ayni anda saglanir:

- `status = 'pending_admin'`
- `ai_source = 'central_ai'`
- `ai_official = true`
- `ai_analysis_ready = true`

`flutter_fallback` sonucu varsa rapor yine yayinlanamaz.

## Merkezi AI Akisi

1. Personel raporu `reports.data.tam_rapor` alanina yazar.
2. Rapor `pending_ai` durumuna gecer.
3. `yerimebak_sistemleri` merkezi AI worker raporu okur.
4. Worker arac bilgisini `tam_rapor` ve `vehicle_snapshot` alanlarindan normalize eder.
5. `MarketReferenceService` once Docker/Postgres `listings` tablosundaki gercek araclari referans alir.
6. Yeterli DB referansi yoksa son care olarak ilan fiyati yuzde 3 asagi cekilir, ama bu durum dusuk guvenli fallback olarak isaretlenir.
7. `YerimebakEngineV8` resmi analizi uretir.
8. `ai_result_adapter` sonucu Flutter uyumlu `AIAnalizSonucu` semasina cevirir.
9. `SupabaseBridge.write_ai_results` sonucu `reports` kaydina resmi AI olarak yazar ve raporu `pending_admin` yapar.
10. Admin sadece bu resmi sonucu inceleyip yayinlayabilir.

## Veri Sozlesmesi

AI sonucu hem ust alanlarda hem de `data.ai_meta` altinda izlenebilir olmalidir.

```json
{
  "ai_source": "central_ai",
  "ai_official": true,
  "ai_analysis_ready": true,
  "ai_reference_found": true,
  "ai_reference_source": "listings",
  "ai_reference_count": 12,
  "ai_confidence": 82,
  "ai_generated_at": "2026-05-14T00:00:00+00:00",
  "market_reference": {
    "found": true,
    "source": "listings",
    "count": 12,
    "market_avg_price": 1250000,
    "market_median_price": 1230000,
    "confidence": 82
  }
}
```

Fallback on analiz asla resmi alanlara yazilmaz. Gerekirse `data.flutter_fallback_preview` icinde saklanir:

```json
{
  "source": "flutter_fallback",
  "official": false,
  "temporary": true,
  "generated_at": "2026-05-14T00:00:00+00:00",
  "warning": "Gecici on analiz. Resmi rapor icin merkezi AI gereklidir.",
  "result": {}
}
```

## Backend Yayim Kurali

`publish_admin_report` sadece `pending_admin` durumunu kontrol etmekle kalmayacak. Ayni zamanda merkezi AI resmi sonucunu da dogrulayacak. Kosul saglanmazsa `400` donecek:

`Resmi rapor yayinlamak icin merkezi AI analizi gereklidir.`

Bu kural backend tarafinda oldugu icin Flutter UI hatali davransa bile musteriye eksik rapor acilmaz.

## Flutter Davranisi

`RaporIncelemeModule` admin ekraninda yayin butonu sadece resmi merkezi AI varsa aktif olur.

- Merkezi AI hazirsa: `Onayla & Yayinla` aktif.
- AI bekliyorsa: buton pasif, durum `Merkezi AI bekleniyor`.
- Sadece Flutter fallback varsa: sari uyari gosterilir, buton pasif kalir.

Flutter `AIEngineService` sonraki fazda resmi motor olmaktan cikarilip on analiz/fallback yardimcisi haline getirilecek.

## Kapsam Disi

- Flutter AI dosyalarini hemen silmek.
- Chrome uzantisini kaldirmak.
- Manuel admin override ile AI olmadan yayin yapmak.
- Tum eski AI isimlerini tek hamlede yeniden adlandirmak.

## Basari Kriterleri

- Merkezi AI sonucu olmayan rapor backend tarafinda yayinlanamaz.
- Worker resmi sonucu `central_ai` meta bilgisiyle yazar.
- Gercek DB referansi varsa analiz onu kullanir.
- DB referansi yoksa yuzde 3 dusuk fallback calisir ve dusuk guven olarak isaretlenir.
- Flutter admin ekraninda yayin butonu bu resmi kurala gore calisir.
- Musteri paneli sadece `published` ve resmi AI sonucu olan raporlari gorur.
