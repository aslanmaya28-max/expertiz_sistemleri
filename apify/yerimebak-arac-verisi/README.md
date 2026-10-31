# YerimeBak araç verisi (Apify actor)

Müşterinin paylaştığı ilanı ve o araç için güncel emsal ilanları **arabam.com** ve **Borusan Next**'ten çeker.

Kazıyıcı kodu `musteri_paneli/yerimebak_ai_v5` içindeki kazıyıcının birebir kopyasıdır (`vendor/`). Kazıyıcıyı değiştirdikten sonra kopyayı güncelleyin:

```sh
python musteri_paneli/scripts/apify_sync.py
```

Kopya güncel değilse `tests/unit/test_apify.py` testi uyarır.

## Modlar

| Mod | Girdi | Çıktı |
|---|---|---|
| `ilan` | `url`: arabam.com veya borusannext.com ilan linki | Tek ilan: fiyat, km, yıl, paket, satıcının boya/değişen beyanı |
| `emsal` | `source` (arabam/borusan), `brand`, `model`, `year`, `yearWindow`, `maxItems` | Aynı marka/model için yıl ±`yearWindow` güncel ilanlar |

Çıktıdaki her kayıt aynı biçimdedir: `source, url, brand, model, package, year, km, price, fuel, transmission, paint_info, observed_at...`

## Apify'a kurulum (bir kez)

1. Apify Console → **Actors → Create new → Link Git repository**.
2. Git URL: `https://github.com/aslanmaya28-max/expertiz_sistemleri#main:apify/yerimebak-arac-verisi`
3. **Build** düğmesine basın. İlk derleme birkaç dakika sürer.
4. **Start** ile deneyin:
   ```json
   {"mode": "emsal", "source": "arabam", "brand": "Renault", "model": "Clio", "year": 2019, "maxItems": 10}
   ```
5. Actor sayfasındaki adı not alın, ör. `kullaniciadi/yerimebak-arac-verisi`.

## Backend ayarı (sunucu `.env`)

```
APIFY_MODE=live
APIFY_TOKEN=...                 # Apify Console → Settings → API & Integrations
APIFY_ACTOR_ID=kullaniciadi~yerimebak-arac-verisi
APIFY_SOURCES=arabam            # Borusan da eklenecekse: arabam,borusan
```

Test için `APIFY_MODE=mock` kullanılır. Bu modda internete çıkılmaz, ücret oluşmaz; örnek veriler `musteri_paneli/tests/fixtures/apify` klasöründen gelir.

## Backend bu actor'ü ne zaman çağırır?

1. **Personel raporu gönderildiğinde:**
   - Müşterinin ilan linki sistemde yoksa önce o ilan çekilir (`ilan` modu).
   - Ardından o araç için güncel emsaller çekilir (`emsal` modu). Aynı araç için `APIFY_REFRESH_HOURS` (varsayılan 24 saat) içinde tekrar çekilmez.
   - Değerleme motoru temiz emsallerin değerinden personelin gerçek bulgularını düşer.
   - Satıcının ilandaki beyanı ekspertiz bulgularıyla karşılaştırılır.
2. **Müşteri değerleme ekranında link yapıştırdığında:** İlan sistemde yoksa çekilir ve bilgiler otomatik dolar.

Apify hata verirse veya zaman aşımına uğrarsa değerleme durmaz. Mevcut veriyle devam edilir ve sebep admin raporunda (`marketReference.emsalCekimi`) görünür.

## Notlar

- Emsal ilanlar veritabanına `status='emsal'` ile yazılır, vitrinde görünmez. Fiyat değişimleri `price_history`'de birikir.
- Maliyet: her çalıştırmanın kullanım bedeli (`usage_usd`) backend log'una ve `market_refresh` tablosuna yazılır.
- arabam.com'un kullanım koşulları otomatik veri çekmeyi kısıtlayabilir. Çekim sıklığını düşük tutun.
- Kazıyıcının sayfa seçicileri site tasarımı değişirse güncellenmelidir. İlk gerçek denemede çıktıyı kontrol edin.
