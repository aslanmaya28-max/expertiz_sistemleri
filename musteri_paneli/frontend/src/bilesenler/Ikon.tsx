import type { ReactNode, SVGProps } from "react";

export type IkonAdi = "ok" | "capraz-ok" | "kontrol" | "kalkan" | "arac" | "konum" | "belge" | "kamera" | "grafik" | "kisi" | "saat" | "takvim" | "yol" | "yakit" | "vites" | "terazi" | "etiket" | "uyari" | "ampul" | "motor" | "anahtar";
const yollar: Record<IkonAdi, ReactNode> = {
  ok: <path d="M4 12h15M13 5l7 7-7 7" />,
  "capraz-ok": <path d="M5 19 19 5M5 5h14v14" />,
  kontrol: <path d="m5 12 4 4L19 6" />,
  kalkan: <><path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z" /><path d="m8 12 3 3 5-6" /></>,
  arac: <path d="m5 7 2-4h10l2 4 2 3v8H3v-8l2-3ZM5 7h14M3 12h18M6 18v3m12-3v3M6 15h2m8 0h2" />,
  konum: <><path d="M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0Z" /><circle cx="12" cy="10" r="2.5" /></>,
  belge: <path d="M14 3H5v18h14V8l-5-5Zm0 0v5h5M8 12h8m-8 4h6" />,
  kamera: <><path d="m8 6 2-3h4l2 3h5v14H3V6h5Z" /><circle cx="12" cy="13" r="4" /></>,
  grafik: <path d="M4 3v18h17M8 16l4-5 4 2 5-8" />,
  kisi: <><circle cx="12" cy="7" r="4" /><path d="M4 21v-2a8 8 0 0 1 16 0v2" /></>,
  saat: <><circle cx="12" cy="12" r="9" /><path d="M12 6v6l4 2" /></>,
  takvim: <><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M7 3v4m10-4v4M3 11h18M7 15h2m4 0h2m-8 3h2" /></>,
  yol: <><path d="m8 3-5 18h18L16 3M12 3v3m0 4v3m0 4v4" /></>,
  yakit: <><path d="M3 21h12M5 21V4h9v17M5 10h9m0-4 4 4v6a2 2 0 0 0 4 0v-5l-3-4" /></>,
  vites: <><circle cx="5" cy="4" r="2" /><circle cx="12" cy="4" r="2" /><circle cx="19" cy="4" r="2" /><circle cx="5" cy="20" r="2" /><path d="M5 6v12M12 6v7M19 6v7H5" /></>,
  terazi: <><path d="M12 3v18M7 21h10M4 6h16M5 6l-3 8h6L5 6Zm14 0-3 8h6l-3-8Z" /></>,
  etiket: <><path d="M3 12V3h9l9 9-9 9-9-9Z" /><circle cx="8" cy="8" r="1" /></>,
  uyari: <><path d="m12 3 10 18H2L12 3Zm0 6v5m0 3h.01" /></>,
  ampul: <><path d="M8 16a7 7 0 1 1 8 0v3H8v-3Zm1 6h6M12 1v2M1 10h2m18 0h2" /></>,
  motor: <path d="M5 8h3l2-3h7v3h4v10H7l-2-3H2V8h3ZM10 2h5M1 5v3m0 7v4M10 11h5m-2-2v4" />,
  anahtar: <path d="m14 4 3 3 4-2a7 7 0 0 1-8 9l-7 7-3-3 7-7a7 7 0 0 1 4-9Z" />,
};
export default function Ikon({ ad, ...props }: SVGProps<SVGSVGElement> & { ad: IkonAdi }) {
  return <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{yollar[ad]}</svg>;
}
