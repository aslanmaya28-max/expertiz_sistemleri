# 026 — Kaynaklı masraf, tipik kilometre ve altı kategori

> Uygulayıcı: superpowers:executing-plans; şartname kök kopru/codex_icin/026-kronik-ariza-masraf-ve-km.md. Taban e09f9cb,025 bitti.

Amaç: yalnız kaynakta yazan aynı onarımın Türkiye TL maliyetini ve açık kilometre aralığını göstermek; arızayı teşhis etmeden bu aracın kilometresinde dikkat edilecek başlıkları ayırmak.

Mimari: vehicle_risk mevcut kaynak doğrulamasına bağlı kalır. Ayrı risk_evidence saf yardımcıları kategori/km/öncelik ve maliyet kanıtını üretir; risk_cost_search tek ek web araması ve atomik günlük kotayı yönetir. Kaynak adayları önbellekte tutulur ve her güncel araç için yeniden doğrulanır. Web/PDF ortak rapor alanlarını aynı adlarla okur; eski üç kategorili/kategorisiz raporlar görünmeye devam eder.

Sınırlar: en fazla1ek arama/rapor, en fazla3orta/yüksek güvenli eksik fiyat kalemi. RISK_COST_SEARCH_LIMIT varsayılan20günlük (0kapalı; en fazla1000); rapor başı sınır1sabit. Arama başarısızlığı ana raporu bozmaz. Şikâyete fiyat eklenmez; kayıpsız eski önbellek uyumu. Değer kaybı/tramer/pazarlık hesapları, uygulama/admin klasörleri değişmez. .env okunmaz. Test DB ybtest_026; ybapp/ybdemo ve sunuculara dokunulmaz.

Kararlar: tipikKm yalnız aynı konulu kaynak cümlesinde açık x–y km veya x km civarı ifadesinden gelir; nokta ifadesinde min=max, yeni aralık uydurulmaz. Yakınlık eşik10.000km; yayımlanan aralık değişmez, önem yalnız bir kademe artar ve kilometreUyarisi etiketi eklenir. Önbelleğe km'ye özgü artış yazılmaz. Masrafın kaynağı ve erişim tarihi saklanır; ek arama ücreti scope.cost_usd'ye eklenir. Aynı onarım için konu+işlem eşleşmesi ve _cost kaynak-TL doğrulaması gerekir.

- [x] Önce kategori/km/kaynaklı fiyat ve karşı örnek testleri; saf yardımcılar ve atomik kota.
- [x] Tek ek arama, en fazla3kalem, kaynak/tarih/ücret; önbellekte ham kanıt ve araç başına yeniden doğrulama. Eski cache alanları güvenli varsayılanlarla korunur.
- [x] Altı kategori motor/sanziman/kaporta/alt_takim/elektronik/diger; model kategorisi kullanılmaz. Güncel km için önem/etiket; fiyat hesabı değişmez.
- [x] Web/PDF aynı başlıklar, kanıt etiketi, masraf kaynak/tarih ve tipikKm; şikâyete fiyat yok. Next yönergesi ve eski rapor görüntüleme testleri.
- [ ] Tüm Python,tsc,site testleri; son inceleme; Cupra/Fiat gerçek model önce/sonra ölçümü Claude010 betiği; commit/teslim.

İnceleme: review_026 salt okunur turunda3P2buldu. Sonar yanıtını ek masraf değişkeninin ezmesi; aynı cümlede lastiğin km'sinin trigere taşınması; birleşik işlem adının başka fiyatı saklaması. Hepsi kırmızı→yeşil testle tek turda düzeltildi (35test). Ayrı kaynak değişkenleri, parça/km yakınlık denetimi ve tek işlem adı kuralı kullanılır. Önce/sonra canlı kapsam ve masraf ölçümü için010betiği hazırdır.

Karar: tek teknik kaynağı “Çok kaynaklı” diye etiketlememek için ek “Teknik kaynak” etiketi kullanıldı; bağımsız alan sayısı sunucuda hesaplanır. Kilometreyle yükselen yüksek önem “Öncelikli kontrol” olarak görünür, doğrulanmış bir yüksek masraf varmış gibi sunulmaz. Poppler bu ortamda bulunmadığı için mevcut PyMuPDF ile5örnek sayfa ve yeni masraf/km sayfası PNG'ye çevrilip görsel denetlendi; kırpılma/taşma yok. Public örnek PDF güncel üreticiden ağsız yeniden üretildi; JSON ve fiyatları değişmedi.

Son doğrulama: tüm Python865geçti (180.96sn), tsc temiz, site46geçti. Loglar kopru/log/026-final-tests.log,026-tsc-final.log,026-node-final.log. Eşzamanlı12kota denemesinde yalnız3izin döndü. 018değişmez testleri değiştirilmedi; mevcut kategori beklentileri yalnız yeni altı kategori sözleşmesine uyarlandı. Tek kalan kabul maddesi Claude010'daki iki gerçek model ölçümüdür; bu süreçte model anahtarı yok, canlı ölçüm uydurulmaz.

