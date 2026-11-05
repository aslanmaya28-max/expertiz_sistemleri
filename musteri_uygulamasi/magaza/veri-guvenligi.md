# Veri güvenliği — Console cevapları

5 Kasım 2026 kod incelemesine göre hazırlanmıştır. Kapsam: bu Android sürümü; web sitesindeki farklı akışlar otomatik olarak bu sürümün özelliği sayılmaz. Formu göndermeden önce üretim sunucusunun fiilî saklama/sağlayıcı sözleşmelerini ve gizlilik metnini bu envanterle eşleştirin.

## Genel cevaplar

- Kullanıcı verisi toplanıyor/paylaşılıyor mu? **Evet.**
- Aktarım sırasında şifreleme? **Evet:** release API HTTPS zorunlu; Google Play trafiği kendi güvenli bağlantısını kullanır. Kullanıcının açtığı üçüncü taraf ilan sayfasının adresi ayrı bir WebView bağlantısıdır.
- Hesap oluşturma: e-posta ve parola; kayıt sırasında ad, soyad ve telefon. Sosyal giriş yok.
- Hesap silme: Profil → Hesabımı sil → mevcut şifre ve açık onay. Web başvuru adresi: https://yerimebak.com.tr/hesap-silme.
- Silme kapsamı: iletişim bilgileri anonimleştirilir, oturum kapatılır, kullanılmayan kredi sıfırlanır; muhasebe kayıtları yasal saklama için, raporlar iletişim alanları anonimleştirilerek tutulur. “Her veri anında ve tamamen silinir” demeyin.
- Bağımsız güvenlik incelemesi/sertifika: **Hayır** (gerçek bir bağımsız sertifika yok).

## Veri türleri

| Console veri türü | Toplanma | Amaç | Zorunluluk / işleme |
|---|---|---|---|
| Kişisel bilgiler → Ad | Evet | Hesap yönetimi, uygulama işlevleri | Kayıtta zorunlu; sunucuda saklanır |
| Kişisel bilgiler → E-posta adresi | Evet | Hesap yönetimi, doğrulama/şifre sıfırlama iletişimi, güvenlik | Zorunlu; sunucuda saklanır |
| Kişisel bilgiler → Telefon numarası | Evet | Hesap yönetimi, uygulama işlevleri | Kayıtta istenir; sunucuda saklanır |
| Kişisel bilgiler → Kullanıcı kimlikleri | Evet | Hesap yönetimi, güvenlik, satın almayı hesaba bağlama | Oturum ve Play için bulanıklaştırılmış hesap kimliği; saklanır |
| Finansal bilgiler → Satın alma geçmişi | Evet | Uygulama işlevleri, sahtekârlığı önleme, hesap yönetimi | Kredi satın alınırsa; ürün/satın alma doğrulaması ve kredi hareketleri saklanır |
| Uygulama etkinliği → Kullanıcı tarafından oluşturulan diğer içerikler | Evet | Uygulama işlevleri | Araç bilgileri, ilan linki/metni, hasar/kaporta beyanı ve üretilen rapor; analiz isteğe bağlı, sonuç sunucuda saklanır |
| Cihaz veya diğer kimlikler | Evet | Güvenlik, kötüye kullanımı önleme | API ağ kayıtlarında IP; Google Play satın alma doğrulama kimlikleri. Reklam kimliği SDK'sı yok |

Parola kimlik doğrulama amacıyla sunucuya gider, uygulamada kaydedilmez; sunucuda parola özeti saklanır. Kart numarası/banka hesabı uygulamada toplanmaz; ödemeyi Google Play alır. Hassas konum, kamera, rehber, mikrofon, fotoğraf galerisi, sağlık, reklam kimliği veya reklam/analitik SDK'sı bu sürümde yoktur. Uygulama içi bildirim/push SDK'sı yoktur.

## Aktarım ve “paylaşım” alanı

- YerimeBak API'si: hesap, araç/ilan, analiz, satın alma doğrulaması ve rapor işlemleri; birinci taraf sunucu.
- OpenRouter ve seçilen model sağlayıcısı: ilan linki/metni ve araç analizi girdileri işlenir. Kullanıcının yapıştırdığı ilan metni kişisel bilgi içerebilir; “hiç kişisel veri gitmez” beyanı verilmemelidir. Sunucunun model istemi rapor üretmek içindir; hesaba ait parola modele gönderilmez.
- Google Play: ürün/satın alma bilgileri ve bulanıklaştırılmış hesap kimliği; ödeme ve satın alma doğrulama. Kullanıcı başka uygulamaya kopyala/paylaş düğmesini kullanırsa seçtiği içerik kullanıcı eylemiyle aktarılır.
- Üçüncü taraf ilan sitesi: ilan okuma için WebView isteği; site IP/çerez gibi bilgileri kendi politikasına göre işleyebilir. Reklam izleme amacıyla SDK kurulmaz.

Console'daki “paylaşılıyor” tanımı, hizmet sağlayıcı istisnasını her aktarım için otomatik kabul etmez. Üretim sözleşmeleri doğrulanmadığından OpenRouter/model sağlayıcısına iletilen kullanıcı içeriğini **paylaşılıyor / uygulama işlevleri** olarak beyan edin. İlan metnine gömülü ad/telefon/e-posta için de paylaşımı açıklayın. Hizmet sağlayıcı istisnası ancak gerçek sözleşme ve kullanım koşulları doğrulanırsa uygulanabilir. Google Play'in kendi topladığı ödeme verisini uygulamanın kart toplaması olarak işaretlemeyin.

“Yalnız geçici işleniyor” seçeneğini saklanan hesap/rapor/satın alma verileri için **Hayır** seçin. İncelenen kod yalnız cihaz içi işlem yapmıyor; model sağlayıcısının saklama şartları doğrulanmadan “sıfır saklama” vaadi vermeyin.

## Kod kanıtları ve kaynak

- `lib/oturum/token_store.dart`: oturum flutter_secure_storage içinde; `android:allowBackup=false`, dosya/cihaz aktarımı dışlamaları.
- `lib/analiz/analiz_api.dart`, `lib/analiz/arac_formu.dart`: ilan ve analiz girdileri.
- `lib/kredi/satin_alma.dart`: Play satın alımı → API doğrulaması.
- Sunucu `services/listing_extract.py`, `services/valuation_service.py`, `services/payment_service.py`, hesap silme ucu.
- [Google veri güvenliği tanımları](https://support.google.com/googleplay/android-developer/answer/10787469?hl=tr).
