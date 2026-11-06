# YerimeBak müşteri uygulaması — tasarım sistemi

Onaylanan tasarım (4 Kasım 2026): **açık tema = A "Kurumsal güven"**, **koyu tema = C "Gece premium"**.
Ekranların görseli: https://claude.ai/artifact/8bs26xegdJw4DhUxgdgKto (`Main`, `A-Rapor`, `A-Hizmet`, `A-Surec`,
`C-Ana`, `C-Rapor`, `C-Hizmet`, `C-Surec`). B yönü seçilmedi, kullanılmaz.

Bu belge uygulamanın tek görsel kaynağıdır. Renk, yazı, boşluk ve köşe değerleri yalnız `musteri_uygulamasi/lib/tema/`
içinde tanımlanır; ekranlarda sabit renk ya da sayı yazılmaz.

## 1. İlkeler

- **Kurumsal ve sakin.** Banka uygulaması ciddiyeti: düz renkler, ince ayırıcılar, tek vurgu rengi.
- **Rakam ön planda.** Raporun kalbi fiyat: büyük, net, hizalı rakamlar (tablo rakamları açık).
- **Uygulama hesap yapmaz.** Her rakam ve metin sunucudan gelir; web raporuyla aynı sıra ve kurallarla gösterilir.
- **Yasak:** renk geçişi (gradient), buzlu cam, emoji, hazır çizim/stok görsel, sol kenarı renkli kart, sahte durum çubuğu,
  "Hoş geldiniz!" gibi boş metin, hazır UI kütüphanesi (GetWidget vb.).

## 2. Tema seçimi

- Varsayılan: telefonun açık/koyu ayarını izler. Profil → Görünüm: Sistem / Açık / Koyu.
- İki tema aynı yerleşimi, aynı yazı tipini ve aynı bileşenleri kullanır; yalnız renkler değişir.
- **Tek fark — ana ekran üstü:** açık temada koyu yeşil marka bandı ve içinde kredi bakiyesi; koyu temada bant yok,
  kredi sağ üstte hap (pill) olarak durur.

## 3. Renkler

Tüm metin/zemin çiftleri WCAG AA'yı geçer (en düşük 5,08:1). Yeni çift eklenirse 4,5:1 altına inmez.

| Görev (token) | Açık (A) | Koyu (C) | Kullanım |
|---|---|---|---|
| `zemin` | `#F2F5F4` | `#0D1312` | Sayfa arka planı |
| `yuzey` | `#FFFFFF` | `#151D1C` | Kart, liste, alt menü |
| `yuzeyIkincil` | `#F2F5F4` | `#1C2625` | Kart içi kutu (pazarlık üçlüsü), ikon kutusu |
| `metin` | `#0F1B1A` | `#EAF0EF` | Ana metin, rakamlar |
| `metinIkincil` | `#4B5B59` | `#9DADAA` | Açıklama, etiket |
| `metinGovde` | `#4B5B59` | `#B7C4C1` | Kart içindeki uzun açıklama metni |
| `ikonPasif` | `#5B6B69` | `#9DADAA` | Alt menü pasif sekme, ok ikonları |
| `kenarlik` | `#E3E8E7` | `#1F2928` | Üst çubuk/alt menü çizgisi |
| `ayirici` | `#E6ECEA` | `#222D2C` | Liste satırları arası |
| `girdiKenarlik` | `#CFD8D6` | `#2A3735` | Metin kutusu, ikincil buton kenarı |
| `birincil` | `#00876F` | `#2ED9B8` | Ana buton zemini, aktif sekme, seçili durum |
| `birincilUstu` | `#FFFFFF` | `#04201C` | Ana buton yazısı |
| `birincilMetin` | `#006B58` | `#55E3C6` | Bağlantı, vurgulu yazı |
| `birincilYuzey` | `#D6F5EB` | `#0E3A31` | Hedef fiyat kutusu, ikon kutusu |
| `birincilAcik` | `#6EDCC2` | `#1C7F6C` | Adil aralık çubuğu, ince vurgu kenarı |
| `markaBandi` | `#00574C` | — | Ana ekran üst bandı (yalnız açık tema) |
| `markaBandiMetin` | `#B5E3D8` | — | Bant içi ikincil yazı |
| `markaBandiVurgu` | `#5CEBC6` | — | Logodaki "Bak", "Yakında" rozeti zemini (bantta) |
| `vurgu` | `#E8622C` | `#FF8A57` | Turuncu dokunuş: hizmet kartı simgesi, fiyat çubuğunda ilan çizgisi |
| `vurguMetin` / `vurguKenar` | `#B4461B` / `#F7B48E` | `#FFA57D` / `#8A4326` | "Yakında" rozeti yazı/kenar, koyu temada kredi düğmesi |
| `vurguBant` | `#FF9B6A` | — | Açık temada yeşil bantta kredi sayısı |

