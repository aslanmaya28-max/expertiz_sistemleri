# YerimeBak — Canlıya Çıkış Rehberi (yerimebak.com.tr)

Tek sunucu, Docker Compose. Dışarıya yalnızca nginx (80/443) açılır.

| Adres | Servis |
|---|---|
| https://yerimebak.com.tr | Müşteri sitesi (Next.js) + `/api/v1` (FastAPI) |
| https://www.yerimebak.com.tr | → yerimebak.com.tr yönlendirmesi |
| https://admin.yerimebak.com.tr | Flutter admin / personel paneli + `/api/v1` |

## 1. Sunucu ve DNS

- Ubuntu 22.04+ / Debian 12, en az 2 vCPU · 4 GB RAM · 40 GB disk.
- Docker Engine + Compose eklentisi kurulu olmalı.
- DNS'te üç A kaydı da sunucu IP'sine gitmeli: `yerimebak.com.tr`, `www`, `admin`.
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

> `COMPANY_*` değerleri çalışma anında okunur; değiştirdikten sonra `docker compose up -d frontend` yeterlidir.

## 3. İlk kurulum ve SSL

nginx sertifika olmadan açılamaz. Bu yüzden ilk sertifika betikle alınır:

```sh
docker compose build
sh scripts/ilk_sertifika.sh info@yerimebak.com.tr
```

Betik şunları yapar:

1. nginx'i durdurur.
2. certbot'u standalone modda çalıştırıp üç alan adı için tek sertifika alır.
3. Tüm servisleri başlatır.

Yenileme `certbot` servisiyle otomatik yapılır (12 saatte bir kontrol). nginx 6 saatte bir yeniden yüklenir.

Kontrol:

```sh
docker compose ps
curl -I https://yerimebak.com.tr
curl https://yerimebak.com.tr/health
```

## 4. PayTR ayarları

PayTR Mağaza Paneli → Ayarlar:

- **Bildirim URL**: `https://yerimebak.com.tr/api/v1/payments/paytr/callback`
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
