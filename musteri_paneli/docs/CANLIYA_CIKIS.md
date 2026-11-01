# YerimeBak — Canlıya Çıkış Rehberi

Sunucu kiralamak, Docker veya nginx kurmak gerekmez. Üç hizmet kullanılır, üçü de GitHub'a bağlıdır ve `main` dalına her gönderimde kendiliğinden güncellenir.

| Adres | Hizmet | Ne çalışır |
|---|---|---|
| https://www.yerimebak.com.tr | Vercel | Müşteri sitesi (Next.js) |
| https://admin.yerimebak.com.tr | Vercel | Admin ve personel paneli (Flutter) |
| https://api.yerimebak.com.tr | Render | API ve yapay zekâ değerlemesi |
| — | Supabase | Veritabanı (PostgreSQL) ve dosyalar (fotoğraf, kurumsal rapor) |

**Aylık maliyet (yaklaşık):**
- Render Starter: 7 $
- Supabase: test için ücretsiz, canlıda Pro 25 $ (ücretsiz plan bir hafta işlem olmazsa projeyi duraklatır ve otomatik yedek almaz)
- Vercel Pro: 20 $ (ücretsiz plan ticari kullanıma izin vermez)
- OpenRouter: rapor başına yaklaşık 0,03 $

## 1. Supabase

1. https://supabase.com → **New project**. Bölge: **Central EU (Frankfurt)**. Veritabanı şifresini güçlü seçip bir yere kaydedin.
2. **Connect** → **Session pooler** adresini kopyalayın (port **5432**). Bu, Render'daki `DATABASE_URL` değeri olacak. Şifre yerine 1. adımdaki şifreyi yazın, sonuna `?sslmode=require` ekleyin:
   ```
   postgresql://postgres.<proje>:<şifre>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
   ```
   > **Transaction pooler (6543) kullanmayın.** Arka plandaki yapay zekâ işleyicisi oturum kilidi kullanıyor, transaction pooler bunu bozar.
