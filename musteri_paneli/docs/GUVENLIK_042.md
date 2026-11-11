# 042 güvenlik değişikliklerinin yayına alınması

## Oturum geçişi

`users.token_version INTEGER NOT NULL DEFAULT 0` yalnız API açılış şemasında eklenir. Yeni yerel JWT'lerde `tv` bulunur; eski `tv` içermeyen JWT yalnız veritabanı sürümü 0 ise geçerlidir. Şifre değiştirme/sıfırlama, personel şifresi sıfırlama ve hesap silme sürümü artırır. Eski token hem normal API isteğinde hem yenilemede 401 alır.

Şifre değiştirme yanıtı artık `token` ve `token_type` içerir. Güncellenmiş panel ve Android istemcisi bu tokenı saklar. Site şifre değiştirme ucu çağırmıyor; bağlantılı şifre sıfırlama sonrası giriş yapılır.

Yayın sırası: önce yeni token yanıtını anlayan istemcileri yayımla, sonra API'yi yeniden başlat. İstemciler eski API'nin yalnız `success` döndüren yanıtıyla da çalışır. Eski kurulu Android sürümleri güncellenmezse şifre değişikliğinden sonra tekrar giriş gerekebilir; sunucu tarafındaki iptal bu istemciler için de geçerlidir. Açılış logunda şema kurulumunun başarılı olduğunu doğrula; istek yolunda bu yeni sütunu/tabloyu oluşturan DDL yoktur.

## Ortam değişkenleri

| Ad | Varsayılan | Açıklama |
|---|---|---|
| `ENABLE_API_DOCS` | kapalı | `/docs`, `/redoc`, `/openapi.json` yalnız `true`, `1`, `yes` ile açılır. Canlıda kapalı bırak. `app.openapi()` ile iç araçların şema üretmesi etkilenmez. |
| `KAYIT_IP_SINIRI` | 5 | IP başına saatlik kayıt denemesi. E-posta gönderilmeden önce tüketilir. |
| `EPOSTA_IP_SINIRI` | 10 | Şifre sıfırlama bağlantısı ve doğrulama tekrarında IP başına saatlik kota; iki işlem ayrı sayılır. |
| `EPOSTA_HESAP_SINIRI` | 3 | Aynı iki işlemde normalize e-posta başına saatlik kota; iki işlem ayrı sayılır. |

E-posta uçları `auth_mail_limits` tablosunu paylaşır. Hesap/IP anahtarları `SECRET_KEY` ile HMAC özetidir; düz kişisel veri saklanmaz. Tablo RLS açık, dış erişim politikası yoktur. 429 yanıtındaki `Retry-After` kalan pencereyi verir. Kota veritabanı hatasında e-posta gönderimi açılmaz: 503 döner. Mevcut giriş koruması ve `GIRIS_*` ayarları korunur.

## Site başlıkları ve ödeme

Tüm yollarda `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` ve kamera/mikrofon/konum izinlerini kapatan `Permissions-Policy` gönderilir. Fotoğraflar dosya seçiciden alınır; `getUserMedia`/`capture` kullanılmıyor.

`X-Frame-Options` genelde `DENY`; PayTR dönüş sayfası `/odeme/sonuc` için `SAMEORIGIN`. PayTR bu sayfayı ödeme iframe'inde döndürdüğünden genel DENY ödeme dönüşündeki üst pencereye çıkışı bozardı. Bu istisna üçüncü taraf sitelerin sayfayı çerçevelemesine izin vermez.

CSP **Report-Only**: Next ve JSON-LD satır içi betikleri henüz nonce/hash taşımıyor. `script-src 'self'` ihlalleri konsolda raporlanır, betikler engellenmez; bu aşama XSS engellemesi sağlamaz. Rapor toplama ucu eklenmedi. PayTR, API, Google Fonts kaynakları tanımlıdır. Sonraki adım nonce/hash desteği ve rapor alıcısını doğrulayıp CSP'yi uygulamaya geçirmek. Yeni Vercel ortam değişkeni gerekmez.

## Render / Cloudflare güven sınırı

Uygulama `*.onrender.com` Host'una artık varsayılan izin vermez. `api.yerimebak.com.tr` ve yerel/Docker host'ları korunur. Render belgelerine göre doğrulanmış özel alan adı varsa HTTP sağlık kontrollerinde o alan adı Host olarak gönderilir. Bu koşul mevcut API alan adı için Render panelinden doğrulanmalı; özel domain henüz kurulmamış yeni bir Render servisi önce domain yapılandırılmadan bu ayarla açılmamalıdır.

**Host kontrolü Cloudflare'den gelindiğinin kanıtı değildir.** Doğrudan kökene ulaşabilen istemci Host ve `CF-Connecting-IP` gibi başlıkları taklit edebilir. Dolayısıyla yalnız bu kod değişikliğiyle IP kotasının bütün köken erişimlerinde güvenilir hale geldiği iddia edilmez. Hesap anahtarlı sınırlar bundan bağımsızdır.

Claude'un canlıda yapacağı işler:

1. Render'da `api.yerimebak.com.tr` özel domain'inin doğrulandığını ve `/health` kontrolünün sağlıklı olduğunu doğrula.
2. Custom Domains → Render Subdomain ayarını **Disabled** yap; alternatif Blueprint alanı `renderSubdomainPolicy: disabled` (en az bir özel domain gerekir). `onrender.com` yanıtları uygulamaya ulaşmadan 404 olmalı.
3. `EXTRA_ALLOWED_HOSTS` ile `onrender.com` iznini yeniden ekleme. Render'daki `CLIENT_IP_HEADERS` ayarının mevcut Blueprint'teki Cloudflare sırasıyla eşleştiğini kontrol et; güvenilmeyen `X-Real-IP`'yi öne alma.
4. Özel domain Host'u ile kökene doğrudan erişimi de engellemek için Cloudflare-köken arasında kimliği doğrulanan bir sınır kur: ağ erişim listesi/uygun platform özelliği veya Cloudflare'in üzerine yazdığı ve kökenin doğruladığı gizli başlık. Yalnız DNS turuncu bulutuna veya Host adına güvenme. Bu oturum platform ayarı, anahtar veya canlı köken politikası değiştirmedi.

Kaynaklar: [Render sağlık kontrolü Host davranışı](https://render.com/docs/health-checks), [Render alt alan adını kapatma](https://render.com/docs/custom-domains#disabling-your-onrendercom-subdomain), [Blueprint alanı](https://render.com/docs/blueprint-spec#rendersubdomainpolicy), [Cloudflare kökeni koruma](https://developers.cloudflare.com/fundamentals/security/protect-your-origin-server/).

## Düşük öncelikli değişiklikler

Kaldırılmış vitrin için kullanılan `/ws` uç noktası kaldırıldı; site/panel/Android kaynaklarında kullanan istemci bulunmadı. Değerleme snapshot tetikleyicisi işlevine `SET search_path = public` eklendi; tetikleyici davranışı değişmedi.

`requirements.txt` bu görevde körlemesine sabitlenmedi. Yerel ortam Python 3.13.8, Docker/Render imajı 3.11-slim; yerelde `google-auth` geliştirme sürümü, eksik `sentry-sdk` ve birlikte kurulu PyFPDF/fpdf2 bulundu. Doğrulanmış çalışan sürüm listesi yerine bu karışık freeze'i üretime taşımak yeni risk yaratır. Temiz Python 3.11 imajında üretim bağımlılıkları kurulup tüm testler çalıştıktan sonra kilit dosyası üretmek ayrı iş olarak ele alınmalı.
