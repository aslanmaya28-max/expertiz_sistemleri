import type { Metadata } from "next";
import Link from "next/link";
import Ikon from "@/bilesenler/Ikon";
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
    <div className="yb-info-page yb-guide-list">
      <header className="yb-band yb-info-band">
        <p className="yb-band-label">REHBER</p>
        <h1 className="yb-info-title">İkinci el araç alım rehberi</h1>
        <p className="yb-info-intro">İlanı ilk gördüğünüz andan satın alma kararına kadar hangi bilgileri toplamanız ve doğrulatmanız gerektiğini bu rehberlerle değerlendirin.</p>
      </header>
      <ul className="yb-grid-2 yb-guide-cards">
        {REHBERLER.map((rehber) => (
          <li key={rehber.slug} className="yb-card yb-guide-card">
            <span className="yb-guide-icon"><Ikon ad="belge" /></span>
            <h2><Link href={`/rehber/${rehber.slug}`} className="yb-guide-link">{rehber.baslik}</Link></h2>
            <p className="yb-guide-summary">{rehber.ozet}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
