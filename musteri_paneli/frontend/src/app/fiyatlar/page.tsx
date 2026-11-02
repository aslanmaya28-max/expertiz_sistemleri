import type { Metadata } from "next";
import Link from "next/link";
import FiyatKartlari from "@/bilesenler/FiyatKartlari";
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
    <div>
      <div className="max-w-7xl mx-auto px-4 py-8 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Fiyatlar</h1>
        <p className="text-metin-ikincil mt-2">
          Araç değerleme raporu için kredi paketleri. 1 kredi = 1 rapor; yeterli benzer ilan bulunamazsa kredi düşülmez.
        </p>
      </div>
      <FiyatKartlari />

      <section aria-labelledby="yerinde-ucret" className="max-w-3xl mx-auto px-4 pb-12">
        <div className="rounded-xl bg-white border border-kenarlik-acik p-6 sm:p-8 text-[15px] leading-relaxed text-metin-birincil">
          <h2 id="yerinde-ucret" className="mb-3 text-xl font-semibold">Yerinde araç inceleme ücreti</h2>
          <p className="text-3xl font-bold">{tl(HIZMET_BEDELI_TL)}</p>
          <p className="mb-4 text-xs text-metin-ikincil">KDV hariç · KDV dahil {tl(HIZMET_BEDELI_TL * (1 + KDV_ORANI))}</p>
          <p className="mb-3">
            Yerinde inceleme kredi ile değil, talep başına ücretlendirilir. YerimeBak hizmet bedelinin KDV&apos;si ödeme
            adımında ayrı satır olarak eklenir. Seçtiğiniz kurumsal ekspertiz firmasının paket ücreti, firmanın KDV dahil
            fiyatıyla eklenir; pakete ayrıca KDV eklenmez. KDV dahil toplam tutar ödeme adımından önce açıkça gösterilir.
          </p>
          <p className="mb-4 text-metin-ikincil">Hizmet bölgesi: {BOLGE_YERINDE}.</p>
          <div className="flex flex-wrap gap-3">
            <Link href="/ekspertiz-talebi" className="rounded-lg bg-birincil px-5 py-3 font-semibold text-white">Aracı yerinde incelet</Link>
            <Link href="/yerinde-inceleme" className="rounded-lg border border-kenarlik-acik px-5 py-3 font-semibold text-metin-birincil">Hizmet ayrıntıları</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
