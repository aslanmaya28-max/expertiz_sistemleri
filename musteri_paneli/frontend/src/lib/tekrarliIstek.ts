/**
 * Değerleme isteği 20–60 sn sürer. Aradaki vekil sunucu (Next/Vercel) bağlantıyı erken keserse
 * arka uç raporu yine de üretip krediyi düşer. Aynı istek numarasıyla (request_id) yeniden sormak
 * güvenlidir: arka uç aynı numaranın raporunu yeniden üretmez ve krediyi ikinci kez düşmez;
 * hazır raporu döndürür, rapor hâlâ hazırlanıyorsa bitmesini bekler.
 */

/** Yalnız taşıma hataları yeniden denenir: ağ hatası ya da kodsuz 5xx (vekil zaman aşımı). */
export function yenidenDenenebilir(err: unknown): boolean {
  if (err instanceof TypeError) return true; // fetch ağ hatası
  if (err && typeof err === "object" && "status" in err) {
    const { status, code } = err as { status?: number; code?: string };
    return typeof status === "number" && status >= 500 && status <= 504 && !code;
  }
  return false;
}

export const BAGLANTI_KOPTU_MESAJI =
  "Sunucuyla bağlantı koptu. Raporunuz hazırlanmış olabilir; birkaç dakika sonra Panel → Değerlemeler bölümünden kontrol edin. Kredi yalnız rapor üretildiyse düşer.";

export async function tekrarliIstek<T>(
  gonder: () => Promise<T>,
  { deneme = 6, beklemeMs = 4000, bekle = (ms: number) => new Promise<void>((r) => setTimeout(r, ms)) } = {},
): Promise<T> {
  for (let i = 1; ; i++) {
    try {
      return await gonder();
    } catch (err) {
      if (!yenidenDenenebilir(err)) throw err;
      if (i >= deneme) throw new Error(BAGLANTI_KOPTU_MESAJI);
      await bekle(beklemeMs);
    }
  }
}
