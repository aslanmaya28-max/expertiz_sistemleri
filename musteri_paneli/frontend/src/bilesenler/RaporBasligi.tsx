import Link from "next/link";
import type { ValuationResult } from "@/lib/api";
import Ikon, { type IkonAdi } from "./Ikon";
import Marka from "./Marka";

const STATUS = {
  altinda: { label: "Piyasanın altında", icon: "uyari" },
  uyumlu: { label: "Piyasayla uyumlu", icon: "kontrol" },
  ustunde: { label: "Piyasanın üstünde", icon: "grafik" },
} as const;

export default function RaporBasligi({ sonuc, ornek }: { sonuc: ValuationResult; ornek: boolean }) {
  const { arac, rapor, ozet, piyasa } = sonuc;
  const status = ozet?.piyasaKonumu?.durum ? STATUS[ozet.piyasaKonumu.durum] : undefined;
  return <>
    <header className="yb-report-header" aria-label="Değerleme raporu başlığı">
      <div className="yb-report-identity">
        <Marka acik />
        {rapor && <div className="yb-report-number"><Ikon ad="kalkan" />
          <div><strong>{rapor.report_no}</strong><time dateTime={rapor.created_at}>{new Date(rapor.created_at).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul" })}</time>
            {ornek ? <span>Örnek rapordur, doğrulanamaz.</span> : <Link href={`/dogrula/${encodeURIComponent(rapor.verification_code)}`}>Doğrulama kodu: {rapor.verification_code}</Link>}
          </div>
        </div>}
      </div>
      <div className="yb-report-heading-row">
        <div className="yb-report-vehicle">
          <span className="yb-report-type"><Ikon ad="belge" />Kredili değerleme raporu — uzman incelemesi içermez.</span>
          <h2>{arac.marka} {arac.model}</h2>
          {arac.paket && <p className="yb-report-package">{arac.paket}</p>}
          {!ornek && rapor && <Link className="yb-report-saved" href={`/panel/degerlemeler/${encodeURIComponent(rapor.id)}`}>Rapor kaydedildi — Raporlarım&apos;da</Link>}
        </div>
        {ozet && <div className="yb-market-position" data-position={ozet.piyasaKonumu.durum || "belirsiz"}>
          <span className="yb-position-symbol"><Ikon ad={(status?.icon || "grafik") as IkonAdi} /></span>
          <div><p>Piyasaya göre fiyatı</p>{status && <h3>{status.label}</h3>}<p>{ozet.piyasaKonumu.metin}</p>
            {[3, 4].includes(piyasa.emsalSayisi) && <small>Fiyatlar yön göstericidir.</small>}
          </div>
        </div>}
      </div>
    </header>
    <dl className="yb-report-chips" aria-label="Araç bilgileri">
      {([
        ["takvim", "Model yılı", arac.yil], ["yol", "Kilometre", `${new Intl.NumberFormat("tr-TR").format(arac.km)} km`],
        ["yakit", "Yakıt tipi", arac.yakit || "-"], ["vites", "Vites", arac.vites || "-"],
      ] as const).map(([icon, label, value]) => <div key={label}><Ikon ad={icon} /><div><dt>{label}</dt><dd>{value}</dd></div></div>)}
    </dl>
  </>;
}
