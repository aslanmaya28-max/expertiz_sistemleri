# Tamamlanmış ekspertizden DeepSeek destekli değerleme

Tarih: 30 Ekim 2026. Durum: kullanıcı incelemesine hazırlanmış tasarım;
ürün kodu uygulanmadı.

## Kullanıcının kesinleştirdiği kapsam

- Yalnız personelin tamamlayıp gönderdiği ekspertiz raporu işlenir.
- Boya, değişen, hasar kaydı ve kilometre etkileri benzer temiz araçların
  güncel emsal değerinden hesaplanır; ilan fiyatıyla ayrıca karşılaştırılır.
- Geçmiş 6/12 aylık fiyat değişimi ile gelecek 6/12 ay için düşük, orta,
  yüksek senaryolar aynı raporda gösterilir.
- DeepSeek sunucuda arka planda çalışır. Sonuç admin kontrolü/onayı ardından
  müşteri paneline açılır; AI analizi zorunluluğu korunur.
- İnceleme öncesi bağımsız/kredi karşılığı değerleme sonraki iştir.

## Yaklaşım ve mevcut temel

Mevcut FastAPI, PostgreSQL, emsal servisi ve saf Python ekspertiz hesaplama
motoru korunur. Merkezi worker'a doğrulanmış DeepSeek değerlendirmesi ve
tarihli piyasa senaryoları eklenir. Tek resmi çıktı ve ortak API kullanılır.

Konuşmada önerilen yaklaşım: veri/hesaplama temeli üzerinde DeepSeek.
Yalnız dil modelinden fiyat istemek kaynak ve tekrar üretilebilirlik sağlamaz.
Mevcut kural motorunu tek başına kullanmak ise istenen DeepSeek katmanını
karşılamaz. Kullanıcının seçtiği ürün kapsamı yukarıdadır; teknik sınırlar
ve aşağıdaki varsayımlar uygulayıcı önerisidir.

Kaynak noktaları:
- workers/ai_analysis_worker.py: emsal → evaluate → adapter → write_ai_results.
- core/market/market_reference_service.py: emsal seçimi; emsal yokken ilan
  fiyatının %97'sini referans sayan fallback resmi akışta reddedilecek.
- core/ai/inspection_valuation.py: bulgu/değer kaybı hesabı.
- core/ai/ai_result_adapter.py: resmi rapor biçimi; bazı mevcut projeksiyon
  alanları sıfır. Eksik veri sıfır getiri gibi gösterilmeyecek.
- services/valuation_service.py: ayrı kredi akışındaki aylık oranla bileşik
  projeksiyon örneği. Bu müşteri ürünü bu işte açılmayacak/değiştirilmeyecek.
- services/expertiz_service.py: resmi AI + pending_admin yayın kapısı.
- core/infrastructure/supabase_bridge.py: merkezi PostgreSQL rapor erişimi;
  dosya adı tek başına Supabase hizmetine yeni geçiş anlamına gelmez.

## Bugünkü değerleme

1. Rapor revizyonu ve normalize araç özellikleri sabitlenir. Marka/model,
   paket, yıl, yakıt/şanzıman, km, boya/değişen/hasar bulguları alınır.
   Bilinmeyen alanlar temiz/hasarsız kabul edilmez; çelişkili bulgu admine döner.
   İlk sürüm yapılandırılmış, personel/admin tarafından doğrulanmış bulguları
   kullanır. Yalnız fotoğraf veya PDF içinde kalan kritik kurumsal bulgular
   işlenmiş kabul edilmez; ilgili alanlara doğrulanarak aktarılmadan değerleme
   tamamlanmaz. Otomatik görsel/PDF yorumlama ayrı kapsamdır.
2. Aynı aracın/ilanın tekrarları ve incelenen ilan dışlanır. Pozitif fiyat,
   kaynak, gözlem tarihi, paket ve kondisyon uyumu kontrol edilir. Yakıt,
   şanzıman/paket karışan geniş aramalar kaliteli temiz emsal sayılmaz.
3. Başlangıç kalite eşiği önerisi: en az 5 tekil, doğrulanabilir temiz emsal,
   son 30 gün içinde görülmüş; 31–90 gün verisi yalnız bağlam, daha eskisi
   bugünkü fiyatın dayanağı değil. Eşikler sürümlü yapılandırma olur ve pilotta
   ölçülür. Temiz emsal/paket doğrulaması yoksa resmi değerleme bekler.
4. Emsal medyanı incelenen aracın yıl/km özelliklerine normalize edilir.
   Uygulanan düzeltmeler ve kullanılan katsayı sürümü saklanır. Yaş/km emsal
   normalizasyonunda hesaba katıldıysa ikinci kez hasar kesintisine eklenmez.
