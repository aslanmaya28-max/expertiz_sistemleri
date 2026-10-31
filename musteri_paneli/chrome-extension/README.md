# YerimeBak Chrome eklentisi

## arabam.com ilanlarını sisteme kaydetme

arabam.com, sunuculardan (Apify dahil) gelen otomatik istekleri Cloudflare ile engeller. Bu yüzden ilan verisi personelin kendi tarayıcısında açtığı sayfadan alınır. Eklenti sayfada gezinmez, başka sayfa açmaz; yalnızca açık sayfanın metnini sunucuya gönderir. Ayrıştırma sunucuda, Apify actor'üyle aynı kodla yapılır (`yerimebak_ai_v5/services/extension_ingest.py`).

Yalnızca **admin** ve **personel** hesapları kullanabilir; işlem kredi düşmez.

| Açık sayfa | Düğme | Kaydedilen |
|---|---|---|
| İlan sayfası (`arabam.com/ilan/...`) | İlanı sisteme kaydet | Fiyat, km, yıl, paket, yakıt, vites, renk, boya/değişen ve tramer beyanı (`status='talep'`) |
| Arama sonuçları | Sayfadaki ilanları emsal kaydet | Görünen ilanların fiyat, km ve yılı (`status='emsal'`; boya bilgisi aramada yoktur) |

Kaydedilen ilan, müşteri talebinde ve personel raporunda link eşleşince otomatik kullanılır (satıcı beyanı ile ekspertiz karşılaştırması dahil).

## Kurulum

1. Chrome → `chrome://extensions` → sağ üstten **Geliştirici modu**nu açın.
2. **Paketlenmemiş öğe yükle** → bu `chrome-extension` klasörünü seçin.
3. Eklenti simgesine tıklayın; sunucu adresi (`https://api.yerimebak.com.tr`) ve hesabınızın API anahtarıyla giriş yapın.

Sunucuda `APIFY_MODE=mock` (veya boş) kalabilir; bu akış Apify'a ihtiyaç duymaz.