3. **Storage** → **New bucket**. Ad: `report-media`. **Public bucket kapalı** kalsın (dosyalar yalnızca API'nin imzalı bağlantısıyla açılır).
4. **Project Settings → API** bölümünden **Project URL** (`SUPABASE_URL`) ve **service_role** anahtarını (`SUPABASE_SERVICE_ROLE_KEY`) alın. service_role anahtarı tam yetkilidir: yalnızca Render'a girilir, sitede ya da kodda kullanılmaz.

Tablolar uygulama ilk açıldığında kendiliğinden oluşur.

## 2. Render (API)

1. https://render.com → GitHub ile giriş → **New + → Blueprint** → `expertiz_sistemleri` deposu. Render kök klasördeki `render.yaml` dosyasını okur.
2. Sorulan gizli değerleri girin:

| Değişken | Nereden |
|---|---|
| `DATABASE_URL` | Supabase session pooler adresi (1.2) |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Supabase API ayarları (1.4) |
| `OPENROUTER_API_KEY` | https://openrouter.ai/keys |
| `INITIAL_ADMIN_EMAIL`, `INITIAL_ADMIN_PASSWORD` | İlk admin hesabı (en az 8 karakter, büyük + küçük harf + rakam) |
| `PAYTR_MERCHANT_ID/KEY/SALT` | PayTR mağaza paneli → Bilgi |
| `SMTP_HOST/USER/PASSWORD/FROM`, `ADMIN_NOTIFY_EMAIL` | E-posta hizmeti (ör. kurumsal e-posta, Brevo) |
| `SENTRY_DSN` | İsteğe bağlı, hata izleme |

`SECRET_KEY` ve `MEDIA_SIGNING_KEY` Render tarafından rastgele üretilir.

3. İlk yayın bitince kontrol edin: `https://yerimebak-api.onrender.com/health` → `{"status":"ok"}`. Kayıtlarda (Logs) `Ilk admin hesabi olusturuldu` satırı görülür.
4. **Settings → Custom Domains** → `api.yerimebak.com.tr` ekleyin. Render'ın gösterdiği CNAME değerini DNS'e girin (bkz. 4).

İlk admin hesabı oluştuktan sonra panelden şifreyi değiştirin, `INITIAL_ADMIN_*` değişkenlerini Render'dan silin.

## 3. Vercel (site ve panel)

| Proje | Kök klasör | Ortam değişkenleri |
|---|---|---|
| `yerimebak-site` | `musteri_paneli/frontend` | `NEXT_PUBLIC_API_BASE_URL=https://api.yerimebak.com.tr/api/v1`, `API_BACKEND_URL=https://api.yerimebak.com.tr`, `COMPANY_*` |
| `yerimebak-admin` | `expertiz_paneli` | `YERIMEBAK_API_BASE_URL=https://api.yerimebak.com.tr/api/v1` |

Bu değişkenler derlemeye gömülür; değiştirirseniz **Redeploy** gerekir.

## 4. DNS (METUnic → yerimebak.com.tr → DNS Kayıtları)

| Ad | Tür | Değer |
|---|---|---|
| `@` | A | Vercel'in verdiği IP |
| `www` | CNAME | Vercel'in verdiği değer |
| `admin` | CNAME | Vercel'in verdiği değer |
| `api` | CNAME | Render'ın verdiği değer (ör. `yerimebak-api.onrender.com`) |

SSL sertifikalarını Vercel ve Render kendisi alır ve yeniler.

## 5. PayTR

- Mağaza paneli → Ayarlar → **Bildirim URL**: `https://api.yerimebak.com.tr/api/v1/payments/paytr/callback`
- Mağaza canlıya alınana kadar `PAYTR_TEST_MODE=1`, sonra Render'da `0` yapın.
- İade için mağazada iade yetkisi açık olmalı.

## 6. Yayından sonra kontrol listesi

- [ ] Müşteri olarak kayıt ol, e-postayı doğrula.
- [ ] İlan linkiyle ekspertiz talebi aç, PayTR test kartıyla öde.
- [ ] Admin: talebi personele ata.
- [ ] Personel: raporu doldur, fotoğraf ve kurumsal PDF yükle, gönder.
- [ ] Admin → Raporlar: yapay zekâ değerlemesi, kaynak ilanlar ve "kontrol gerekli" uyarıları geliyor mu; gerekiyorsa piyasa değerini düzelt; onayla.
- [ ] Müşteri panelinde 4 rapor ve fotoğraflar açılıyor mu.
- [ ] Render'ı yeniden başlat (Manual Deploy) → fotoğraflar hâlâ açılıyor mu (Supabase Storage çalışıyor demektir).
- [ ] İptal / iade akışını dene.
- [ ] Render Logs'ta hız sınırı kayıtlarındaki IP'ler gerçek ziyaretçi IP'si mi (değilse `CLIENT_IP_HEADERS` ayarı).

## 7. Yedekleme

- Supabase Pro günlük yedek alır (7 gün geri dönüş).
- Ek güvence için ayda bir yerel döküm: `pg_dump "<DATABASE_URL>" | gzip > yedek-$(date +%F).sql.gz`

## 8. Kod dışı yapılacaklar

- [ ] Yasal metinler (KVKK, gizlilik, kullanım koşulları, mesafeli satış, iptal/iade) avukata kontrol ettirilmeli.
- [ ] e-Arşiv fatura entegratörü seçilmeli. O zamana kadar Finans → **Fatura CSV** dökümü muhasebeye verilir.
- [ ] PayTR mağazası canlıya alınmalı. Gerçek kartla küçük tutarlı ödeme ve iade denenmeli.
- [ ] SMTP hesabında SPF ve DKIM kayıtları eklenmeli.
- [ ] Kurumsal ekspertiz firmalarının fiyatları admin panelinden girilmeli.

## Eski kurulum

Docker Compose, nginx ve kazıyıcılı eski kurulum `git tag arsiv/docker-surum` etiketinde duruyor.