> **Turuncu kuralı (kullanıcı kararı, 6 Kasım 2026):** ana renk yeşil kalır. Turuncu yalnız yukarıdaki küçük
> dokunuşlarda kullanılır; düğme, karar rozeti, bağlantı ve seçili menü yeşildir. Kaporta durum renkleri ayrıdır.
> Aynı gün "daha canlı" isteğiyle yeşil ve turuncu doygunlaştırıldı; hizmet kartları sırayla nane (`birincilYuzey`)
> ve şeftali (`vurguYuzey`) zeminlidir.
| `uyari` | `#8A4B00` | `#F0B458` | "Pazarlık yapın" yazısı, ilan işareti (koyu) |
| `uyariYuzey` | `#FDF1E2` | `#241A0B` | "Pazarlık yapın" rozet zemini |
| `uyariKenar` | `#F2C894` | `#6B4A16` | Uyarı rozet kenarı |
| `tehlike` | `#9A2A1C` | `#F29A8C` | "Önerilmez" yazısı |
| `tehlikeYuzey` | `#FCEDEA` | `#2A1613` | "Önerilmez" rozet zemini |
| `bilgi` | `#1F4E8C` | `#8FB8F0` | "Ek doğrulama gerekli" yazısı |
| `bilgiYuzey` | `#E8F0FB` | `#14202F` | "Ek doğrulama gerekli" rozet zemini |

Koyu temada yükselti gölgeyle değil, bir ton açık yüzeyle verilir. Açık temada yalnız ana ekrandaki "Yeni analiz"
kartında hafif gölge: `0 1 2 rgba(16,24,40,.06)` + `0 12 32 rgba(16,24,40,.07)`.

## 4. Karar rozeti (sunucudaki `karar.sonuc` → ekran)

| `karar.sonuc` | Rozet metni | Renk |
|---|---|---|
| `AL` | Alınabilir | `birincilMetin` üstüne `birincilYuzey` |
| `PAZARLIK YAP` | Pazarlık yapın | `uyari` üstüne `uyariYuzey` |
| `ALMA` | Önerilmez | `tehlike` üstüne `tehlikeYuzey` |
| `EK DOĞRULAMA GEREKLİ` | Ek doğrulama gerekli | `bilgi` üstüne `bilgiYuzey` |

Renk tek başına anlam taşımaz; rozet her zaman yazılıdır. Rapor detayında karar rozetinin yanında sunucunun
`karar.aciklama` metni durur.

## 5. Yazı

- **Yazı tipi: Inter** (sitenin yazı tipi), iki temada aynı. `google_fonts` ile değil, uygulamaya gömülü (`assets/fonts`,
  OFL lisansı) — çevrimdışı ve ilk açılışta da doğru görünür. Ağırlıklar: 400, 500, 600, 700.
- **Rakamlar:** para, km, yüzde gösterilen her yerde tablo rakamları (`FontFeature.tabularFigures()`).
- Satır yüksekliği gövde metinde 1,4–1,5.

| Rol | Boyut / ağırlık | Harf aralığı | Örnek |
|---|---|---|---|
| `rakamBuyuk` | 34–44 / 600 | −0,8 | Hesaplanan değer "1.610.000 TL" |
| `baslik1` | 25 / 600 | −0,4 | Ekran başlığı "Aracı uzaktan satın alın" |
| `baslik2` | 21 / 600 | −0,3 | Araç adı rapor başında |
| `bolumBaslik` | 16–17 / 600 | 0 | "Pazarlık planı", "Son raporlar" |
| `govde` | 15 / 400 | 0 | Liste satırı başlığı (600), girdi metni |
| `govdeKucuk` | 14 / 400 | 0 | Açıklama paragrafı |
| `etiket` | 13 / 500 | 0 | Alan etiketi, satır alt bilgisi |
| `kucuk` | 12 / 500–600 | 0,2 | Rozet, rapor no, tarih |
| `menu` | 11 / 500 (aktif 600) | 0 | Alt menü yazısı |

En küçük yazı 11 (yalnız alt menü); okunması gereken metin en az 13.

