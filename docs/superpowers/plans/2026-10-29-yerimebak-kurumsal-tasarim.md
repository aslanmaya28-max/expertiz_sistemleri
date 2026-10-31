# YerimeBak Kurumsal Tasarım Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Müşterinin hizmeti, kapsamı ve güven sürecini anlamasını sağlayan yeni ana sayfa ve kayıt deneyimi.
**Architecture:** Mevcut Next.js uygulamasında sunucuda çizilen tanıtım sayfası, ortak görsel bileşenler, mevcut istemci kimlik formları. API ve yetkiler korunur.
**Tech Stack:** Next.js 16, React 19, Tailwind 4, CSS, yerel fotoğraflar.
**Spec:** `docs/superpowers/specs/2026-10-29-yerimebak-kurumsal-tasarim.md`

## Global Constraints
- Mesleki dallar listelenmez: “alanında uzman personel”.
- İstanbul pilot; 81 il hedef. Vekâleten satın alma ve transfer planlanan hizmetlerdir.
- Ücretli çağrı, üretim DB yazımı, yeni paket veya otomatik yayın yok.
- Önceki yerel değişiklikler ve devam eden personel raporu korunur.

## Review Focus
- Dar ekranda büyük başlık/navigasyon yatay taşmamalı.
- Mobil menü klavye ve dokunma ile açılmalı ve bağlantıda kapanmalı.
- Form etiketleri, doğrulama, yükleme/hata/başarı durumu korunmalı.
- Görseller yüklenirken metin ve CTA kullanılabilir kalmalı.
- Kayıtlı kullanıcı gerçek panelini görmeli; örnek raporlar gerçek veri gibi sunulmamalı.

### Task 1: Ana sayfa ve ortak marka bileşenleri
Files: `src/app/page.tsx`, `src/bilesenler/HeroBolumu.tsx`, `UstCubuk.tsx`,
`AltBilgi.tsx`, new `Marka.tsx`, `Ikon.tsx`, `src/app/globals.css`,
`src/app/layout.tsx`, local `public/images/*`.
Interfaces: mevcut `/ekspertiz-talebi`, `/kayit-ol`, `/panel`, `/#raporlar`,
`/#nasil-calisir` bağlantıları; ortak Ikon ve Marka bileşenleri.
- [x] Tarayıcıda ana mesaj, dört rapor, hizmet durumu, mobil menü kontrollerinin eski sayfada başarısız olduğunu gör.
- [x] Yeni ana sayfayı ve ortak kabuğu uygula, sahte istatistikleri kaldır.
- [x] Mobil/masaüstü ekran görüntülerini incele, CTA/ankrajları doğrula.

### Task 2: Kayıt, giriş ve müşteri karşılama
Files: new `src/bilesenler/HesapCercevesi.tsx`; `src/app/kayit-ol/page.tsx`,
`src/app/giris/page.tsx`, `src/app/panel/page.tsx`, `src/app/hakkimizda/page.tsx`.
Interfaces: mevcut useAuth login/register sözleşmeleri aynen korunur.
- [x] Kayıt/giriş formunu gerçek tarayıcıda doğrula; API cevaplarını testte yakala, DB'ye yazma.
- [x] Yeni düzen, bağlı etiketler, yükleme/hata ve başarı mesajlarını uygula.
- [x] Mock API ile kayıt payload'ı, başarısız/başarılı akışları ve mobil menüyü doğrula.

### Task 3: Tam doğrulama ve teslim
- [x] TypeScript, değişen dosyalarda ESLint, mevcut Node testleri ve Next üretim build.
- [x] Yerel tarayıcı testini çalıştır; sayfalar/ankrajlar/formlar, 360/390/1440px ve azaltılmış hareket.
- [x] Diff incelemesi ve yerel durum kaydı. Kullanıcıya çalışan yerel önizleme adresi ver.

## Execution ledger
- Kullanıcı tasarımı planlayıp uygulamayı açıkça istedi; tekrar onay beklemeden mevcut kapsam uygulanır.
- Mevcut özellik dalı ve çalışan yerel checkout kullanılır; önceki değişiklikler taşınmaz veya geri alınmaz.
- Task 1 complete: eski ana sayfada beklenen başlık testi FAIL; yeni içerik ve mobil menü PASS. Fotoğraflar temsili olarak işaretli, harici paket yok.
- Task 2 complete: `tests/corporate-experience.py` mock kayıt payload/hata/başarı, giriş hata/başarı, müşteri paneli ve güvenli dönüş bağlantıları PASS. Testlerde tüm API istekleri yakalanır; gerçek kayıt açılmaz.
- Task 3 complete: 7 Playwright test PASS; mevcut 3 Node SW testi PASS; TypeScript ve değişen TSX dosyalarının ESLint'i temiz; son Next üretim build 25 sayfa başarılı.
- Final review: corporate_design_review bağımsız salt-okunur incelemede engelleyici bulgu yok. İstenen giriş/dönüş testleri kalıcı test dosyasına eklendi ve geçti.
- Lokal API `/health` ve frontend `/api/v1/expertiz/packages` GET 200. API mevcut izole test DB'sinde migrations/workers kapalı başlatıldı.
- Yayın/commit/push yapılmadı; kullanıcı yerel 18802 üzerinden tasarımı inceleyebilir.
