# Kaynaklı masraf ve kilometre (026)

Yeni değerleme raporlarında “Bu araçta dikkat edilecekler” altı başlıkta sunulur: Motor, Şanzıman, Kaporta, Alt takım, Elektronik, Diğer. Kategori model yanıtından alınmaz; başlıktaki parça terimlerinden üretilir. Eski üç kategorili veya kategorisiz arşiv raporları okunmaya devam eder. Görünüm sürümü `modelRiskleri.gorunumSurumu=2` olur.

## Masraf kanıtı

Ana araştırmada TL bulunmayan, güveni orta/yüksek en fazla3risk için tek ek servis/usta fiyat araması yapılır. Kullanıcı şikâyetlerine fiyat yazılmaz. Modelin verdiği tutar tek başına kabul edilmez: atıfta gerçekten dönen sayfa metninde aynı onarım adı/işlemi ve açık TL değeri bulunmalı, mevcut `_cost` doğrulaması geçmelidir. Başka parçaya ait fiyat, döviz tutarı ve birleşik işlem fiyatı reddedilir. Kaynak yetersizse “kaynakta belirtilmemiş” kalır.

Doğrulanan fiyat `tahminiMaliyet` alanındadır; `maliyetKaynagi` URL, erişim tarihi ve ek aramada tam onarım adını taşır. Bu bir bilgi aralığıdır; masraf değerden düşülmez. Değer kaybı/tramer/pazarlık hesabı değişmez.

`RISK_COST_SEARCH_LIMIT`: tüm kullanıcılar için günlük ek arama sayısı; varsayılan20,0kapalı, üst sınır1000. Rapor başına en fazla1ek arama sabittir. PostgreSQL'deki `risk_cost_search_usage` günlük sayaç tablosu atomik artırılır; ağ çağrısı sırasında işlem/kilit açık tutulmaz. Kota veya veri tabanı hatasında ek araştırma atlanır, ana rapor korunur. Ek arama20saniyeyle ve toplam risk araştırmasının kalan süresiyle sınırlıdır.

Ek ücret `scope.cost_search_usd` ve toplam `scope.cost_usd` içine girer. Önbellek okumaları yeni arama/ücret üretmez. Ham teknik/şikâyet ve masraf kanıtları ayrı saklanır; masraf sonucu Sonar şikâyet adaylarını ezmez. Kayıtlı erişim tarihi korunur, eski kayıtta tarih yoksa bugünün tarihi uydurulmaz.

## Açık kilometre

`tipikKm` yalnız kaynakta açık `80.000–120.000 km` veya `100.000 km civarı` gibi ifadeden gelir. Belirsiz “yüksek km” veya TL aralığı kilometreye çevrilmez. Yan cümleler ayrılır; km ifadesine en yakın ilgili parça denetlenerek lastik km'si triger gibi başka riske bağlanmaz. Nokta ifadesi min=max olarak saklanır; aralık genişletilmez. `kmKaynagi` kaynak ve erişim tarihini taşır.

Aracın km'si aralıkta veya sınırına en fazla10.000km uzaklıktaysa önem bir kademe artar; “Bu kilometrede dikkat” etiketi görünür. Bu artış her araçta ham önbellek adayından yeniden hesaplanır; ilk aracın yükseltilmiş önemi başka kilometredeki araca taşınmaz.

## Web/PDF eşliği ve eski kayıtlar

İkisi aynı JSON'daki kategori, `kanitSeviyesi`, masraf/km ve kaynak/tarih alanlarını gösterir. Resmî kanıt “Resmî kayıt”; en az iki bağımsız alan “Çok kaynaklı”; tek doğrulanmış teknik kaynak “Teknik kaynak”; şikâyet “Kullanıcı deneyimi” diye etiketlenir. Tek kaynağa çok kaynaklı denmez. Eski PDF örneği kaynak JSON'undan ağsız yeniden üretilmiş, tüm sayfaları görsel denetlenmiştir.

## Canlı karşılaştırma

`musteri_paneli` içinde `python -m tools.risk_evidence_smoke` iki araçla sınırlıdır: CupraFormentor1.5TSIDSG ve FiatEgea1.3Multijet. Anahtar süreç ortamında olmalıdır; betik gizli dosya okumaz. Önbellek kapalıdır; yalnız localhost55432/ybtest_026_smoke bütçe sayacı kullanılır, ybapp/ybdemo'ya dokunmaz. Aynı teknik kaynak adaylarında `scope.coverage.before` ek arama öncesi kaynaklı fiyatı ve eski şemadaki0km alanını; `after` son doğrulanmış kapsamı gösterir. Böylece rastgele farklı web aramaları önce/sonra gibi sunulmaz. Gerçek sonuçta0da olabilir; kaynaksız tutar veya km eklenmez.
