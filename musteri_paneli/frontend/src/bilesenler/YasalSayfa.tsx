import Link from "next/link";
import type { ReactNode } from "react";

export const YASAL_SAYFALAR = [
  { href: "/hakkimizda", ad: "Hakkımızda" },
  { href: "/iletisim", ad: "İletişim" },
  { href: "/kvkk", ad: "KVKK Aydınlatma Metni" },
  { href: "/gizlilik", ad: "Gizlilik ve Çerez Politikası" },
  { href: "/kullanim-kosullari", ad: "Kullanım Koşulları" },
  { href: "/mesafeli-satis", ad: "Mesafeli Satış Sözleşmesi" },
  { href: "/iptal-iade", ad: "İptal ve İade Koşulları" },
];

/** Yasal metin sayfasi cercevesi: baslik, guncelleme tarihi, yan menu. */
export default function YasalSayfa({ baslik, guncelleme, children }: { baslik: string; guncelleme?: string; children: ReactNode }) {
  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10 grid gap-8 lg:grid-cols-[220px_1fr]">
      <nav className="text-sm space-y-1 lg:sticky lg:top-24 h-fit">
        {YASAL_SAYFALAR.map((s) => (
          <Link key={s.href} href={s.href} className="block rounded-md px-3 py-2 text-metin-ikincil hover:bg-gray-50 hover:text-birincil">
            {s.ad}
          </Link>
        ))}
      </nav>
      <article className="bg-white border border-kenarlik-acik rounded-xl p-6 sm:p-8 text-[15px] leading-relaxed text-metin-birincil [&_h2]:mt-8 [&_h2]:mb-3 [&_h2]:text-lg [&_h2]:font-semibold [&_p]:mb-3 [&_ul]:mb-3 [&_ul]:list-disc [&_ul]:pl-6 [&_li]:mb-1 [&_table]:w-full [&_td]:border [&_td]:border-kenarlik-acik [&_td]:px-3 [&_td]:py-2 [&_th]:border [&_th]:border-kenarlik-acik [&_th]:px-3 [&_th]:py-2 [&_th]:bg-gray-50 [&_th]:text-left">
        <h1 className="text-2xl font-bold">{baslik}</h1>
        {guncelleme ? <p className="mt-1 text-sm text-metin-ikincil">Son güncelleme: {guncelleme}</p> : null}
        <div className="mt-6">{children}</div>
      </article>
    </div>
  );
}

/** Sirket kimlik tablosu (veri sorumlusu / satici bilgileri). */
export function SirketTablosu({ s }: { s: { unvan: string; adres: string; vergiDairesi: string; vergiNo: string; mersis: string; telefon: string; eposta: string; kep: string } }) {
  const satirlar: [string, string][] = [
    ["Ünvan", s.unvan],
    ["Adres", s.adres],
    ["Vergi dairesi / no", `${s.vergiDairesi} / ${s.vergiNo}`],
    ["MERSİS no", s.mersis],
    ["Telefon", s.telefon],
    ["E-posta", s.eposta],
    ["KEP adresi", s.kep],
  ];
  return (
    <table>
      <tbody>
        {satirlar.map(([k, v]) => (
          <tr key={k}>
            <th className="w-48">{k}</th>
            <td>{v}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
