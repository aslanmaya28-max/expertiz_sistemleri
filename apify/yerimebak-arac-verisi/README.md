# YerimeBak araç verisi (Apify actor)

Müşterinin paylaştığı ilanı ve o araç için güncel emsal ilanları **arabam.com**'dan çeker. Her ilanda şunlar gelir:
- Fiyat, km, yıl, paket.
- Satıcının **boya / değişen** beyanı (parça parça).
- **Hasar kaydı:** tramer tutarı, "tramer kaydı yok" beyanı, ağır hasar kaydı.

Kazıyıcı kodu `musteri_paneli/yerimebak_ai_v5` içindeki kazıyıcının birebir kopyasıdır (`vendor/`). Kazıyıcıyı değiştirdikten sonra kopyayı güncelleyin:

```sh
python musteri_paneli/scripts/apify_sync.py
```

Kopya güncel değilse `tests/unit/test_apify.py` testi uyarır.

## Modlar

| Mod | Girdi | Çıktı |
|---|---|---|
| `ilan` | `url`: arabam.com ilan linki | Tek ilan: fiyat, km, yıl, paket, boya/değişen ve hasar kaydı beyanı |
| `emsal` | `brand`, `model`, `year`, `yearWindow`, `maxItems` | Aynı marka/model için yıl ±`yearWindow` güncel ilanlar |

Çıktıdaki her kayıt aynı biçimdedir: `source, url, brand, model, package, year, km, price, fuel, transmission, paint_info, damage_record, accident_record, observed_at...`

`damage_record` alanının değerleri:
- `tramer_tl`: Tramer tutarı (TL).
- `tramer_yok`: Satıcı "kaydı yok" dediyse `true`.
- `agir_hasar`: Ağır hasar kayıtlıysa `true`.

Bilgi ilanda yoksa alan `null` kalır. Bu durumda araç hasarsız kabul edilmez.

`paint_info` ilan sayfasındaki **"Boya, Değişen ve Tramer"** bölümünden parça parça okunur. Parça adları değerleme motorundaki adlarla aynıdır (ör. arabam.com'daki "Arka Kaput" → "Bagaj Kapağı"). `painted_parts` lokal boyalıları da içerir; lokal olanlar ayrıca `local_painted_parts`'ta listelenir. Bölüm yoksa durum "Bilinmiyor" kalır; ilan açıklamasındaki kelimelerden boya/değişen tahmini yapılmaz.

## Apify'a kurulum (bir kez)

1. Apify Console → **Actors → Create new → Link Git repository**.
2. Git URL: `https://github.com/aslanmaya28-max/expertiz_sistemleri#main:apify/yerimebak-arac-verisi`
3. **Build** düğmesine basın. İlk derleme birkaç dakika sürer.
4. **Start** ile deneyin:
   ```json
   {"mode": "emsal", "brand": "Renault", "model": "Clio", "year": 2019, "maxItems": 10}
   ```
5. Actor sayfasındaki adı not alın, ör. `kullaniciadi/yerimebak-arac-verisi`.

## Backend ayarı (sunucu `.env`)

```
APIFY_MODE=live
APIFY_TOKEN=...                 # Apify Console → Settings → API & Integrations
APIFY_ACTOR_ID=kullaniciadi~yerimebak-arac-verisi
```

Test için `APIFY_MODE=mock` kullanılır. Bu modda internete çıkılmaz, ücret oluşmaz; örnek veriler `musteri_paneli/tests/fixtures/apify` klasöründen gelir.

## Backend bu actor'ü ne zaman çağırır?

1. **Personel raporu gönderildiğinde:**
   - Müşterinin ilan linki sistemde yoksa önce o ilan çekilir (`ilan` modu).
   - Ardından o araç için güncel emsaller çekilir (`emsal` modu). Aynı araç için `APIFY_REFRESH_HOURS` (varsayılan 24 saat) içinde tekrar çekilmez.
   - Değerleme motoru temiz emsallerin değerinden personelin gerçek bulgularını düşer.
   - Satıcının ilandaki boya, değişen ve tramer beyanı ekspertiz bulgularıyla karşılaştırılır.
   - Tramerli veya ağır hasarlı emsaller "temiz emsal" sayılmaz.
2. **Müşteri değerleme ekranında link yapıştırdığında:** İlan sistemde yoksa çekilir ve bilgiler otomatik dolar.

Apify hata verirse veya zaman aşımına uğrarsa değerleme durmaz. Mevcut veriyle devam edilir ve sebep admin raporunda (`marketReference.emsalCekimi`) görünür.

## Notlar

- Emsal ilanlar veritabanına `status='emsal'` ile yazılır, vitrinde görünmez. Fiyat değişimleri `price_history`'de birikir.
- Maliyet: her çalıştırmanın kullanım bedeli (`usage_usd`) backend log'una ve `market_refresh` tablosuna yazılır.
- arabam.com'un kullanım koşulları otomatik veri çekmeyi kısıtlayabilir. Çekim sıklığını düşük tutun.
- Kazıyıcının sayfa seçicileri site tasarımı değişirse güncellenmelidir. İlk gerçek denemede çıktıyı kontrol edin.
