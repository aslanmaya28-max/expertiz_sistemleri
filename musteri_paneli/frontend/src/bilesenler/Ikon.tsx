import type { ReactNode, SVGProps } from "react";

export type IkonAdi = "ok" | "capraz-ok" | "kontrol" | "kalkan" | "arac" | "konum" | "belge" | "kamera" | "grafik" | "kisi" | "saat";
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
};
export default function Ikon({ ad, ...props }: SVGProps<SVGSVGElement> & { ad: IkonAdi }) {
  return <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{yollar[ad]}</svg>;
}
