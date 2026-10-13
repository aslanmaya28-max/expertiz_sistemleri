# YerimeBak — Canlıya Çıkış Rehberi (www.yerimebak.com.tr)

Müşteri sitesi ve admin paneli **Vercel**'de çalışır. API, veritabanı ve kazıyıcılar ise **bir sunucuda** Docker Compose ile çalışır. Sunucuda dışarıya yalnızca nginx (80/443) açılır.

| Adres | Nerede | Servis |
|---|---|---|
| https://www.yerimebak.com.tr | Vercel | Müşteri sitesi (Next.js) — ana adres |
| https://yerimebak.com.tr | Vercel | → www yönlendirmesi |
| https://admin.yerimebak.com.tr | Vercel | Flutter admin / personel paneli |
| https://api.yerimebak.com.tr | Sunucu | FastAPI + PostgreSQL + Redis + kazıyıcılar |

> İstenirse her şey tek sunucuda da çalışır: `.env` içine `COMPOSE_PROFILES=tek-sunucu` ve `NGINX_CONF=nginx.conf` yazılır, sertifika `tek` moduyla alınır (bkz. 3).

## 1. DNS (METUnic → yerimebak.com.tr → DNS Kayıtları)

| Ad | Tür | Değer |
|---|---|---|
| `@` | A | Vercel'in verdiği IP (Vercel → Project → Domains) |
| `www` | CNAME | Vercel'in verdiği CNAME |
| `admin` | CNAME | Vercel'in verdiği CNAME |
| `api` | A | API sunucusunun IP adresi |

## 1b. Vercel projeleri

| Proje | Kök klasör | Ortam değişkenleri |
|---|---|---|
| `yerimebak-site` | `musteri_paneli/frontend` | `NEXT_PUBLIC_API_BASE_URL=https://api.yerimebak.com.tr/api/v1`, `API_BACKEND_URL=https://api.yerimebak.com.tr`, `COMPANY_*` |
| `yerimebak-admin` | `expertiz_paneli` | `YERIMEBAK_API_BASE_URL=https://api.yerimebak.com.tr/api/v1` |

- **Admin projesi:** Flutter SDK'yı derleme sırasında kendisi indirir (`scripts/vercel_build.sh`, ayarlar `vercel.json`'da).
- **Otomatik yayın:** Her iki proje de GitHub'a bağlı; `main` dalına her push otomatik yayınlanır.
- **Değişkenler:** `NEXT_PUBLIC_*` ve `YERIMEBAK_API_BASE_URL` derlemeye gömülür. Değiştirince yeniden yayınlamak (Redeploy) gerekir.

## 1c. API sunucusu

- Ubuntu 22.04+ / Debian 12, en az 2 vCPU · 4 GB RAM · 40 GB disk (ör. Hetzner CX22).
- Docker Engine + Compose eklentisi kurulu olmalı.
- Güvenlik duvarında yalnızca 22, 80 ve 443 açık olmalı.

## 2. Ortam değişkenleri

```sh
cd musteri_paneli
cp .env.example .env
```

Doldurulması **zorunlu** alanlar:

| Değişken | Açıklama |
|---|---|
| `POSTGRES_PASSWORD`, `DATABASE_URL` | Güçlü, rastgele şifre (iki yerde aynı) |
| `SECRET_KEY` | `openssl rand -hex 32` |
| `INITIAL_ADMIN_EMAIL`, `INITIAL_ADMIN_PASSWORD` | İlk admin hesabı (bkz. 5) |
| `PAYTR_MERCHANT_ID/KEY/SALT` | PayTR mağaza paneli → Bilgi |
| `PAYMENT_SIMULATION=false` | Canlıda **mutlaka** false |
| `PAYTR_TEST_MODE=0` | PayTR mağazası canlı onaylandıktan sonra 0 |
| `SMTP_*`, `SMTP_FROM` | E-posta doğrulama, şifre sıfırlama, makbuz ve bildirimler için |
| `ADMIN_NOTIFY_EMAIL` | Yeni ödenmiş talep bildirimlerinin gideceği adres |
| `COMPANY_*` | Şirket unvanı, adres, vergi dairesi/no, MERSİS, telefon, KEP — yasal sayfalarda ve mesafeli satış sözleşmesinde gösterilir |

