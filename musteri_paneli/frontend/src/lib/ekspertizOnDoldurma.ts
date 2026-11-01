/**
 * Değerleme raporundan "Bu aracı yerinde inceletelim" ile ekspertiz talep formuna geçiş.
 * Rapordaki araç bilgisi ve müşterinin beyanı sorgu parametresiyle taşınır; form tarafında
 * her değer yeniden doğrulanır (bağlantı başkası tarafından da üretilebilir).
 */

export interface RaporAraci {
  marka: string;
  model: string;
  paket?: string | null;
  yil?: number | null;
  km?: number | null;
  ilanFiyati?: number | null;
  yakit?: string | null;
  vites?: string | null;
  ilanLinki?: string | null;
  /** Parça anahtarı -> durum (lokal_boyali | boyali | degisen | orijinal); eski raporlarda yok */
  beyanEdilenParcalar?: Record<string, string> | null;
  tramerTutari?: number | null;
}

export interface EkspertizOnDoldurma {
  brand?: string;
  model?: string;
  package?: string;
  year?: string;
  km?: string;
  price?: string;
  fuel?: string;
  gear?: string;
  link?: string;
  declaredPainted?: string;
  declaredChanged?: string;
  declaredTramer?: string;
}

const METIN_ALANLARI = ["brand", "model", "package", "fuel", "gear"] as const;
const KONTROL_KARAKTERI = /[\u0000-\u001f\u007f]/;

/** Yalnız açık http/https adresleri; boşluk, kontrol karakteri ve kullanıcı bilgisi içeren adresler reddedilir. */
export function guvenliWebAdresi(value: unknown): string | undefined {
  if (typeof value !== "string" || value.length > 500) return undefined;
  if (/\s/.test(value) || KONTROL_KARAKTERI.test(value)) return undefined;
  if (!/^https?:\/\//i.test(value)) return undefined;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return undefined;
  }
  if (!url.hostname || url.username || url.password) return undefined;
  return value;
}

function metin(value: string | null): string | undefined {
  if (value == null) return undefined;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 120 || KONTROL_KARAKTERI.test(value)) return undefined;
  return trimmed;
}

function tamSayi(value: string | null, enFazlaHane: number, min: number, max: number): string | undefined {
  if (value == null || !new RegExp(`^\\d{1,${enFazlaHane}}$`).test(value)) return undefined;
  const sayi = Number(value);
  return Number.isSafeInteger(sayi) && sayi >= min && sayi <= max ? String(sayi) : undefined;
}

/** Sorgu parametrelerinden yalnız geçerli alanları döner; geçersiz olanlar atlanır. */
export function ekspertizOnDoldurma(params: URLSearchParams): EkspertizOnDoldurma {
  const out: EkspertizOnDoldurma = {};
  for (const alan of METIN_ALANLARI) {
    const deger = metin(params.get(alan));
    if (deger) out[alan] = deger;
  }
  const yil = tamSayi(params.get("year"), 4, 1950, new Date().getFullYear() + 1);
  if (yil) out.year = yil;
  const km = tamSayi(params.get("km"), 7, 0, 2_000_000);
  if (km) out.km = km;
  const fiyat = tamSayi(params.get("price"), 10, 1, 1_000_000_000);
  if (fiyat) out.price = fiyat;
  const link = guvenliWebAdresi(params.get("link"));
  if (link) out.link = link;
  const boyali = tamSayi(params.get("declaredPainted"), 2, 0, 30);
  if (boyali) out.declaredPainted = boyali;
  const degisen = tamSayi(params.get("declaredChanged"), 2, 0, 30);
  if (degisen) out.declaredChanged = degisen;
  const tramer = tamSayi(params.get("declaredTramer"), 9, 0, 100_000_000);
  if (tramer) out.declaredTramer = tramer;
  return out;
}

/** Rapordaki araçtan ön doldurulmuş ekspertiz talep adresi. Beyan yoksa uydurulmaz. */
export function ekspertizTalepAdresi(arac: RaporAraci): string {
  const params = new URLSearchParams();
  const ekle = (anahtar: string, deger: unknown) => {
    if (deger === null || deger === undefined || deger === "") return;
    params.set(anahtar, String(deger));
  };
  ekle("brand", arac.marka);
  ekle("model", arac.model);
  ekle("package", arac.paket);
  ekle("year", arac.yil);
  ekle("km", arac.km);
  ekle("price", arac.ilanFiyati);
  ekle("fuel", arac.yakit);
  ekle("gear", arac.vites);
  ekle("link", guvenliWebAdresi(arac.ilanLinki));
  if (arac.beyanEdilenParcalar) {
    const durumlar = Object.values(arac.beyanEdilenParcalar);
    ekle("declaredPainted", durumlar.filter((d) => d === "boyali" || d === "lokal_boyali").length);
    ekle("declaredChanged", durumlar.filter((d) => d === "degisen").length);
    ekle("declaredTramer", arac.tramerTutari ?? 0);
  }
  return `/ekspertiz-talebi?${params.toString()}`;
}
