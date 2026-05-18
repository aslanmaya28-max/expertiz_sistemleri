# Tek Vucut Entegrasyon Tasarimi

## Amac

`yerimebak_sistemleri` musteri paneli ve merkezi API katmani olarak calisacak. `yerimebak_sistemleri` admin/personel operasyon paneli olarak kalacak. Iki sistem ayni `reports`, `profiles`, `expertiz_requests` ve `listings` gercegini kullanacak; kritik durum gecisleri tek merkezden yonetilecek.

## Basari Kriterleri

- Musteri ekspertiz talebi `yerimebak_sistemleri` uzerinden olusur ve ayni anda `reports` akisina baglanir.
- Personel raporu `reports.data.tam_rapor` alanina islenir ve rapor `pending_admin` durumuna gelir.
- Admin rapor inceleme, yayinlama ve reddetme islemleri merkezi API uzerinden yapilir.
- Musteri paneli sadece `published` raporlari gorur.
- Red nedeni `reports.data.rejection_reason` icinde saklanir ve personele geri donus icin iz birakir.
- Her onemli entegrasyon dilimi sonunda derleme/test ve code review kontrolu yapilir.

## Mimari Karar

Ana karar: durum degisimleri dogrudan Flutter icinden Supabase update ile daginik sekilde yapilmayacak. `yerimebak_sistemleri` icindeki FastAPI servisleri, ortak workflow kurallarinin sahibi olacak.

Bu yaklasimda:

- `yerimebak_sistemleri`: musteri paneli, vitrin, analiz, favoriler, profil ve merkezi ekspertiz API.
- `yerimebak_sistemleri`: admin/personel ekranlari ve operasyonel is akislari.
- PostgreSQL/Supabase tablolar: iki sistemin ortak veri zemini.
- AI worker: `pending_ai` raporlari isleyip `pending_admin` durumuna tasiyan arka plan katmani.

## Durum Makinesi

Rapor durumu asagidaki ana akisla ilerler:

1. `draft`: Musteri talebi ve rapor satiri olustu.
2. `pending_ai`: Personel ya da sistem raporu AI analizine gonderdi.
3. `pending_admin`: AI/personel raporu admin onayina hazir hale getirdi.
4. `published`: Admin onayladi, musteri panelinde gorunur.
5. `rejected`: Admin reddetti, personele duzeltme icin geri doner.

`published` rapor musteriye acilan tek nihai durumdur.

## Ilk Uygulama Dilimi

Ilk dilim merkezi admin rapor API'sini ekler:

- `GET /api/v1/expertiz/admin/reports`
- `GET /api/v1/expertiz/admin/reports/{report_id}`
- `POST /api/v1/expertiz/admin/reports/{report_id}/publish`
- `POST /api/v1/expertiz/admin/reports/{report_id}/reject`

Bu API sadece admin kullanicilar tarafindan kullanilir. `publish` islemi `status='published'`, `durum='Tamamlandi'`, `status_updated_at`, `updated_at`, `version_id` ve `data.published_at` alanlarini gunceller. `reject` islemi `status='rejected'`, `durum='Iptal'`, red nedeni ve red zamanini saklar.

## Flutter Entegrasyon Dilimi

`yerimebak_sistemleri` icindeki `RaporIncelemeModule`, ilk asamada listeleme icin mevcut Supabase okumasini koruyabilir; ancak yayin/red islemleri merkezi API'ye tasinir. Bu kademeli gecis riski dusurur.

Sonraki asamada listeleme ve detay da API'ye tasinabilir. Realtime stream ihtiyaci varsa Supabase stream sadece yenileme tetikleyici olarak kalabilir, karar islemi yine API uzerinden yapilir.

## Hata Yonetimi

- Rapor yoksa `404`.
- Admin yetkisi yoksa `403`.
- Red nedeni bos ise `400`.
- `publish` sadece `pending_admin` durumunda aktif kabul edilir; daha once yayinlanmis raporda idempotent basari donebilir.
- Tum kritik hatalar kullaniciya okunabilir mesajla doner.

## Test ve Dogrulama

- Python dosyalari `py_compile` ile dogrulanir.
- FastAPI router import edilir ve admin route'lari listelenir.
- Canli backend `/openapi.json` icinde yeni route'lar aranir.
- Flutter tarafinda statik analiz veya build uygun komutla calistirilir.
- Her uygulama diliminden sonra Requesting Code Review becerisiyle taze inceleme istenir.

## Kapsam Disi

- Tum Flutter servislerinin tek seferde API'ye tasinmasi.
- Mevcut Chrome uzantisinin silinmesi ya da yeniden yazilmasi.
- Supabase tablo isimlerinin degistirilmesi.
