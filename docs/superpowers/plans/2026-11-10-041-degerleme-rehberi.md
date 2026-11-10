# 041 Değerleme ilk kullanım rehberi

**Amaç:** 041 köprü şartnamesindeki beş adımlı rehberi ve erişilebilir alan bilgilerini mevcut değerleme akışına eklemek.
**Mimari:** Bağımlılıksız istemci bileşenleri. Tur baloncuğu hedef bölümde ayrılmış alana portal ile yerleşir; belge akışında yer kaplayarak formu örtmez, sayfa kaydırılabilir. Bilgi düğmeleri etiketlerden bağımsızdır; açılan açıklama viewport içinde konumlanır. Görüldü kaydı yalnız tarayıcıda tutulur.
**Teknoloji:** Mevcut Next.js 16 / React 19 / TypeScript; yeni CSS dosyası.
**Şartname:** `kopru/codex_icin/041-degerleme-ilk-kullanim-rehberi.md`.

## Sınırlar
Sunucu, API sözleşmesi, form alan adları/değerleme hesabı, kredi sayfası ve paylaşılan iki CSS dosyası değişmez. Kredi sıfırken rehber satın almaya yönlendirmez. Türkçe metin, klavye, Esc, reduced motion ve 360 px desteklenir.

## Uygulama
- [ ] Test tabanını çalıştır; `tests/ilk-kullanim-rehberi.test.mjs` ile beş adım, bitir/atla kalıcılığı, erişilemeyen depolama ve güvenli baloncuk konumu için kırmızı test.
- [ ] `src/lib/ilkKullanimRehberi.ts`: adımlar, güvenli depolama ve konum sınırı; `IlkKullanimRehberi.tsx` ve `BilgiBaloncugu.tsx`: etkileşimler.
- [ ] Değerleme sayfasındaki hedefler ve alan bilgileri; fotoğraf bileşeni başlığı; yeni `rehber-turu.css` ve layout içe aktarması. Otomatik tur yalnız oturum/form hazırken başlar; manuel düğme tekrar açar.
- [ ] TypeScript ve tüm node testleri; Playwright'ta 390/1440 her adım + açık bilgi, atla/bitir sonrası yenileme, depolama engeli, klavye ve reduced motion; PNG'leri incele.
- [ ] Bütün dal için bağımsız inceleme; Türkçe commit ve köprü raporu.

## İnceleme odağı
- Storage getter/setter hataları sayfayı durdurmaz; aynı oturumda kapatılan tur yeniden belirmez.
- Tur düğmeleri form göndermez; form değerleri gezinmede korunur.
- Bilgi düğmesi label içine yerleşip yanlış alanı tetiklemez; aria-describedby yalnız açıklama açıkken bağlanır.
- Küçük ekranda baloncuk sınırları ve belge yatay genişliği kontrol edilir.
- Oturum yüklenirken/girişsiz/rapor gösterilirken otomatik tur açılmaz; odak tuzağı ve kaydırma kilidi yoktur.
