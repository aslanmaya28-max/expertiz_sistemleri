import { connection } from "next/server";

/** Yasal sayfalarda ve iletisimde gorunen sirket bilgileri (.env, calisma aninda okunur). */
export interface SirketBilgisi {
  unvan: string;
  adres: string;
  vergiDairesi: string;
  vergiNo: string;
  mersis: string;
  telefon: string;
  eposta: string;
  kep: string;
  kvkkEposta: string;
  site: string;
}

const BOS = "—";

export async function sirketBilgisi(): Promise<SirketBilgisi> {
  // Derleme aninda degil, istek aninda okunur (Docker'da .env sonradan verilir)
  await connection();
  const env = (key: string) => (process.env[key] || "").trim();
  return {
    unvan: env("COMPANY_TITLE") || "YerimeBak",
    adres: env("COMPANY_ADDRESS") || BOS,
    vergiDairesi: env("COMPANY_TAX_OFFICE") || BOS,
    vergiNo: env("COMPANY_TAX_NUMBER") || BOS,
    mersis: env("COMPANY_MERSIS") || BOS,
    telefon: env("COMPANY_PHONE") || BOS,
    eposta: env("COMPANY_EMAIL") || "info@yerimebak.com.tr",
    kep: env("COMPANY_KEP") || BOS,
    kvkkEposta: env("COMPANY_KVKK_EMAIL") || env("COMPANY_EMAIL") || "kvkk@yerimebak.com.tr",
    site: "https://www.yerimebak.com.tr",
  };
}
