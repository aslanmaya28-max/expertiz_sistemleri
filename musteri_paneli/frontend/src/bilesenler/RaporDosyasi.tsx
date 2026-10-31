import Link from "next/link";
import Ikon, { type IkonAdi } from "./Ikon";

const raporlar: { title: string; detail: string; icon: IkonAdi }[] = [
  { title: "İç ekspertiz", detail: "Kozmetik ve donanım bulguları", icon: "arac" },
  { title: "Dış ekspertiz", detail: "Boya, kaporta ve dış kozmetik", icon: "kamera" },
  { title: "Yapay zekâ değerleme", detail: "Araç bilgileri ve piyasa karşılaştırması", icon: "grafik" },
  { title: "Kurumsal ekspertiz", detail: "Tercih ettiğiniz firmanın raporu", icon: "kalkan" },
];

export default function RaporDosyasi() {
  return <section className="yb-dossier" data-report-scene data-sc-act="flow" data-sc-span="1.9" aria-labelledby="dosya-baslik">
    <div className="yb-dossier-stage" data-sc-stage>
      <div className="yb-wrap yb-dossier-layout">
        <div className="yb-dossier-copy">
          <span className="yb-eyebrow">DAĞINIK BİLGİDEN, BÜTÜN BİR DOSYAYA</span>
          <h2 id="dosya-baslik">Her açıdan inceleme.<br /><em>Hepsi elinizin altında.</em></h2>
          <p>Farklı kontroller, ortak bir amaç: aracı daha iyi tanımanız. Yönetim kontrolünden geçen dört rapor, ilgili araç talebinizin altında buluşur.</p>
          <Link href="/ornek-rapor" className="yb-text-link">Örnek raporu inceleyin <Ikon ad="capraz-ok" /></Link>
        </div>
        <div className="yb-folder" aria-label="Dört raporun müşteri panelinde bir araya gelmesini anlatan şema">
          <span className="yb-folder-label"><Ikon ad="belge" /> Müşteri paneliniz <small>İlgili araç dosyanız</small></span>
          <div className="yb-folder-papers">{raporlar.map((report, index) => <div className={`yb-report-paper yb-report-paper-${index}`} key={report.title}><Ikon ad={report.icon} /><div><strong>{report.title}</strong><span>{report.detail}</span></div><Ikon ad="belge" /></div>)}</div>
          <div className="yb-folder-footer"><Ikon ad="kalkan" /> Onaylanan raporlar, fotoğraflar ve belgeler.<span>Hizmet akışı gösterimi</span></div>
        </div>
      </div>
    </div>
  </section>;
}
