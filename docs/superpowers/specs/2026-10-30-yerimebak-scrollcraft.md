# YerimeBak: mevcut kullanıcı kararlarıyla hazırlanan revizyon

Kullanıcı: “yerimebak logusu emanet gibi durmuş sistenin bir parçası gibi durmalı”;
“görsel araç forografları dah iyi olabilir animasyonlu geçişler olabilir”.
Seçilen depo: `nateherkai/scroll-craft`. Önceden verilen yön: kurumsal güven,
uzman personel, dört rapor tek müşteri paneli, İstanbul pilot / 81 il hedefi.

## Sekiz başlık
- His: kurumsal, bütünleşik, güvenilir, kontrollü. Referans BEGG'nin ferah kompozisyonu.
- Yolculuk: hizmet → inceleme → dört raporun birleşmesi → süreç → kayıt.
- Enerji: ilk ekranda sakin güç, rapor birleşmesinde tek belirgin zirve, sonra açıklık.
- Hatırlanacak an: farklı incelemelerden gelen dört raporun aynı araç dosyasında toplanması.
- İmza: dört rapor yaprağı kaydırmayla hizalanarak “müşteri paneliniz” dosyasına oturur.
- Aralık: önceki premium sade/kurumsal karar korunur; yeniden marka icadı yapılmaz.
- Yapı: mevcut bölümler korunarak ayrı sahneler, kesintisiz video uçuşu kullanılmaz.
- Varlıklar: mevcut Y sembolünün silueti, yeni düz yazı kilidi, yerel lisanslı temsili
  fotoğraflar. Ücretli üretim ve API yok. Gövde sahneleri uygulayıcı kararıdır.

## Duygu eğrisi (hareketlerden önce)
1. Tanıma: alanında uzman bir ekip sizin yerinize bakıyor.
2. Açıklık: ne incelendiği ve fotoğrafların rolü anlaşılır.
3. Güven (zirve): dört farklı rapor tek araç dosyasında birleşir.
4. Kontrol: adım adım gerçek işleyiş açıklanır.
5. Kararlılık: kayıt ve inceleme talebi gerçek ekranlarına gider.

“Farklı incelemelerin tek müşteri dosyasında toplandığını gördüğüm site.”

## Kurgu ve skor
Mevcut sayfaya özel hizmet dosyası anlatısı: normal akışlı ilk ekran,
kısa rapor sabitlemesi, ardından doğrudan süreç. Ağır bir site değişimi değil.
Filmic/worldflight video bütçesi ve tek yönlü anlatısı uymaz; live surface gerçek
operasyon panelini tanıtıma karıştırır; poster/maksimalizm güven odağını dağıtır;
gallery tek başına süreci anlatmaz; split-stage karşılaştırma yapmadığımız için
uymaz; chaptered nav zorunluluğu mevcut çalışan müşteri navigasyonunu bozar.

| Durak | Aile | Neden |
|---|---|---|
| İlk ekran | parallax | Fotoğraf ve yakın detay farklı hızlarda, yazı sabit |
| Hizmet faydaları | in | Tek seferlik hafif giriş |
| Rapor dosyası | pin + özel --sc-p | Raporlar müşteri dosyasına hizalanır |
| Süreç | reveal | Bilgiler okunarak açılır |
| Son çağrı | normal akış | Yerleşim sabit; gerçek kayıt bağlantısı |

## Katman sözleşmesi
Fotoğraf çekilmiş haliyle tek bütün kalır, araç kesilip zeminden ayrılmaz.
Arka düzlem: sağdaki yumuşak yüzey. Orta: dış araç fotoğrafı. Yakın: ayrı kokpit
detay çerçevesi. Üst: gerçek metin inceleme etiketleri. Başlık ve CTA sabittir.
Mobilde küçük hareket; hareket azaltılınca tüm içerik tek normal akışta görünür.

## Uygulama / kanıt
ScrollCraft motoru 75d81f74e83692add18cd7a8a8e078b8a887a579 kaynağından değiştirilmeden
alınır. Global reset CSS'i diğer panellere taşınmaz; yerel tasarım CSS'i kullanılır.
Doctor: node/Chrome var; ffmpeg ve Node playwright-core yok. Bu çalışma video
üretmez; mevcut Python Playwright ile gerçek scroll durumları test edilir.
Registry boş: ilk kayıt, karşılaştırılacak önceki ScrollCraft yapımı yok.
