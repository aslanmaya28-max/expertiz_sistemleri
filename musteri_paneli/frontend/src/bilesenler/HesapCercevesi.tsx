import Image from "next/image";
import type { ReactNode } from "react";
import Ikon from "./Ikon";

export default function HesapCercevesi({ children }: { children: ReactNode }) {
  return <section className="yb-account"><div className="yb-wrap yb-account-grid">
    <aside className="yb-account-story" aria-label="YerimeBak ile inceleme süreciniz">
      <Image src="/images/arac-kokpit.jpg" alt="" fill loading="eager" sizes="(max-width: 760px) 100vw, 50vw" />
      <div><span className="yb-eyebrow">YERİNİZE BAKAN BİR EKİP VAR</span><h2>Mesafeler<br />arada kalmasın.<br /><em>Bilgi yanınızda olsun.</em></h2><p>Alanında uzman personelle yerinde inceleme. Tercihiniz doğrultusunda kurumsal ekspertiz. Tüm raporlar tek müşteri panelinde.</p></div>
      <div><div className="yb-account-promises"><span><Ikon ad="kontrol" /> Talebinizi ve sürecinizi takip edin.</span><span><Ikon ad="kontrol" /> Dört raporu aynı araç dosyasında inceleyin.</span><span><Ikon ad="kontrol" /> Fotoğraflara ve belgelere ulaşın.</span></div><div className="yb-account-foot">İstanbul’da pilot hizmet · Hedefimiz 81 il.<small>Fotoğraf temsili olarak kullanılmıştır.</small></div></div>
    </aside>
    <div className="yb-account-form">{children}</div>
  </div></section>;
}
