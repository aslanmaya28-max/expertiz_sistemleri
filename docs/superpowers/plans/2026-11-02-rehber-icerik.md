# Rehber içerik sayfaları uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Dört özgün Türkçe rehberden ilgili gerçek hizmete yönlendirme ve taranabilir içerik.
**Architecture:** Ortak RehberSayfasi sunucu bileşeni içerik/SSS/CTA ve Article, FAQPage, BreadcrumbList üretir. Dört statik page.tsx aynı şablona veri verir; liste, footer, hizmet bağlantıları, sitemap ve llms ile keşfedilir.
**Tech Stack:** Next.js/React/TypeScript, node:test ve SSR şema doğrulaması.
**Spec:** Ana çalışma kopyasında kopru/codex_icin/016-rehber-icerik-sayfalari.md.

## Global Constraints
- Yalnız görev dalı/worktree/frontend; Python/.env/main/push yok.
- Hizmet, fiyat, bölge SITE_URL/ISLETME/HIZMET_YERINDE/HIZMET_DEGERLEME/BOLGE sabitleriyle tutarlı.
- Özgün içerik; kaynak kopyalama/özetleme, istatistik/yüzde/fiyat kaybı oranı/garanti vaadi yok.
- Yerinde inceleme yalnız mevcut bölge; çevrim içi değerleme aracı görmez. Resmî işlemler genel dille ve güncel kuruma yönlendirilerek anlatılır.

## Review Focus
- Statik metadata ile render edilen Article canonical ve görünür SSS'nin tutarlılığı.
- Sayfa başına 3–5 Kısaca/SSS, tek h1 ve güncelleme tarihi; olmayan sitemap yolları.
- JSON-LD metnindeki HTML kapanışının script sınırını aşmaması.
- Yanlış hizmet/bölge/ücret vaadi; ilan fiyatını gerçek satış fiyatı sanma ve kasa geçişi.
- Kaynaklı bilgi ile inceleme gerektiren bulgunun ayrımı; resmî işlemlerde kesin hüküm vermeme.

## Adımlar
- [x] Başlangıç TypeScript ve 28 site testini doğrula.
- [x] Sayfa keşfi ve JSON-LD için önce kırmızı SSR/dosya testlerini çalıştır.
- [x] Ortak bileşen, dört özgün sayfa, liste ve bağlantıları ayrı dosya sahipliğiyle uygula.
- [ ] Tam TypeScript/node testi, bağımsız içerik/kod incelemesi ve mümkünse worktree üretim derlemesi.
- [ ] Bağımsız köprü test kapısı; görev dalına Türkçe commit ve sonuç raporu.
