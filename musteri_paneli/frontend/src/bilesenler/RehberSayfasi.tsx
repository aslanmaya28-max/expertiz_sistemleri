import Link from "next/link";
import type { ReactNode } from "react";
import { ISLETME, SITE_URL, sssJsonLd, type SSS } from "@/lib/hizmetBilgisi";

export interface RehberBolumu {
  id: string;
  baslik: string;
  icerik: ReactNode;
}

interface RehberProps {
  slug: string;
  baslik: string;
  ozet: string;
  guncellemeTarihi: string;
  kisaca: string[];
  bolumler: RehberBolumu[];
  sorular: SSS[];
  cta: { href: string; etiket: string; aciklama: string };
  kaynaklar?: { ad: string; href: string }[];
}

/** JSON-LD içinde HTML kapanış etiketi oluşmasını önler. */
function jsonLd(value: unknown) {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}

export default function RehberSayfasi({
  slug, baslik, ozet, guncellemeTarihi, kisaca, bolumler, sorular, cta, kaynaklar = [],
}: RehberProps) {
  const canonical = `${SITE_URL}/rehber/${slug}`;
  const article = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: baslik,
    description: ozet,
    dateModified: guncellemeTarihi,
    author: ISLETME,
    publisher: ISLETME,
    inLanguage: "tr-TR",
    mainEntityOfPage: { "@type": "WebPage", "@id": canonical },
  };
  const breadcrumbs = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "YerimeBak", item: SITE_URL },
      { "@type": "ListItem", position: 2, name: "Rehber", item: `${SITE_URL}/rehber` },
      { "@type": "ListItem", position: 3, name: baslik, item: canonical },
    ],
  };

  return (
    <article className="max-w-5xl mx-auto px-4 sm:px-6 py-10">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd(article) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd(sssJsonLd(sorular)) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd(breadcrumbs) }} />

      <nav aria-label="İçerik yolu" className="mb-4 flex flex-wrap gap-2 text-sm text-metin-ikincil">
        <Link href="/" className="text-birincil underline">YerimeBak</Link>
        <span aria-hidden="true">/</span>
        <Link href="/rehber" className="text-birincil underline">Rehber</Link>
        <span aria-hidden="true">/</span>
        <span aria-current="page">{baslik}</span>
      </nav>
      <header className="rounded-2xl bg-white border border-kenarlik-acik p-6 sm:p-10">
        <p className="text-xs font-semibold tracking-widest text-birincil">ARAÇ ALIM REHBERİ</p>
        <h1 className="mt-2 text-3xl sm:text-4xl font-bold text-metin-birincil">{baslik}</h1>
        <p className="mt-4 max-w-3xl text-lg text-metin-ikincil">{ozet}</p>
        <p className="mt-3 text-sm text-metin-ikincil">
          Güncelleme: <time dateTime={guncellemeTarihi}>{guncellemeTarihi.split("-").reverse().join(".")}</time>
        </p>
        <nav aria-label="Sayfa içeriği" className="mt-6 flex flex-wrap gap-x-4 gap-y-2 text-sm">
          <a href="#kisaca" className="text-birincil underline">Kısaca</a>
          {bolumler.map((bolum) => <a key={bolum.id} href={`#${bolum.id}`} className="text-birincil underline">{bolum.baslik}</a>)}
          <a href="#sorular" className="text-birincil underline">Sık sorulan sorular</a>
        </nav>
      </header>

      <div className="mt-8 space-y-6">
        <section id="kisaca" aria-label="Kısaca" className="scroll-mt-24 rounded-xl bg-birincil/5 border border-birincil/30 p-6 sm:p-8">
          <h2 className="mb-4 text-xl font-semibold text-metin-birincil">Kısaca</h2>
          <ul className="list-disc space-y-2 pl-6 text-metin-birincil">
            {kisaca.map((madde) => <li key={madde}>{madde}</li>)}
          </ul>
        </section>
        {bolumler.map((bolum) => (
          <section key={bolum.id} id={bolum.id} aria-labelledby={`${bolum.id}-baslik`}
            className="scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8 text-[15px] leading-relaxed text-metin-birincil [&_ul]:list-disc [&_ul]:pl-6 [&_ol]:list-decimal [&_ol]:pl-6 [&_li]:mb-2 [&_p]:mb-3 [&_a]:text-birincil [&_a]:underline">
            <h2 id={`${bolum.id}-baslik`} className="mb-4 text-xl font-semibold">{bolum.baslik}</h2>
            {bolum.icerik}
          </section>
        ))}
        <section id="sorular" aria-labelledby="sorular-baslik" className="scroll-mt-24 rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
          <h2 id="sorular-baslik" className="mb-4 text-xl font-semibold text-metin-birincil">Sık sorulan sorular</h2>
          <div className="divide-y divide-kenarlik-acik">
            {sorular.map((soru) => (
              <details key={soru.soru} className="py-3">
                <summary className="cursor-pointer font-medium text-metin-birincil">{soru.soru}</summary>
                <p className="mt-2 text-[15px] leading-relaxed text-metin-ikincil">{soru.yanit}</p>
              </details>
            ))}
          </div>
        </section>
        {kaynaklar.length > 0 && (
          <section aria-labelledby="kaynaklar-baslik" className="rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
            <h2 id="kaynaklar-baslik" className="mb-3 text-xl font-semibold text-metin-birincil">Resmî kaynaklar</h2>
            <p className="mb-3 text-sm text-metin-ikincil">İşlem öncesinde hizmetin kapsamını ve güncel koşulları ilgili kurumdan kontrol edin.</p>
            <ul className="list-disc space-y-2 pl-6">
              {kaynaklar.map((kaynak) => <li key={kaynak.href}><a href={kaynak.href} target="_blank" rel="noopener noreferrer" className="text-birincil underline">{kaynak.ad}</a></li>)}
            </ul>
          </section>
        )}
        <section aria-label="İlgili hizmet" className="rounded-xl bg-birincil/5 border border-birincil/30 p-6 sm:p-8 text-center">
          <h2 className="text-xl font-semibold text-metin-birincil">Bir sonraki adımı bilgiyle atın</h2>
          <p className="mt-3 text-metin-ikincil">{cta.aciklama}</p>
          <Link href={cta.href} className="mt-5 inline-block rounded-lg bg-birincil px-5 py-3 font-semibold text-white">{cta.etiket}</Link>
        </section>
      </div>
    </article>
  );
}