İsteğe bağlı: `SENTRY_DSN` (hata izleme), `OFFSITE_PATH` + `RCLONE_CONFIG_OFFSITE_*` (sunucu dışı yedek).

> `COMPANY_*` değerleri müşteri sitesinde gösterilir. Vercel kullanılıyorsa bunlar Vercel projesine (`yerimebak-site`) girilir, sunucu `.env`'ine değil.

## 3. İlk kurulum ve SSL

nginx sertifika olmadan açılamaz. Bu yüzden ilk sertifika betikle alınır:

```sh
docker compose build
sh scripts/ilk_sertifika.sh info@yerimebak.com.tr api   # Vercel kurulumu: yalnızca api.yerimebak.com.tr
# sh scripts/ilk_sertifika.sh info@yerimebak.com.tr tek  # her şey tek sunucuda
```

Betik şunları yapar:

1. nginx'i durdurur.
2. certbot'u standalone modda çalıştırıp sertifika alır (`api` modunda yalnızca api.yerimebak.com.tr).
3. Tüm servisleri başlatır.

Yenileme `certbot` servisiyle otomatik yapılır (12 saatte bir kontrol). nginx 6 saatte bir yeniden yüklenir.

Kontrol:

```sh
docker compose ps
curl https://api.yerimebak.com.tr/health
curl -I https://www.yerimebak.com.tr
```

## 4. PayTR ayarları

PayTR Mağaza Paneli → Ayarlar:

- **Bildirim URL**: `https://api.yerimebak.com.tr/api/v1/payments/paytr/callback`
- Başarılı / başarısız dönüş adresleri `.env` içindeki `PAYTR_OK_URL` / `PAYTR_FAIL_URL` ile aynı olmalı.
- İade (admin → İptal / İade ve kredi paketi iadesi) PayTR iade API'sini kullanır. Mağazada iade yetkisi açık olmalı.

## 5. İlk admin hesabı

`.env` içine admin e-postası ve şifresi yazılır. Uygulama açılırken bu e-postada hesap yoksa admin hesabını oluşturur:

```
INITIAL_ADMIN_EMAIL=admin-epostaniz@ornek.com
INITIAL_ADMIN_PASSWORD=<en az 8 karakter, büyük + küçük harf + rakam>
```

`docker compose up -d app` sonrası https://admin.yerimebak.com.tr adresinden giriş yapılır. Log'da `Ilk admin hesabi olusturuldu` satırı görülür.

Hesap oluştuktan sonra:

- Şifreyi panelden (Ayarlar → Şifre Değiştir) değiştirin.
- İki satırı `.env` içinden silin. Hesap silinmez.
- Var olan bir hesabın şifresi bu yolla değişmez.

Sonraki adımlar https://admin.yerimebak.com.tr üzerinden yapılır:

- **Personel**: yeni personel eklenir. İlk girişte şifresini değiştirmesi istenir.
- **Fiyatlandırma**: kurumsal ekspertiz firmaları ve fiyatları girilir.
- **Piyasa Verisi**: kazıyıcılar (arabam / Borusan) buradan başlatılıp durdurulur. Kazıyıcılar otomatik başlamaz.

## 6. Yedekleme

- `backup` servisi her gün PostgreSQL dökümü alır. Dökümler `./data/backups` altında 14 gün saklanır.
- Sunucu dışı kopya için `.env` içinde rclone ayarlarını doldurup şunu çalıştırın:
  ```sh
  docker compose --profile offsite up -d offsite-backup
  ```
  Bu servis saatte bir veritabanı yedeklerini ve medya dosyalarını uzak depoya eşitler.
- Geri yükleme:
  ```sh
  gunzip -c data/backups/<dosya>.sql.gz | docker compose exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB"
  ```

## 7. Güncelleme

