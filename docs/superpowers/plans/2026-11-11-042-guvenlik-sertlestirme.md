# 042 Güvenlik sertleştirme planı

**Şartname:** kök `kopru/codex_icin/042-guvenlik-sertlestirme.md`; taban `a0c02d7`.
**Amaç:** Eski oturumları şifre değişiminde iptal etmek, e-posta uçlarına paylaşımlı sınır koymak, belgeleri varsayılan kapatmak ve site başlıklarını eklemek.
**Mimari:** Startup'ta token_version ve e-posta kota şeması. JWT doğrulamada DB sürümü; istek yolunda DDL yok. E-posta kotaları HMAC anahtarlı PostgreSQL atomik sayaçları. CSP önce Report-Only. Render host değişikliği resmi sağlık kontrolü sözleşmesiyle değerlendirilir.

## İş adımları
- [x] Oturum servisi, reset/delete/personel reset ve istemci yeni-token işleme: kırmızı/yeşil testler. Panelde eski profil isteğinin 401 yanıtı yeni oturumu silmez; istemciler eski API yanıtıyla da uyumlu.
- [x] Startup token_version ve kota şemaları; docs varsayılan 404 / ortamla açık testleri.
- [x] Kayıt IP; forgot/resend IP+hesap kotaları, 429 ve süre/atomik yarış testleri; giriş koruması korundu. İki eski kota satırının kilit yarışı yeniden üretildi ve SKIP LOCKED ile giderildi.
- [x] Site başlıkları ve CSP Report-Only; dosya seçiciler/kamera incelemesi; 67 node testi, tsc, varsayılan next build, gerçek HTTP ve PayTR aynı kaynak iframe dönüşü geçti.
- [x] /ws kaldırıldı; snapshot search_path sabitlendi. Onrender host izni kaldırıldı; özel domain sağlık kontrolü geçti. Gerçek köken kimlik doğrulaması için canlı ayar notları yazıldı. Python 3.13 yerel freeze Docker 3.11 ile eşdeğer olmadığından sürüm kilitleme ertelendi.
- [x] Tam kapılar geçti: 1096 Python, 67 node/HTTP, tsc ve varsayılan Next build; panel analyze + 578 test, Android analyze + 147 test. Bağımsız incelemenin üç bulgusu regresyonla kapandı. Türkçe commitler, köprü raporu ve GUVENLIK_042 yayına alma kılavuzuyla teslim.

## İnceleme odağı
Geçiş JWT'si sadece DB0; hatalı tv tipleri; şifre/refresh yarışında iptal edilen sürümün canlanmaması; limiter çok işçide ve sahte forwarded başlıklarda tutarlı; e-posta var/yok bilgisinin korunması; şema yalnız startup; Render sağlık kontrolü ve IP güven sınırı; ödeme iframe ve inline scriptlerin kırılmaması.

## Sınırlar
.env okunmaz; canlı DB/hesap/yayın değişmez; Next ve giriş koruması geri alınmaz. Kök Claude dosyalarına kaynak değişikliği yok; yalnız ayrılmış iş kopyası. Bağımlılık değişikliği doğrulanmamış yerel sürümlerden körlemesine yapılmaz.
