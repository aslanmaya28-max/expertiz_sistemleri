/** Araç değerleme ekranındaki ilk kullanım rehberinin içeriği ve tarayıcıya bağlı olmayan yardımcıları (041). */

export type RehberHedefi = "ilan" | "bilgiler" | "kaporta" | "fotograf" | "degerle";

export interface RehberAdimi {
  hedef: RehberHedefi;
  baslik: string;
  metin: string;
}

/** Görüldü bilgisi yalnız bu tarayıcıda tutulur; sürüm değişince rehber bir kez daha gösterilebilir. */
export const REHBER_ANAHTARI = "yb-degerleme-rehberi-v1";

export const REHBER_ADIMLARI: RehberAdimi[] = [
  {
    hedef: "ilan",
    baslik: "İlanı ekleyin",
    metin: "İlan linkini yapıştırıp \"Bilgileri getir\"e basın; araç bilgileri otomatik dolar. İlan sitesi erişim vermezse ekran görüntüsü yükleme düğmesi çıkar.",
  },
  {
    hedef: "bilgiler",
    baslik: "Bilgileri kontrol edin",
    metin: "Otomatik gelen marka, model, yıl, kilometre ve fiyatı ilanla karşılaştırın; eksik olanları tamamlayın. Alanların yanındaki \"i\" işaretinde kısa açıklama var.",
  },
  {
    hedef: "kaporta",
    baslik: "Boya ve değişenleri işaretleyin",
    metin: "Biliyorsanız boyalı ve değişen parçaları araç şemasında işaretleyin, hasar kaydı tutarını girin. İşaretlemediğiniz parçalar orijinal sayılır.",
  },
  {
    hedef: "fotograf",
    baslik: "Ekspertiz raporu (isteğe bağlı)",
    metin: "Elinizde ekspertiz raporu varsa fotoğrafını ekleyin; parçaları ve trameri sizin için okuyalım. Bu adım isteğe bağlıdır.",
  },
  {
    hedef: "degerle",
    baslik: "Değerlemeyi başlatın",
    metin: "",
  },
];

/** Son adımın metni bakiyeye göre değişir; bakiye sıfırken satın almaya yönlendirmez. */
export function sonAdimMetni(bakiye: number | null): string {
  if (bakiye === 0) {
    return "Bakiyeniz şu an 0. Kredi hesabınıza tanımlandığında buradan değerleme yapabilirsiniz; hazırlanan raporlar Raporlarım'da saklanır.";
  }
  return "\"Analiz Et\"e bastığınızda 1 kredi kullanılır. Rapor genellikle bir dakikadan kısa sürede hazırlanır ve Raporlarım'da saklanır.";
}

interface DepoBenzeri {
  getItem(anahtar: string): string | null;
  setItem(anahtar: string, deger: string): void;
}

/** Depolama kapalı/engelliyse (gizli pencere, tarayıcı ayarı) rehber yine çalışır, yalnız hatırlanmaz. */
export function rehberGorulmusMu(depo: () => DepoBenzeri): boolean {
  try {
    return depo().getItem(REHBER_ANAHTARI) === "1";
  } catch {
    return false;
  }
}

export function rehberiTamamla(depo: () => DepoBenzeri, neden: "atla" | "bitir"): void {
  void neden;
  try {
    depo().setItem(REHBER_ANAHTARI, "1");
  } catch {
    // Hatırlanamaz; aynı sayfa ziyaretinde bileşen durumu rehberi kapalı tutar.
  }
}

interface Kutu {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

const KENAR = 12;
const ARALIK = 8;

/** Bilgi baloncuğunun ekran içi konumu: düğmenin altında (sığmazsa üstünde), ekran kenarlarından taşmadan. */
export function baloncukKonumu(dugme: Kutu, ekranEni: number, ekranBoyu: number, en: number, boy: number) {
  const width = Math.min(en, ekranEni - KENAR * 2);
  const orta = (dugme.left + dugme.right) / 2;
  const left = Math.min(Math.max(orta - width / 2, KENAR), ekranEni - KENAR - width);
  let top = dugme.bottom + ARALIK;
  if (top + boy > ekranBoyu - KENAR) top = Math.max(KENAR, dugme.top - ARALIK - boy);
  return { left, top, width };
}