## 6. Boşluk, köşe, boyut

- **Boşluk adımları:** 4 · 8 · 12 · 16 · 20 · 24 · 28. Sayfa yan boşluğu kartlarda 16, düz metinde 20.
- Kart iç boşluğu 16–20; kartlar arası 12; bölüm başlığı ile içerik arası 10–12.
- **Köşeler:** buton ve girdi 12 · kart 16 (rapor kartları 18) · liste ikon kutusu 11 · rozet 6 · hap 22 (tam yuvarlak).
- **Dokunma alanı en az 44×44.** Ana buton yüksekliği 52, girdi 52, ikincil buton 50, alt menü 64 + güvenli alan.
- Kenarlık kalınlığı 1; seçili/vurgulu kenar 1,5–2.

## 7. İkonlar ve marka

- **İkon seti: Lucide** (çizgi ikon, ISC lisansı; Flutter'da `lucide_icons_flutter` ya da SVG). Çizgi kalınlığı 1,75
  (aktif sekme 2), boyut 20–24. Dolu ikon kullanılmaz.
- **Logo:** sitedeki sembol (`musteri_paneli/frontend/src/bilesenler/Marka.tsx` içindeki SVG yolu) + "Yerime**Bak**" yazısı.
  Açık temada bantta beyaz sembol, "Bak" `markaBandiVurgu`; koyu temada sembol `birincil`.
- Araç, ekspertiz, belge, çekici gibi ikonlar tuvaldeki ekranlardaki çizimlerle aynı anlamda kullanılır.

## 8. Bileşenler

Her bileşen `lib/bilesenler/` altında tek dosya, ekranlar bunları kullanır.

| Bileşen | Kural |
|---|---|
| **AnaButon** | Tam genişlik, 52 yükseklik, `birincil` zemin, `birincilUstu` 16/600 yazı. Yüklenirken metin yerine küçük gösterge; çift basış engellenir. |
| **IkincilButon** | 50 yükseklik, `yuzey` zemin, `girdiKenarlik` 1 kenar, `metin` yazı. |
| **MetinKutusu** | Üstte görünür etiket (13/500), 52 yükseklik, `girdiKenarlik`; odakta `birincil` 1,5 kenar. İlan linki kutusunda sağda "Yapıştır". |
| **Kart** | `yuzey`, köşe 16–18, kenarlık yok (açık) / yok (koyu, yüzey tonu yeter). |
| **ListeSatiri** | 42'lik ikon kutusu (`yuzeyIkincil`), başlık 15/600, alt bilgi 13 `metinIkincil`, sağda rozet + rakam. Satırlar arası `ayirici`. |
| **KararRozeti** | Bölüm 4. Köşe 6, iç boşluk 3×8, 12/600. Rapor başında büyük hâli 12/700 büyük harf. |
| **YakindaRozeti** | "Yakında" 11/600; iki temada `vurguMetin` yazı + `vurguKenar` kenar. "Şimdi" rozeti dolu `birincil`. |
| **FiyatAraligi** (imza bileşeni) | Yatay çubuk: gri iz (`ayirici`/`yuzeyIkincil`), üstünde adil aralık (`birincilAcik`), hesaplanan değer = `birincil` dolu nokta (beyaz/yüzey halkalı), ilan fiyatı = ince dikey turuncu çizgi (`vurgu`) ve üstünde/altında "İlan 1.730.000". Alt/üst sınır rakamları çubuğun iki ucunun altında. Ölçek, aralığın iki yanına pay bırakacak şekilde sunucu rakamlarından hesaplanır; ilan aralık dışındaysa çizgi çubuğun dışına taşmaz, uca yapışır ve etiket "aralığın üstünde" der. Ekran okuyucu etiketi: "Adil fiyat aralığı X ile Y TL arası; ilan fiyatı Z TL". |
| **PazarlikUclusu** | Üç eşit kutu: Açılış · **Hedef** (vurgulu: `birincilYuzey`) · Üst sınırınız. Altında tasarruf cümlesi. Hedef ile üst sınır sunucuda eşit gelirse yine olduğu gibi gösterilir (kural sunucunun işi). |
| **KaportaSemasi** (imza bileşeni) | Üstten görünüş araç şeması, 13 parça (`/valuation/parts` sırası ve adlarıyla), önü yukarıda, solda "SOL" sağda "SAĞ". Dokununca durum sırayla değişir: Orijinal → Lokal boyalı → Boyalı → Değişen → Orijinal; uzun basınca seçim listesi. Durumlar yalnız renk tonuyla değil açıklıkla da ayrılır ve parçada harf yazar (L/B/D). Açık: orijinal `yuzey` + `girdiKenarlik`, lokal `#FDF1E2`/`#F2C894`, boyalı `#F2C894`/`#C98A3A`, değişen `#A3580A` + beyaz harf. Koyu: orijinal `yuzey` + `girdiKenarlik`, lokal `#241A0B`/`#6B4A16`, boyalı `#6B4A16`/`#B8812F`, değişen `#E9A23B` + `#04201C` harf. Camlar `#E9EEED` / `#253230`. Altında açıklama (lejant) ve yazılı özet ("Değişen: Sol ön kapı, Sol arka kapı · Diğer 11 parça orijinal"). Her parça ekran okuyucuda "Sol ön kapı, değişen" diye okunur. |
| **AltEylemCubugu** | Ekranın altına sabit, `yuzey` + üst `kenarlik`; iki buton yan yana (ikincil + ana) ya da tek ana buton; alt güvenli alan payı. |
| **AltMenu** | 4 sekme: Ana sayfa · Raporlarım · Kredi · Profil. Aktif = `birincil` ikon + yazı. |
| **AdimListesi** | "Aracı uzaktan satın alın" ekranındaki numaralı adımlar: aktif adım dolu daire, gelecek adımlar kenarlı daire + YakindaRozeti; açık temada daireler ince dikey çizgiyle bağlı. |
| **BosDurum / Hata** | Kısa Türkçe cümle + tek eylem ("Tekrar dene"). İkon yok ya da tek çizgi ikon; çizim yok. |
| **Yukleniyor** | Liste ve kartlarda iskelet (gri bloklar, hafif nabız). Tam ekran dönen çark kullanılmaz; analiz beklemesi aşama metinli ayrı ekrandır (021). |

## 9. Biçimler (tr-TR)

- Para: `1.610.000 TL` (binlik nokta, kuruş yok, "TL" sonda, araya boşluk). Küçük kutularda "TL" atlanabilir (pazarlık üçlüsü).
- Yüzde: `%7,4` (işaret önde, ondalık virgül). Km: `44.000 km`.
- Tarih: listede `2 Kas`, rapor başında `2 Kasım 2026`. Rapor no olduğu gibi: `YD 2026-000004`.
- Fiyatta KDV kuralı web ile aynı: hizmet bedeli "5.000 TL + KDV"; firma paketi KDV dahil.

## 10. Hareket ve dokunma

- Geçişler kısa ve sade: sayfa geçişi platform varsayılanı, iç değişimler 150–200 ms solma.
- Tek "an" hareketi: rapor açılınca fiyat aralığı çubuğunda değer noktasının yerine kayması (300 ms). Başka süs animasyonu yok.
- Başarılı ödeme ve rapor hazır olduğunda hafif titreşim (haptic). Sistem "hareketi azalt" açıksa animasyon kapanır.

## 11. Erişilebilirlik

- Metin/zemin en az 4,5:1 (bölüm 3). Sistem yazı boyutu büyütülünce yerleşim taşmaz (en az %130'a kadar denenir).
- İkon tek başına buton ise ekran okuyucu etiketi var ("Bildirimler", "Geri", "Raporu paylaş").
- Renk tek başına anlam taşımaz; rozetler yazılı.

## 12. Flutter'a aktarım (Codex için)

- `lib/tema/renkler.dart`: bölüm 3'teki tokenlar → `ThemeExtension<YbRenkler>` (açık + koyu iki örnek, `lerp` dahil).
- `lib/tema/yazi.dart`: bölüm 5 → `TextTheme` + `YbYazi` uzantısı (`rakamBuyuk` vb.).
- `lib/tema/olculer.dart`: bölüm 6 boşluk/köşe/boyut sabitleri.
- `lib/tema/tema.dart`: `ThemeData.light/dark` (Material 3), `ColorScheme` eşlemesi: `primary=birincil`, `onPrimary=birincilUstu`,
  `surface=yuzey`, `onSurface=metin`, `onSurfaceVariant=metinIkincil`, `outline=girdiKenarlik`, `outlineVariant=ayirici`,
  `error=tehlike`; `scaffoldBackgroundColor=zemin`. Material'in varsayılan mor/mavi tonları hiçbir yerde görünmez.
- Widget testleri: iki temada da ana bileşenlerin altın görüntü (golden) testi; tasarım bozulursa test kırmızıya düşer.