5. Aynı parça için boya/değişen ve aynı olaya ait hasar kaydı ilişkilendirilir.
   Hasar bedeli doğrudan araç değerinden çıkarılmaz. Her bulgu için dayanak,
   etkisi, belirsizliği ve örtüşme açıklaması bulunur. Mevcut katsayılar pilot
   kalibrasyonu gerektirir; doğrulanmış piyasa gerçeği diye sunulmaz.
6. Çıktı: temiz emsal değeri, bulgu etkileri TL/%, kondisyon sonrası değer
   aralığı, ilan fiyatı ve hesaplanan değer arasındaki fark.

## Geçmiş piyasa değişimi

- 6 ve 12 ay önceki karşılaştırılabilir segment endeksi ile güncel endeks
  aynı yöntemle karşılaştırılır. Ham ilan ortalamasının araç karışımı değişimi
  enflasyon diye sunulmaz; dönem kapsamı, örnek sayısı ve yöntem açıklanır.
- Bugünden kazınan araçların model yılı eski diye geçmiş fiyat gözlemi
  üretilmez. Gerçek tarihli fiyat geçmişi veya uygun kapsamlı dış seri gerekir.
- Öncelik havuzdaki yeterli tarihli segment serisi; yoksa adminin kaynağı,
  dönemi ve kapsamını kaydederek doğruladığı dış endeks kullanılabilir.
  Genel endeks, o araç modelinin gerçekleşmiş getirisi gibi etiketlenmez.
- Veri yoksa ilgili dönem unavailable/null ve açıklama; 0% yazılmaz.
- Geçmiş segment değişimi, müşterinin henüz gerçekleşmemiş araç kazancı değildir.

## Gelecek senaryoları ve getiri

- 6 ve 12 ay için düşük/orta/yüksek değerler; her senaryoda ikinci el fiyat
  değişimi varsayımı, beklenen ek km, yaşlanma ve dahil edilen masraflar açıklanır.
- Geçmiş artış doğrudan gelecek kesin oranı değildir. Başlangıçta adminin
  tarihli/kaynaklı onayladığı senaryo girdileri kullanılabilir; otomatik
  öğrenilmiş tahmin diye sunulmaz. Oran yoksa senaryo üretilemez.
- Aylık oran varsa bileşik hesap: V(n) = V0 × (1+r)^n × kondisyon/yaş/km
  düzeltmesi. Doğrudan 6/12 aylık oran verilmişse tekrar bileşik uygulanmaz.
- V0 bugünkü ekspertiz sonrası değerdir. Getiri tabanı gerçek alış fiyatıdır;
  henüz satın alınmadıysa ilan veya adminin doğruladığı pazarlık fiyatı açıkça
  varsayımsal alış olarak etiketlenir. Gelecek değer farkı ve bugünkü ilan
  iskontosu ayrı gösterilir; ilk günkü fiyat avantajı zaman getirisi diye gizlenmez.
- Brüt kazanç = senaryo satış değeri − alış; net kazanç = satış değeri − alış
  − dahil edilen giderler. Eksik giderler varsa net getiri iddiası yapılmaz.
- Reel oran = (1 + nominal oran)/(1 + aynı dönem TÜFE değişimi) − 1.
  Gelecek TÜFE yalnız varsayım; veri yoksa reel bölüm unavailable.
  İkinci el fiyat endeksi ile genel TÜFE birbirinin yerine kullanılmaz.
- Düşük senaryo değer kaybına izin verir. Sıfır altına zorla kırpılmaz;
  kesin kazanç/garanti veya tek sayıdan ibaret gelecek fiyatı gösterilmez.

## DeepSeek'in sınırı

- Sunucu tarafında sağlayıcı adaptörü. Anahtar/model/çağrı izni ortamdan;
  mevcut ücretli çağrı yasağı nedeniyle varsayılan kapalı. Gerçek çağrı açılması
  ayrıca açık kullanıcı izni gerektirir; model seçimi yapılandırılabilir.
- Girdi: gerekli anonim araç/bulgu verileri, seçilmiş emsal özetleri, kontrollü
  sayısal hesap ve senaryo girdileri. Müşteri/personel kişisel bilgileri gönderilmez.
- Görev: bulgu/emsal tutarlılığını değerlendirmek, çelişkileri işaretlemek,
  değerleme ve senaryoları gerekçelendirmek. Piyasa oranı veya emsal uyduramaz.
