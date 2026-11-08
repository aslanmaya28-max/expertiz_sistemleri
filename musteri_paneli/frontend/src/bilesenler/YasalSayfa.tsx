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
    <div className="yb-info-page yb-legal-page">
      <header className="yb-band yb-info-band">
        <h1>{baslik}</h1>
        {guncelleme ? <p>Son güncelleme: {guncelleme}</p> : null}
      </header>
      <div className="yb-legal-layout">
        <nav aria-label="Kurumsal ve yasal sayfalar" className="yb-card yb-legal-nav">
          {YASAL_SAYFALAR.map((s) => (
            <Link key={s.href} href={s.href} aria-current={s.ad === baslik ? "page" : undefined}>
              {s.ad}
            </Link>
          ))}
        </nav>
        <article className="yb-card yb-info-prose yb-legal-content">
          {children}
        </article>
      </div>
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
    <div className="yb-company-table"><table>
      <tbody>
        {satirlar.map(([k, v]) => (
          <tr key={k}>
            <th scope="row">{k}</th>
            <td>{v}</td>
          </tr>
        ))}
      </tbody>
    </table></div>
  );
}
