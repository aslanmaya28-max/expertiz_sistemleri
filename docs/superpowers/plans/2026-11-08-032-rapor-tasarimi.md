# 032 — Referans görselle rapor sunumu

**Amaç:** Kullanıcının eklediği yeşil rapor görselini mevcut sunum kurallarıyla web raporuna uyarlamak.
**Dayanak:** `kopru/codex_icin/032-rapor-tasarimi.md`; referans `docs/tasarim/rapor-referans-2026-11-08.png`.
**Yöntem:** writing-plans, executing-plans ve test-driven-development ile bu oturumda. Ayrı dal `codex/032-rapor-tasarimi`, taban `c11c76e`.

## Tasarım kararları
- Mevcut marka SVG'si, koyu yeşil/nane tokenları ve çizgi ikonları; referanstaki başka logo veya sabit örnek veri kullanılmaz.
- Başlıkta araç ve doğrulama kimliği, sağda yalnız `ozet.piyasaKonumu`; karar/güven skoru yok. Örnekte gerçek doğrulama bağlantısı yok.
- Bilgi çipleri mobil 2×2; fiyat kartları ve plan/sonraki eylem masaüstünde çift sütun, mobil tek sütun.
- Adil aralık yatay ölçekte; hesaplanan değer ve ilan işareti sınırlanır. Pazarlık hedefi tek rakam, üst sınır ayrı. Eksik eski kayıtlar çizgi ile korunur.
- Özetin risk, gerekçe ve eylem metinleri; kaynak, kalem, bakım, şikâyet, getiri ve bütün mevcut hesap sonuçları korunur. Risk ayrıntıları native details ile açılır, yazdırmada görünür.
- Yeni renkler yalnız kurumsal.css tokenları; yeni bağımlılık, sunucu/PDF/mobil değişikliği yok.

## Adımlar
- [x] Taban 49 node testini ve önce 390/1440 görüntülerini kaydet.
- [x] Başlık/örnek kimliği, hedef/üst sınır ve ölçek taşmaması testleri; kırmızıyı doğrula.
- [x] `RaporBasligi.tsx`, `FiyatOzeti.tsx`, `DegerlemeSonucu.tsx`, `AkilliAliciBolumleri.tsx`, `Ikon.tsx` ve `kurumsal.css` ile sunumu uygula.
- [x] Tüm node testleri ve tsc; 3032 tarayıcı kontrolü: örnek, kayıtlı/analiz ortak bileşeni, mobil taşma, kaynaklar, kopyalama, print ve reduced-motion. Sonra ekran görüntülerini gözle incele.
- [x] Bağımsız inceleme; Türkçe commit, köprü teslimi. Kök birleştirme/push yok.

## Kayıt
- Taban node: 49/49.

- Yeni dört test eski sunumda kırmızı görüldü (032-design-red.log); son node paketi 53/53, tsc temiz.
- Gerçek tarayıcı: 3/3; örnek ve kayıtlı rapor, 390/1440 düzen, kopyalama, ayrıntı/klavye ve print geçti.
- Bağımsız salt okunur inceleme teslimi engelleyen hata bulmadı. Örnek/kayıtlı farkı ayrı tarayıcı testiyle doğrulandı.
- Önce/sonra dört görünümün görüntüleri kopru/log/032-*.png altında; masaüstü ve mobil görüntüler görsel incelendi.