- JSON şeması ve sayısal denetim zorunlu. Modelin ek fiyat önerisi yalnız ayrı
  admin önerisi olabilir; doğrulanmış resmi hesapları sessizce değiştiremez.
- Boş/kesilmiş JSON, geçersiz sayı, bilinmeyen bulgu/emsal veya zaman aşımı
  başarılı AI sayılmaz. Kural çıktısı DeepSeek çalışmış gibi yayınlanmaz.

## İş yürütme, sürüm ve yayın

- İş anahtarı rapor revizyonu + emsal snapshot + politika/prompt/model sürümü.
  Aynı işin eşzamanlı tekrar çağrısı kilit/tekil kayıtla engellenir.
- Claim/lease, sınırlı yeniden deneme, sonraki deneme zamanı ve hata nedeni
  kalıcı tutulur. Sürekli başarısız rapor sınırsız maliyet döngüsüne girmez.
- AI sonucu yazılırken rapor revizyonu tekrar doğrulanır; iade/düzeltmeden önceki
  işin sonucu yeni raporu veya published raporu ezemez. İçerik değişince eski
  AI onayı geçersiz olur. Yalnız pending_ai revizyonu pending_admin'a ilerler.
- Başarılı bugünkü değerleme ve gerçek/doğrulanmış DeepSeek sonucu resmi yayın
  kapısıdır. Tarihsel/gelecek veri eksikliği değerleme raporunu tek başına
  engellemez; eksik bölümler açıkça belirtilir. Bu öneri kullanıcı incelemesine açıktır.
- Kullanılan veri/katsayı/model sürümü, zaman, hash ve gerçek/taklit sağlayıcı
  etiketi saklanır. Test sonuçları üretimde resmi sonuç olarak kabul edilmez.

## Üç panelde gösterim

- Personel gönderim ve iade akışı korunur. Yeni kredi ürünü/personel fiyat
  değiştirme yetkisi eklenmez.
- Admin: temiz emsaller, kalemler, fiyat karşılaştırması, AI yorumu, veri
  kapsamı/uyarılar, 6/12 ay tabloları ve hata/yeniden deneme durumu.
- Müşteri: yalnız onaylı revizyon; bugünkü değer, ilan karşılaştırması, gerekçe,
  tarihli geçmiş değişim ve etiketli gelecek senaryoları. Mevcut dört rapor
  bütünlüğü korunur. Yetkisiz kullanıcı rapor/medya erişimi alamaz.
- Eksik oran/değerler UI'da 0 TL/0% gibi gösterilmez. Mobil tablo okunabilirliği
  ve PDF/rapor çıktısının aynı sayıları kullanması doğrulanır.

## Uygulama sırası ve kabul kanıtları

1. Saf hesap/sözleşme testleri: temiz emsal şartı, fallback reddi, örtüşme ve
   km mükerrerliği, negatif getiri, bileşik/reel hesap, eksik veri.
2. Taklit DeepSeek: doğru/bozuk/boş yanıt, tutarsız rakam, timeout, kapalı
   sağlayıcı. Ücretli çağrı yok; varsayılan testler DB bağlantısı kullanmaz.
3. Worker entegrasyonu: revizyon değişikliği, eşzamanlı işlem, retry sınırı,
   yanlış durum/geç yanıt ve yayın kapısının taklit bağımlılıklarla sınanması.
4. Admin/müşteri rapor sözleşmeleri ve mobil görsel kontroller.
5. Önce ayrı ve boş DB üzerinde gerçek API ile uçtan uca senaryo. Mevcut yerel
   deneme DB'si sıfırlanmaz, canlı DB kullanılmaz. Ücretli servisler taklittir.
6. Sonradan açık izinli küçük gerçek DeepSeek pilotu; uzman referansına göre
   fiyat hatası, aralık kapsaması, bulgu dayanağı ve açıklama tutarlılığı ölçülür.
   Kabul eşikleri pilot öncesinde belirlenir; şimdiden başarı iddiası yok.

Bu tasarım hosting satın alma, scraper başlatma/veri yazımı, canlı deploy,
DeepSeek ücretli çağrısı veya kredi ürününü etkinleştirme yetkisi değildir.

## Dış kaynaklar

- DeepSeek JSON çıktısı: https://api-docs.deepseek.com/guides/json_mode/
- Tarihli piyasa rapor örneği: https://betam.bahcesehir.edu.tr/kategori/ekonomik-arastirmalar/yayinlar/otomotiv-piyasasi-gorunumu/
- Reel getiri: https://finansalokuryazarlik.gov.tr/i/nominal-getiri-ve-reel-getiri