```sh
git pull
docker compose up -d --build
```

Veritabanı şeması uygulama açılışında otomatik güncellenir.

## 8. Kod dışı yapılacaklar (canlı öncesi)

- [ ] Yasal metinler (KVKK, gizlilik, kullanım koşulları, mesafeli satış, iptal/iade) avukata kontrol ettirilmeli.
- [ ] e-Arşiv fatura için bir entegratör (GİB özel entegratör) seçilmeli. O zamana kadar Finans → **Fatura CSV** dökümü muhasebeye verilir.
- [ ] PayTR mağaza başvurusu canlıya alınmalı. Gerçek kartla küçük tutarlı ödeme + iade testi yapılmalı.
- [ ] SMTP hesabı (ör. kurumsal e-posta / Brevo / SES) açılmalı. SPF ve DKIM kayıtları eklenmeli.
- [ ] Kurumsal ekspertiz firmalarının fiyatları admin panelinden girilmeli.
- [ ] SMS ile doğrulama istenirse bir SMS sağlayıcısı (Netgsm, İleti Merkezi vb.) seçilmeli. Şu an doğrulama e-posta ile yapılıyor.

## 9. Kapasite ve hız

Yük testi k6 ile yapıldı: 20.813 ilanlık veritabanı, 4 vCPU. Yük aracı da aynı makinede çalıştı.

**Senaryo:** Kullanıcı ortalama 5 saniyede bir tıklıyor. İsteklerin dağılımı:
- %40 vitrin sayfası
- %20 marka filtresi
- %20 rastgele araç detayı
- %20 istatistik / marka listesi

| Eşzamanlı kullanıcı | İstek/sn | Ortanca | %95 | Hata |
|---|---|---|---|---|
| 5.000 | 818 | 0,7 ms | 8 ms | %0 |
| 10.000 | 1.327 | 102 ms | 2,3 sn | %0 (makine dolu; yük aracı tek başına 1 çekirdek kullanıyor) |

Optimizasyon öncesi (tek işlem, önbelleksiz) 1.000 kullanıcıda ortanca yanıt 2 saniyeydi.

**Hızı sağlayanlar:**
- **nginx önbelleği:** Herkese açık vitrin istekleri 30 saniye önbellekte tutulur, Python'a gitmez. Giriş yapmış kullanıcıda önbellek kapalıdır.
- **Redis önbelleği:** Araç detayı (60 sn), liste (120 sn), istatistik ve marka listesi (300 sn).
- **Çoklu çalışan:** `WEB_CONCURRENCY` ayarı ve uvloop. Güvenlik katmanı saf ASGI'ye çevrildi. İstek başına işlemci maliyeti yaklaşık 3 kat düştü.
- **Tek AI taraması:** Çok işlemde kurtarma taramasını PostgreSQL kilidiyle yalnızca bir işlem yapar.
- **Görsel optimizasyonu kapalı:** Vercel'de ilan görselleri doğrudan kaynak CDN'den gelir; kota/ücret aşımı olmaz.

**Sunucu boyutu önerisi:**

| Beklenen eşzamanlı kullanıcı | Sunucu (Hetzner) | Ayar |
|---|---|---|
| ~1.000'e kadar | CX23 (2 vCPU, 4 GB) | `WEB_CONCURRENCY=2` |
| ~5.000 | 4 vCPU / 8 GB (CPX31 veya CCX13) | `WEB_CONCURRENCY=4` |
| ~10.000 | 8 vCPU / 16 GB (CPX51 veya CCX33) | `WEB_CONCURRENCY=8` |

- Hetzner'de sunucu büyütme (Rescale) birkaç dakikalık kesintiyle yapılır. Veriler korunur.
- Kazıyıcılar Chromium çalıştırır ve yoğun işlemci kullanır. Yoğun saatlerde çalıştırmayın veya ayrı küçük bir sunucuya taşıyın.
- Vercel'in ücretsiz Hobby planı ticari kullanıma izin vermez. Canlıda **Pro** plan gerekir.
