# Apify taklit (mock) ciktilari

`APIFY_MODE=mock` iken `apify_service` bu dosyalari dondurur; internete cikilmaz, ucret olusmaz.

**Fiyatlar test verisidir, gercek piyasa fiyati degildir.** Kaynak alani `test` oldugu icin veritabaninda ayirt edilir.

- `ilan.json`: tek ilan modu (girdideki link adresiyle dondurulur)
- `emsal.json`: emsal modu; `emsal_<marka>_<model>.json` varsa o tercih edilir
