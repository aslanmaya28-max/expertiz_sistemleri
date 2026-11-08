import type { Metadata } from "next";
import Link from "next/link";
import FiyatKartlari from "@/bilesenler/FiyatKartlari";
import DegerlemeKapsami from "@/bilesenler/DegerlemeKapsami";
import { BOLGE_YERINDE, HIZMET_BEDELI_TL, KDV_ORANI, SITE_URL } from "@/lib/hizmetBilgisi";

const tl = (n: number) => new Intl.NumberFormat("tr-TR").format(n) + " TL";

export const metadata: Metadata = {
  title: "Fiyatlar — araç değerleme raporu ve yerinde inceleme",
  description:
    "Araç değerleme raporu 1 kredi = 100 TL; 5 kredi 400 TL, 10 kredi 750 TL. Yerinde araç inceleme hizmet bedeli 5.000 TL + KDV; seçtiğiniz kurumsal ekspertiz paketi KDV dahil fiyatıyla eklenir, toplam ödemeden önce gösterilir.",
  alternates: { canonical: `${SITE_URL}/fiyatlar` },
};

export default function FiyatlarSayfasi() {
  return (
    <div className="yb-inner-page yb-pricing-page max-w-6xl mx-auto px-4 sm:px-6 py-10">
      <header className="yb-band">
        <h1>Fiyatlar</h1>
        <p>
          Araç değerleme raporu için kredi paketleri. 1 kredi = 1 rapor; yeterli benzer ilan bulunamazsa kredi düşülmez.
        </p>
      </header>
      <section aria-label="100 TL'ye neler alırsınız?" className="yb-pricing-lead">
        <div className="yb-card"><DegerlemeKapsami kisa /></div>
      </section>
      <FiyatKartlari />

      <section aria-labelledby="yerinde-ucret" className="yb-inspection-price">
        <div className="yb-card yb-card-mint">
          <h2 id="yerinde-ucret" className="mb-3">Yerinde araç inceleme ücreti</h2>
          <p className="yb-big-number">{tl(HIZMET_BEDELI_TL)}</p>
          <p className="yb-badge mt-3 mb-4">KDV hariç · KDV dahil {tl(HIZMET_BEDELI_TL * (1 + KDV_ORANI))}</p>
          <p className="mb-3">
            Yerinde inceleme kredi ile değil, talep başına ücretlendirilir. YerimeBak hizmet bedelinin KDV&apos;si ödeme
            adımında ayrı satır olarak eklenir. Seçtiğiniz kurumsal ekspertiz firmasının paket ücreti, firmanın KDV dahil
            fiyatıyla eklenir; pakete ayrıca KDV eklenmez. KDV dahil toplam tutar ödeme adımından önce açıkça gösterilir.
          </p>
          <p className="mb-4 text-metin-ikincil">Hizmet bölgesi: {BOLGE_YERINDE}.</p>
          <div className="yb-btn-row">
            <Link href="/ekspertiz-talebi" className="yb-btn yb-btn-green">Aracı yerinde incelet</Link>
            <Link href="/yerinde-inceleme" className="yb-btn yb-btn-outline">Hizmet ayrıntıları</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
