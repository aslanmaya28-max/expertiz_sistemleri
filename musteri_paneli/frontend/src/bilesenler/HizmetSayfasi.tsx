import Link from "next/link";
import { Children, cloneElement, isValidElement, type ReactNode } from "react";
import { SITE_URL, sssJsonLd, HIZMET_BEDELI_TL, KREDI_PAKETLERI, type SSS } from "@/lib/hizmetBilgisi";
import ScrollSahnesi from "./ScrollSahnesi";
import Ikon from "./Ikon";

export interface HizmetBolumu { id: string; baslik: string; icerik: ReactNode }

/** Kayan yığına giren ilk bölüm sayısı; sonrakiler normal akar. */
const bolumIkonu = (id: string) =>
  id === "kimler-icin" ? "kisi" : id === "nasil-isler" ? "yol" : id === "ucret" ? "etiket" : id === "bolge" ? "konum" : "belge";

const YIGIN_KART = 4;

function bolumKarti(b: HizmetBolumu, index: number, yigin: boolean) {
  return (
    <section key={b.id} id={b.id} aria-labelledby={`${b.id}-baslik`}
      data-sc-in style={{ "--yb-stack-index": index, "--yb-entry-delay": `${50 + Math.min(index, 5) * 50}ms` } as React.CSSProperties}
      className={`yb-card yb-service-section-card ${yigin ? "yb-stack-card" : ""} yb-service-${b.id} ${b.id === "kimler-icin" ? "yb-card-mint" : b.id === "teslim" ? "yb-card-accent" : b.id === "ucret" ? "yb-card-mint" : ""} scroll-mt-24`}>
      <h2 id={`${b.id}-baslik`}><Ikon ad={bolumIkonu(b.id)} />{b.baslik}</h2>
      {bolumIcerigi(b.icerik, b.id)}
      {/* Yığında kartlar eşit boydadır; kısa kartın boşluğunu soluk büyük simge doldurur. */}
      {yigin && <span className="yb-stack-watermark" aria-hidden="true"><Ikon ad={bolumIkonu(b.id)} /></span>}
    </section>
  );
}

/**
 * Hizmet sayfası iskeleti: "Kimler için, Neleri kapsar, Nasıl işler, Ne teslim edilir, Ücret, Bölge"
 * bölümleri düz metin (arama motorları ve yapay zekâlar okuyabilsin), sık sorulan sorular ve
 * yapılandırılmış veri (Service + FAQPage).
 */
