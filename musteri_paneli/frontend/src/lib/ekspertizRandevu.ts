import type { ExpertizCity } from "./api";

export const BULUNAMAMA_ONAYI = "Araç belirtilen adreste bulunamazsa hizmet bedeli iade edilmez; kurumsal ekspertiz paket ücreti iade edilir.";
export const BULUNAMAMA_ROZETI = "Araç adreste bulunamadı — paket ücreti iade edildi";
export type RandevuAlani = "city" | "appointment_at" | "address" | "seller_phone" | "not_found_accepted";
export type RandevuHatalari = Partial<Record<RandevuAlani, string>>;

/** API'nin saat dilimsiz tarihleri İstanbul duvar saatidir. Cihazın dilimini kullanmayın. */
export function randevuZamani(value: string): Date | null {
  const naive = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$/.test(value);
  const date = new Date(naive ? `${value}+03:00` : value);
  if (!Number.isFinite(date.getTime())) return null;
  if (naive && istanbulYerel(date) !== value.slice(0, 16)) return null;
  return date;
}

function istanbulYerel(date: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Istanbul", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(date);
  const part = (key: string) => parts.find((p) => p.type === key)?.value;
  return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}`;
}

export function randevuSinirlari(now = new Date()) {
  return { min: istanbulYerel(new Date(Math.ceil((now.getTime() + 2 * 3600000) / 60000) * 60000)), max: istanbulYerel(new Date(now.getTime() + 30 * 86400000)) };
}

export function randevuMetni(value?: string | null): string {
  const date = value ? randevuZamani(value) : null;
  return date ? new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", dateStyle: "medium", timeStyle: "short" }).format(date) + " (İstanbul saati)" : "—";
}

const HATA_ALANLARI: Record<string, RandevuAlani> = { il_kapali: "city", randevu_gecersiz: "appointment_at", adres_eksik: "address", satici_telefon_gecersiz: "seller_phone", bulunamama_onayi_gerekli: "not_found_accepted" };
export function randevuHataAlani(code?: string): RandevuAlani | undefined { return code ? HATA_ALANLARI[code] : undefined; }

export function randevuDogrula(value: {city: string; appointment_at: string; address: string; seller_phone: string; not_found_accepted: boolean}, cities: ExpertizCity[], now = new Date()): RandevuHatalari {
  const errors: RandevuHatalari = {};
  if (!cities.some((c) => c.il === value.city && c.talep_acabilir)) errors.city = "Bu ilde henüz hizmet yok";
  const date = randevuZamani(value.appointment_at);
  if (!date || date.getTime() < now.getTime() + 2 * 3600000 || date.getTime() > now.getTime() + 30 * 86400000) errors.appointment_at = "Randevuyu İstanbul saatiyle en erken 2 saat sonrası, en geç 30 gün sonrası için seçin.";
  if (value.address.trim().length < 10 || value.address.trim().length > 300) errors.address = "Açık adres / buluşma noktası 10–300 karakter olmalıdır.";
  let phone = value.seller_phone.replace(/\D/g, "").replace(/^90(?=\d{10}$)/, "");
  if (phone.length === 10) phone = `0${phone}`;
  if (!/^0\d{10}$/.test(phone)) errors.seller_phone = "Geçerli bir Türkiye cep veya sabit telefon numarası girin.";
  if (!value.not_found_accepted) errors.not_found_accepted = "Devam etmek için bulunamama koşulunu ayrıca onaylayın.";
  return errors;
}
export function bulunamamaDurumu(durumKodu?: string, paymentStatus?: string): string | null {
  if (durumKodu !== "vehicle_not_found") return null;
  return paymentStatus === "partially_refunded" || paymentStatus === "refunded" ? BULUNAMAMA_ROZETI : "Araç adreste bulunamadı — paket ücreti iade sürecinde";
}
