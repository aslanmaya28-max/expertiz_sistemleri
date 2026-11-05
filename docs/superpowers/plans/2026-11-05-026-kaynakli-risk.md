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