export default function HizmetSayfasi({
  ust, baslik, ozet, bolge, birincil, ikincil, bolumler, sorular, hizmetJsonLd, onBolum,
}: {
  ust: string;
  baslik: string;
  ozet: string;
  bolge: string;
  birincil: { href: string; etiket: string };
  ikincil?: { href: string; etiket: string };
  bolumler: HizmetBolumu[];
  sorular: SSS[];
  hizmetJsonLd: Record<string, unknown>;
  /** Başlığın hemen altında, kart yığınının dışında gösterilen bölüm (uzun içerik yığını bozmasın). */
  onBolum?: { id: string; baslik: string; icerik: React.ReactNode };
}) {
  const cevrimIci = hizmetJsonLd.url === `${SITE_URL}/arac-degerleme`;
  const chips = cevrimIci ? [
    ["etiket", "1 rapor", `${KREDI_PAKETLERI[0].fiyat} TL`], ["konum", "Hizmet bölgesi", "Türkiye geneli"],
    ["saat", "Rapor süresi", "1 dakikadan kısa"], ["belge", "Teslim", "PDF + doğrulama kodu"],
  ] : [
    ["etiket", "Hizmet bedeli", `${HIZMET_BEDELI_TL.toLocaleString("tr-TR")} TL + KDV`],
    ["konum", "Hizmet bölgesi", "İstanbul (iki yaka)"], ["kisi", "İnceleme", "Uzman personel"], ["belge", "Teslim", "Müşteri panelinde rapor"],
  ];
  const split = baslik.includes("? ") ? baslik.indexOf("? ") + 1 : baslik.includes(", ") ? baslik.indexOf(", ") + 1 : -1;
  return (
    <ScrollSahnesi className="yb-service-page yb-inner-page max-w-6xl mx-auto px-4 sm:px-6 py-10">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({ "@context": "https://schema.org", ...hizmetJsonLd }) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(sssJsonLd(sorular)) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
        "@context": "https://schema.org", "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "YerimeBak", item: SITE_URL },
          { "@type": "ListItem", position: 2, name: baslik },
        ],
      }) }} />

      <header data-sc-in className="yb-band yb-service-band">
        <span className="yb-band-label"><Ikon ad={cevrimIci ? "grafik" : "kalkan"} />{ust}</span>
        <h1>{split > 0 ? <>{baslik.slice(0, split)}<span className="yb-band-accent">{baslik.slice(split)}</span></> : baslik}</h1>
        <p>{ozet}</p>
        <div className="yb-btn-row">
          <Link href={birincil.href} className="yb-btn yb-btn-mint">{birincil.etiket}<Ikon ad="capraz-ok" /></Link>
          {ikincil && <Link href={ikincil.href} className="yb-btn yb-btn-ghost">{ikincil.etiket}</Link>}
        </div>
      </header>
      <dl className="yb-chips yb-service-chips" aria-label="Hizmet özeti">{chips.map(([icon, label, value]) => <div key={label}><Ikon ad={icon as Parameters<typeof Ikon>[0]["ad"]} /><div><dt>{label}</dt><dd>{value}</dd></div></div>)}</dl>
      <p className="yb-service-region">Hizmet bölgesi: {bolge}</p>
        <nav aria-label="Sayfa içeriği" className="yb-service-links">
          {onBolum && <a href={`#${onBolum.id}`} className="text-birincil underline">{onBolum.baslik}</a>}
          {bolumler.map((b) => <a key={b.id} href={`#${b.id}`} className="text-birincil underline">{b.baslik}</a>)}
          <a href="#sorular" className="text-birincil underline">Sık sorulan sorular</a>
        </nav>

      <div className="mt-8 space-y-6">
        {onBolum && (
          <section id={onBolum.id} aria-labelledby={`${onBolum.id}-baslik`} data-sc-in
            className="yb-service-lead scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
            <h2 id={`${onBolum.id}-baslik`} className="mb-4 text-2xl font-bold text-metin-birincil">{onBolum.baslik}</h2>
            {onBolum.icerik}
          </section>
        )}
        {/* Yalnız ilk dört kart yığılır ve kendi kapsayıcısındadır: yapışkan kartlar bu kapsayıcı bitince
            birlikte kayar, sonraki bölümler üstlerinden geçmez (10.11.2026 "iç içe geçme" düzeltmesi). */}
        <div className="yb-service-stack" data-stack>
          {bolumler.slice(0, YIGIN_KART).map((b, index) => bolumKarti(b, index, true))}
        </div>
        {bolumler.slice(YIGIN_KART).map((b, index) => bolumKarti(b, YIGIN_KART + index, false))}

        <section id="sorular" aria-labelledby="sorular-baslik" className="yb-card yb-service-faq scroll-mt-24">
          <h2 id="sorular-baslik">Sık sorulan sorular</h2>
          <div className="divide-y divide-kenarlik-acik">
            {sorular.map((s) => (
              <details key={s.soru} className="py-3">
                <summary className="cursor-pointer font-medium text-metin-birincil">{s.soru}</summary>
                <p className="mt-2 text-[15px] leading-relaxed text-metin-ikincil">{s.yanit}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="yb-band yb-cta-band yb-service-cta">
          <h2>Karar sizin. Bilgiyi bir araya getirmek bizim işimiz.</h2>
          <div className="yb-btn-row">
            <Link href={birincil.href} className="yb-btn yb-btn-mint">{birincil.etiket}<Ikon ad="capraz-ok" /></Link>
            {ikincil && <Link href={ikincil.href} className="yb-btn yb-btn-ghost">{ikincil.etiket}</Link>}
          </div>
        </section>
      </div>
    </ScrollSahnesi>
  );
}

/** Mevcut bölüm metnini aynen koruyarak yalnız liste sunumunu değiştirir. */
function bolumIcerigi(content: ReactNode, id: string): ReactNode {
  return Children.map(content, (child) => {
    if (!isValidElement<{ children?: ReactNode; className?: string }>(child)) return child;
    if (child.type === "ul" || child.type === "ol") {
      const className = id === "nasil-isler" ? "yb-step-list" : id === "kapsam" ? "yb-service-features yb-grid-2" : "yb-check-list";
      const children = id === "nasil-isler" || id === "kapsam" ? Children.map(child.props.children, (item) =>
        isValidElement<{ children?: ReactNode }>(item) && item.type === "li"
          ? cloneElement(item, {}, <>{id === "kapsam" && <Ikon ad="kontrol" />}<div>{item.props.children}</div></>) : item) : child.props.children;
      return cloneElement(child, { className: `${child.props.className || ""} ${className}`.trim() }, children);
    }
    return child.props.children ? cloneElement(child, {}, bolumIcerigi(child.props.children, id)) : child;
  });
}
