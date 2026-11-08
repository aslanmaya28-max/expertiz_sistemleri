import Link from "next/link";
import type { ReactNode } from "react";
import { SITE_URL, sssJsonLd, type SSS } from "@/lib/hizmetBilgisi";
import ScrollSahnesi from "./ScrollSahnesi";
import Ikon from "./Ikon";

export interface HizmetBolumu { id: string; baslik: string; icerik: ReactNode }

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
  return (
    <ScrollSahnesi className="yb-service-page max-w-5xl mx-auto px-4 sm:px-6 py-10">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({ "@context": "https://schema.org", ...hizmetJsonLd }) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(sssJsonLd(sorular)) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
        "@context": "https://schema.org", "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "YerimeBak", item: SITE_URL },
          { "@type": "ListItem", position: 2, name: baslik },
        ],
      }) }} />

      <header data-sc-in className="yb-service-hero rounded-2xl bg-white border border-kenarlik-acik p-6 sm:p-10">
        <p className="text-xs font-semibold tracking-widest text-birincil">{ust}</p>
        <h1 className="mt-2 text-3xl sm:text-4xl font-bold text-metin-birincil">{baslik}</h1>
        <p className="mt-4 max-w-3xl text-lg text-metin-ikincil">{ozet}</p>
        <p className="mt-3 text-sm font-medium text-metin-birincil">Hizmet bölgesi: {bolge}</p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link href={birincil.href} className="yb-button yb-button-dark">{birincil.etiket}<Ikon ad="capraz-ok" /></Link>
          {ikincil && <Link href={ikincil.href} className="rounded-lg border border-kenarlik-acik px-5 py-3 font-semibold text-metin-birincil">{ikincil.etiket}</Link>}
        </div>
        <nav aria-label="Sayfa içeriği" className="mt-6 flex flex-wrap gap-x-4 gap-y-1 text-sm">
          {onBolum && <a href={`#${onBolum.id}`} className="text-birincil underline">{onBolum.baslik}</a>}
          {bolumler.map((b) => <a key={b.id} href={`#${b.id}`} className="text-birincil underline">{b.baslik}</a>)}
          <a href="#sorular" className="text-birincil underline">Sık sorulan sorular</a>
        </nav>
      </header>

      <div className="mt-8 space-y-6">
        {onBolum && (
          <section id={onBolum.id} aria-labelledby={`${onBolum.id}-baslik`} data-sc-in
            className="yb-service-lead scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
            <h2 id={`${onBolum.id}-baslik`} className="mb-4 text-2xl font-bold text-metin-birincil">{onBolum.baslik}</h2>
            {onBolum.icerik}
          </section>
        )}
        <div className="yb-service-stack" data-stack>
        {bolumler.map((b, index) => (
          <section key={b.id} id={b.id} aria-labelledby={`${b.id}-baslik`}
            data-sc-in style={{ "--yb-stack-index": index, "--yb-entry-delay": `${50 + Math.min(index, 5) * 50}ms` } as React.CSSProperties}
            className={`${index < 4 ? "yb-stack-card" : "yb-service-section"} scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8 text-[15px] leading-relaxed text-metin-birincil [&_ul]:list-disc [&_ul]:pl-6 [&_ol]:list-decimal [&_ol]:pl-6 [&_li]:mb-1.5 [&_p]:mb-3`}>
            <h2 id={`${b.id}-baslik`} className="mb-4 text-xl font-semibold">{b.baslik}</h2>
            {b.icerik}
          </section>
        ))}
        </div>

        <section id="sorular" aria-labelledby="sorular-baslik" className="scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
          <h2 id="sorular-baslik" className="mb-4 text-xl font-semibold text-metin-birincil">Sık sorulan sorular</h2>
          <div className="divide-y divide-kenarlik-acik">
            {sorular.map((s) => (
              <details key={s.soru} className="py-3">
                <summary className="cursor-pointer font-medium text-metin-birincil">{s.soru}</summary>
                <p className="mt-2 text-[15px] leading-relaxed text-metin-ikincil">{s.yanit}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="rounded-xl bg-birincil/5 border border-birincil/30 p-6 sm:p-8 text-center">
          <p className="text-lg font-semibold text-metin-birincil">Karar sizin. Bilgiyi bir araya getirmek bizim işimiz.</p>
          <div className="mt-4 flex flex-wrap justify-center gap-3">
            <Link href={birincil.href} className="yb-button yb-button-dark">{birincil.etiket}<Ikon ad="capraz-ok" /></Link>
            {ikincil && <Link href={ikincil.href} className="rounded-lg border border-kenarlik-acik bg-white px-5 py-3 font-semibold text-metin-birincil">{ikincil.etiket}</Link>}
          </div>
        </section>
      </div>
    </ScrollSahnesi>
  );
}
