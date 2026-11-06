# 031 — Site renkleri ve kaydırma geçişleri

**Amaç:** Kullanıcının onaylı 031 görevindeki canlı yeşil/turuncu palet ve hareket fikrini mevcut Next.js/ScrollCraft sitesine uygulamak.
**Dayanak:** `kopru/codex_icin/031-site-canli-gecisler.md`.
**Uygulama:** Bu oturumda executing-plans ve test-driven-development; ayrı dal/worktree, taban `d816f4b` (görevdeki `a570f4f` sonrasındaki 030 merge; frontend aynı).

## Kararlar
- Yeni kütüphane yerine mevcut ScrollCraft; yeni içerik/görsel/fiyat yok.
- Ana sayfada dört rapor kartı, hizmet sayfalarında ilk dört bilgi kartı yığılır. Diğer bölümler doğal akışta kalır; uzun kartların içeriğini örtmemek için yeterli ekran yüksekliği ve sığan kart şartı aranır. Kısa ekran ve azaltılmış harekette normal akış.
- Yeşil ana düğme ve bağlantı; nane/şeftali kartlar; son çağrı bandının yeşil baskın, turuncu uçlu degradesi. Beyaz metin için marka bandı koyuluğu korunur.
- Üst menü yüksekliği değişmeden, kaydırmada iç yüzeyi kapsüle dönüşür. Böylece düzen sıçramaz; mobil menü ve Escape/odak korunur.
- Giriş hareketi transform/opacity ve kademeli 50–300 ms; JS/engine yokken görünür içerik. Azaltılmış hareket CSS'i dosyanın sonunda bütün anlatı hareketlerini kapatır.
- Local-only çalışma; Sites yayını yok. Yalnız 3031 portunda sahip olunan önizleme sunucusu kullanılır.

## Adımlar
- [ ] Başlangıç node/tsc ve önce ekran görüntüleri (1440/390; ana sayfa ve araç değerleme).
- [ ] CSS azaltılmış hareket/yığılma/giriş sözleşmesi için istenen node testi, tarayıcıdaki gerçek davranış testleri; kırmızı kanıtı.
- [ ] `globals.css`, `kurumsal.css`, `scroll-deneyimi.css`: ortak tokenlar, kart yığını, kapsül üst menü/düğme, çağrı bandı ve hareket güvenliği.
- [ ] `ScrollSahnesi`, `UstCubuk`, `HizmetSayfasi`, `page`: mevcut runtime'a bağlantı, uygun kart sınıfları, üst menü kaydırma durumu, simge kapsülleri.
- [ ] TypeScript, bütün node testleri ve mevcut `scrollcraft-experience.py`; gerçek 1440/390, kısa ekran, JS kapalı, runtime yok, dinamik reduced-motion ve klavye/mobil menü kontrolü. Sonra ekran görüntülerini görsel incele.
- [ ] Bağımsız inceleme, Türkçe commit, köprü teslim raporu. Ana dal/birleştirme/push yok.

## Kayıt
- Başlangıç node: 46/46 geçti. Paket kurulmadı; kökteki node_modules'a junction kuruldu.