Son kapsam düzeltmesi: doğru motorun sayfa girişinde bulunması, onarım cümlesindeki başka motorun fiyatını kabul ettirebiliyordu. Ana risk doğrulamasındaki cümle düzeyi sürüm kuralı ek fiyat kanıtına ve önbellekteki yeniden doğrulamaya da uygulandı; aynı karşı örnek kırmızı→yeşil,36odaklı test geçti. Bu değişiklik için tam kapı yeniden çalıştırılıyor.

Güncel teslim kapısı:866Python geçti (186.68sn), önceki46site ve temiztsc değişmedi. Canlı ilk örneklerde görünür risk0; önceki kodda Egea'nın9riski de düşük güvenli. Güven kuralı değiştirilmedi. tools/risk_smoke_diagnostics aynı aday/kaynaklarla eski e09f9cb doğrulayıcıyı karşılaştırır; yardımcı1ağsız test ve gerçek eski modül yükleme kontrolü geçti.010'da varsayılan tanı + teknik kaynaklı ikinci örnek çift istendi;011'de ayrı kullanıcı politika kararı bırakıldı. Canlı tanı/ölçüm bekleniyor, kabul tamamlandı denmez.

010'dan devam turu: aynı sentetik ham kaynakta e09f9cb kabul/9d2d991red biçiminde gerçek DSG bağlam regresyonu tekrarlandı. Genel DSG etiketi, özgül mekatronik kanıtına ilgisiz motor paragrafını katıyordu. evidence_topics başlıkta açık şanzıman sözcüğü yokken genel vites bağlamını özgül arıza kanıtından ayırır; kaynak/fiyat/km ve şikâyet konu kimliği aynı ayrımı kullanır. Kategori ve eski ham adaysız cache de tutarlıdır. Yanlış motor mekatroniği yine reddedilir; genel DSG yağ fiyatı mekatronik fiyatı olmaz. Yeni4regresyon testi ve eski cache kontrolü güçlendirildi;130hedefli test geçti.

Daraltılmış incelemede DSG'nin km mesafe hesabında rakip parça sayılması bulundu; ek kırmızı→yeşil testle DSG/DCT bağlamı gerçek parça km'sini gizlemeyecek şekilde düzeltildi. Son42odaklı test geçti. Kontrol tekrarı: eski/yeni kabul=true, eski/yeni güven=yüksek, ilgisiz km aktarılmadı (kopru/log/026-dsg-replay.json; sentetik örnektir, canlı ölçüm değildir). Güven eşiği veya kaynak listesi değişmedi. Son tam kapı çalışıyor;010 isteği yalnız kalan iki canlı komutu içerecek şekilde sadeleştirildi.

Bu devam turunun son koduyla tam Python kapısı872geçti (219.36sn), log kopru/log/026-context-final-gate.log. Ek dar inceleme bulgusu düzeltildi; yeni canlı veri henüz gelmediğinden026calisiyor durumu korunur.

Yeni010cevabı geldi: aynı ham kaynaklarda Cupra2/2,Egea7/7,Focus3/3,Golf0/0kabul; görünür eski/yeni0/0. Dolayısıyla bu örneklerde kaynak eleme regresyonu yok; tüm kabul edilenler düşük güvenli. NHTSA'nın listede olmadığı yorumu tanı yardımcısının yanlış gerekçesinden kaynaklanıyordu;_AUTHORITIES zaten nhtsa.gov içeriyor. Gerçek SSM47587PDF'si web aracıyla kontrol edildi; belge başlığıSSM, servicebulletin/recall sözcükleri yok. Mevcut resmî kayıt kuralında yalnız güvenilenNHTSAhost+kesinTSBarşiv yolu+SSM/TSBbelgeetiketi+model/motor kapsamıyla tür tanıması düzeltildi. GenelPDF,sahtehost ve başka motorun düşük kalması kırmızı→yeşil test edildi. Güven gerekçesi artık `_confidence_details` ortak fonksiyonundan gelir; ayrı kopya mantık kaldırıldı.133hedefli test geçti; son tam kapı çalışıyor. İki bilinmeyen kaynağın orta olması011kullanıcı kararı olarak kalır;010'da yalnız teknik çiftin son tekrar ölçümü istendi.

Kapanış: son üretim koduyla874Python testi geçti (196.05sn,026-ssm-delivery.log),46site testi geçti ve tsc temiz. Kullanıcı026'nın mevcut kural ile teslimini, Bpolitikasının ayrı029görevinde yapılmasını açıkça istedi. Dört gerçek modelin önce/sonra0masraf/0km ve maliyetleri teslim raporuna aktarıldı; bu örneklerde artış gözlenmedi. SSMsonrası canlı tekrar029politika ölçümüyle birlikte yapılabilir; yapılmış gibi gösterilmez.026tamamlandı.
