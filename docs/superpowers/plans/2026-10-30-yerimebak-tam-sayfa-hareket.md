# YerimeBak tam sayfa kaydırma revizyonu

Kullanıcı: logo onaylandı, Porsche fotoğrafı kullanılmayacak; liftte araç kontrol
eden personel görseli isteniyor. Animasyon tüm sayfaya yayılmalı.

Uygulama: mevcut marka ve formlar korunur. Lisanslı temsili lift fotoğrafı,
faydalar için sıralı yükselme, raporlar için ayrı ritimde açılma, süreç için ilerleyen
adımlar, uzmanlık fotoğrafında parallax, misyon/vizyonda yaklaşma, SSS'de yatay
geçiş, kayıt çağrısında büyüyerek yerleşme. ScrollCraft motoru değiştirilmez.
Başlıklar/CTA görünür kalır. Ekran kilidi/ek sabitlenmiş bölüm eklenmez.

- [x] Fotoğrafları ve lisanslarını incele, ilk ekran ve uzmanlık bölümünde kullan.
- [x] Her bölümde ayrı kaydırma ilerlemesi ve görünür hareket; hareket azaltılınca durağan içerik.
- [x] Önce başarısız test, sonra 7 bölümün gerçek CSS dönüşümlerinin değiştiğini doğrula.
- [x] Masaüstü/mobil ara kareler, mevcut müşteri testleri, TS/lint ve build.

Ücretli çağrı veya DB yazımı yok. Kaynak fotoğraf: Artem Podrez / Pexels
8986070 ve 8986068. Başarı ölçütü gerçek ekran değişimi; yalnız data attribute
veya CSS ilerleme değerinin değişmesi yeterli kanıt değildir.

Doğrulama: yeni fotoğraf/bölüm hareketi testi önce FAIL, uygulama sonrası PASS.
6 scroll testi + 7 müşteri tarayıcı senaryosu + 3 Node testi PASS. TS/ilgili lint
temiz; son Next üretim build 25 sayfa başarılı. Ek mobil bölüm yürüyüşü 390px'de
7 bölüm boyunca yatay taşma bulmadı. Ara kareler üst çalışma alanında
`.tmp/yerimebak-full-scroll/`. Bağımsız kod incelemesinde yeni önemli bulgu yok.
Yerel önizleme 18802; canlı Vercel yayını yapılmadı. Gerçek telefonda test yapılmadı.
