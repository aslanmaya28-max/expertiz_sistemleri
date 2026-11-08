import type { ValuationResult } from "@/lib/api";
import Ikon from "./Ikon";

function tl(value?: number | null) {
  return value == null ? "-" : new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

export default function FiyatOzeti({ sonuc }: { sonuc: ValuationResult }) {
  const { arac, degerleme, pazarlikPlani: plan, ozet } = sonuc;
  const range = degerleme.adilFiyatAraligi;
  const scale = range && Number.isFinite(range.min) && Number.isFinite(range.max) && range.min < range.max;
  const position = (value: number) => Math.max(0, Math.min(100, (value - range.min) / (range.max - range.min) * 100));
  const aiPosition = scale && Number.isFinite(degerleme.aiDegeri) ? position(degerleme.aiDegeri) : null;
  const listingPosition = scale && Number.isFinite(arac.ilanFiyati) ? position(arac.ilanFiyati) : null;
  return <>
    <section className="yb-report-card yb-fair-price" aria-label="Adil fiyat aralığı">
      <h2><Ikon ad="terazi" />Adil fiyat aralığı</h2>
      <p className="yb-price-range">{tl(range?.min)} <span>–</span> {tl(range?.max)}</p>
      {ozet && <p className="yb-summary-fair">Adil fiyat: {tl(ozet.adilFiyat.min)} – {tl(ozet.adilFiyat.max)}</p>}
      {scale && <div className="yb-price-scale" role="img" aria-label={`Adil fiyat ölçeği: ${tl(range.min)} ile ${tl(range.max)}. Hesaplanan değer ${tl(degerleme.aiDegeri)}. İlan fiyatı ${tl(arac.ilanFiyati)}${arac.ilanFiyati < range.min ? ', aralığın altında' : arac.ilanFiyati > range.max ? ', aralığın üstünde' : ''}.`}>
        <div className="yb-price-track">
          {aiPosition !== null && <span className="yb-ai-marker" data-marker="calculated" style={{ left: `${aiPosition}%` }} />}
          {listingPosition !== null && <span className="yb-listing-marker" data-marker="listing" style={{ left: `${listingPosition}%` }} />}
        </div>
        <div className="yb-scale-ends"><span>{tl(range.min)}</span><span>{tl(range.max)}</span></div>
      </div>}
      <dl className="yb-scale-key"><div><dt><i />Hesaplanan değer</dt><dd>{tl(degerleme.aiDegeri)}</dd></div><div><dt><i />İlan fiyatı</dt><dd>{tl(arac.ilanFiyati)}</dd></div></dl>
    </section>
    <section className="yb-report-card yb-listing-price" aria-label="İlan fiyatı ve alım hedefi">
      <div><h2><Ikon ad="etiket" />İlan fiyatı</h2><p className="yb-listed-value">{tl(arac.ilanFiyati)}</p>{ozet && <p className="yb-listing-position">{ozet.piyasaKonumu.metin}</p>}</div>
      <dl className="yb-price-targets"><div><dt>Tavsiye alım fiyatı</dt><dd data-price="target">{tl(plan?.hedefFiyat ?? degerleme.tavsiyeFiyat)}</dd></div>
        {plan && <div><dt>Üst sınırınız</dt><dd data-price="ceiling">{tl(plan.ustSinir)}</dd></div>}
      </dl>
    </section>
  </>;
}
