import type { Metadata } from "next";
import Link from "next/link";
import { SITE_URL } from "@/lib/hizmetBilgisi";

export const metadata: Metadata = {
  title: "İkinci el araç alım rehberi",
  description: "İkinci el araç alırken kontrol listesi, tramer kaydı, boyalı ve değişen parçalar ile ilan fiyatını değerlendirmek için rehberler.",
  alternates: { canonical: `${SITE_URL}/rehber` },
};

const REHBERLER = [
  {
    slug: "ikinci-el-arac-alirken-kontrol-listesi",
    baslik: "İkinci el araç alırken kontrol listesi",
    ozet: "İlanı incelerken, satıcıyla görüşürken, araç başında ve satışa hazırlanırken kontrol edilecek bilgileri adım adım ele alın.",
  },
  {
    slug: "tramer-kaydi-nedir",
    baslik: "Tramer kaydı nedir?",
    ozet: "Hasar kaydının hangi sorulara cevap verdiğini, sınırlarını ve fiyat değerlendirmesinde neden tek başına yeterli olmadığını öğrenin.",
  },
  {
    slug: "boyali-degisen-parca-fiyat-etkisi",
    baslik: "Boyalı ve değişen parçanın fiyata etkisi",
    ozet: "Lokal boya, boyalı ve değişen parça arasındaki farkları, kritik parçaları ve satıcı beyanını doğrulatmanın önemini inceleyin.",
  },
  {
    slug: "ilan-fiyati-dogru-mu-nasil-anlasilir",
    baslik: "İlan fiyatı doğru mu, nasıl anlaşılır?",
    ozet: "Benzer ilanları model, kasa, motor, yıl, kilometre ve hasar bilgisiyle karşılaştırarak pazarlığa hazırlanın.",
  },
];

export default function RehberListesiSayfasi() {
  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-10">
      <header className="rounded-2xl bg-white border border-kenarlik-acik p-6 sm:p-10">
        <p className="text-xs font-semibold tracking-widest text-birincil">REHBER</p>
        <h1 className="mt-2 text-3xl sm:text-4xl font-bold text-metin-birincil">İkinci el araç alım rehberi</h1>
        <p className="mt-4 max-w-3xl text-lg text-metin-ikincil">İlanı ilk gördüğünüz andan satın alma kararına kadar hangi bilgileri toplamanız ve doğrulatmanız gerektiğini bu rehberlerle değerlendirin.</p>
      </header>
      <ul className="mt-8 grid gap-6 sm:grid-cols-2">
        {REHBERLER.map((rehber) => (
          <li key={rehber.slug} className="rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8">
            <h2 className="text-xl font-semibold text-metin-birincil"><Link href={`/rehber/${rehber.slug}`} className="text-birincil underline">{rehber.baslik}</Link></h2>
            <p className="mt-3 text-[15px] leading-relaxed text-metin-ikincil">{rehber.ozet}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
