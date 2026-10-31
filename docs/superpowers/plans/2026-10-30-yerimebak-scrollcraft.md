# YerimeBak ScrollCraft revizyon planı

**Goal:** Logoyu sayfayla bütünleştirmek, araç fotoğraflarını yenilemek ve hizmeti anlatan kaydırma hareketlerini eklemek.
**Spec:** `docs/superpowers/specs/2026-10-30-yerimebak-scrollcraft.md`.
**Architecture:** Next.js sunucu içeriği, yalnız ana sayfada istemci motor sarmalayıcısı; saf ScrollCraft motoru değiştirilmeden yerel sunulur. Kimlik ve rapor API'leri korunur.
**Tech Stack:** Mevcut Next.js/React, CSS transform/opacity, ScrollCraft vanilla JS, Python Playwright.

- [x] Önce test: motor mount/unmount, hareketli ve azaltılmış hareket, marka PNG yerine aynı siluetle vektör kilit, rapor birleşmesi.
- [x] Marka.tsx düz vektör + okunaklı yazı; orijinal logo dosyası korunur.
- [x] HeroBolumu.tsx yeni dış/kokpit fotoğrafları ve bağımsız katmanlar.
- [x] ScrollSahnesi.tsx scope/mount/destroy, RaporDosyasi.tsx dört raporlu anlamlı imza sahnesi; yerel CSS.
- [x] Masaüstü ve telefon scroll karelerini incele; JS kapalı ve script hatası fallback, azaltılmış hareket, SPA yeniden giriş testleri.
- [x] Mevcut 7 müşteri testini, TS/lint ve build'i doğrula; lisans/asset kaynakları/durum kaydı.

## Sınırlar
Ücretli üretim yok; gerçek DB yazımı yok. Mevcut kirli özellik dalında kullanıcının
önceki çalışması korunur. Farklı projeler veya canlı Vercel yayını değiştirilmez.
Hareket en fazla kısa rapor sahnesini sabitler; mobilde ve hareket azaltıldığında
normal akış. Yazılar/CTA animasyonla erişilemez hale gelmez.

## Tamamlanan doğrulama
- ScrollCraft olmadan ilk mount testi FAIL; entegrasyondan sonra PASS.
- 5 scroll testi PASS: gerçek katman dönüşümleri, iki SPA çıkış/girişinde aktif
  instance 1→0→1, JS/script hatası durumunda görünür içerik, mobil/azaltılmış hareket,
  kısa ekran ve canlı hareket tercihi değişimi.
- Görsel kontrolde erken biten rapor hareketi; incelemede kısa masaüstü sahnesi
  bulundu. İkisi de önce FAIL eden testle gösterildi, sonra düzeltilip 5/5 PASS.
- Mevcut 7 müşteri tarayıcı senaryosu ve 3 Node testi PASS.
- TypeScript/ilgili TSX ESLint temiz; son üretim build başarılı, 25 sayfa.
- Vendor JS SHA256 kaynakla aynı: 91A8E57CEC07B7B977584885741F07D93FD1CD08FDBEA623D5432FCEDE66FD38.
- Gerçek telefonda test yapılmadı; mobil Chromium boyutları kullanıldı.
- Kareler ve contact-sheet: üst çalışma alanı `.tmp/yerimebak-scrollcraft/shots/`.
- His kontrolü: açılış tanıma, raporların birleşmesi güven, süreç açıklık. İlk
  denemedeki erken duran final giderildi; son birleşme gerçek kaydırma boyunca sürer.
- Vercel yayını veya Git push/commit yapılmadı. Önizleme http://127.0.0.1:18802/ .
