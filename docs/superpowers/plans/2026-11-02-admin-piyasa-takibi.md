# Admin piyasa takibi uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Hazır üç admin uç noktasını kullanarak eksik emsalli modelleri ve elle liste ekleme akışını göstermek.
**Architecture:** Mevcut merkezi API servisinin kimlik doğrulama ve hata çözümlemesini kullan. AdminShell rol kapısı altında dokuzuncu modül; önizlemedeki satırlar kaldırılabilir, marka zorunludur. Başarısız kayıtta veri korunur; başarılı kayıtta temizlenir ve eksik emsal listesi yenilenir.
**Tech Stack:** Flutter/Dart, http MockClient ve flutter_test.
**Spec:** Ana çalışma kopyası `kopru/codex_icin/015-admin-piyasa-takibi-ekrani.md`.

## Global Constraints
- Yalnız görev worktree/dalı; sunucu, .env, main ve push yok.
- GET /admin/market/gaps?limit=50; POST /admin/market/manual/preview {text}; POST /admin/market/manual/save {brand,satirlar}.
- Personel rolü AdminShell kapısından geçemez; mevcut Authorization başlığı korunur.

## Review Focus
- Liste düzenlenirken eski önizlemenin kaydedilmesi: metin değişince önizlemeyi iptal et.
- Tespit edilemeyen/boş marka: elle doldurulana kadar kayıt pasif.
- 422 ve ağ/sunucu hatası: sunucu ayrıntısı görünür, kayıt hatasında liste korunur.
- Başarılı kayıt: sonuç sayaçları görünür, metin/önizleme temizlenir ve gaps yenilenir.
- Dar ekran: iki tablo yatay, sayfa dikey kaydırılır; yetkisiz personelde ekran kurulmaz.

## Adımlar
- [x] Mevcut 12 servis/admin testiyle başlangıcı doğrula.
- [x] Önce eksik modül nedeniyle kırmızı testleri göster, API sarmalayıcıları/modülü/menüyü uygula.
- [x] Önizleme, satır çıkarma, marka, kayıt, 422, eski önizleme ve rol testlerini çalıştır.
- [ ] Hata/yeniden deneme ve dar ekran testlerini tamamla; tam Flutter analiz/test kapısını çalıştır.
- [ ] Görev dalına Türkçe commit ve sonuç raporu; Durum bitti.
