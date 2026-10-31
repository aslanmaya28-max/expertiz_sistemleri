# Örnek ilan verisi (testler için)

Chrome eklentisinin kaydettiği ilanlarla aynı biçimdedir (`market_ingest.upsert_listings`).

**Fiyatlar test verisidir, gerçek piyasa fiyatı değildir.** Kaynak alanı `test` olduğu için veritabanında ayırt edilir.

- `ilan.json`: müşterinin paylaştığı ilan (`status='talep'`)
- `emsal.json`: aynı araç için emsal ilanlar (`status='emsal'`)
