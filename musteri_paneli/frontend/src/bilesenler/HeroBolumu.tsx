import Image from "next/image";
import Ikon from "./Ikon";
import IncelemeBaglantisi, { HesapBaglantisi, UyelikNotu } from "./IncelemeBaglantisi";

export default function HeroBolumu() {
  return (
    <section className="yb-hero" data-sc-act="flow" aria-labelledby="ana-baslik">
      <div className="yb-wrap yb-hero-grid">
        <div className="yb-hero-copy">
          <span className="yb-pilot"><span /> İstanbul’da pilot hizmet</span>
          <h1 id="ana-baslik">Siz gitmeden,<br />biz <em>yerinize</em><br />bakalım.</h1>
          <p className="yb-hero-description">Aklınızdaki araca, alanında uzman personelimizle yakından bakalım. Yerinde inceleme, kurumsal ekspertiz ve dört kapsamlı raporla kararınızı bilgiyle verin.</p>
          <div className="yb-actions">
            <IncelemeBaglantisi className="yb-button yb-button-dark">İnceleme talebi oluştur <Ikon ad="capraz-ok" /></IncelemeBaglantisi>
            <HesapBaglantisi className="yb-button yb-button-outline"><Ikon ad="ok" /></HesapBaglantisi>
          </div>
          <UyelikNotu />
          <div className="yb-hero-assurance"><Ikon ad="kalkan" /><span>Uzman incelemesi. Belgeli süreç. Bilinçli karar.</span></div>
        </div>
        <div className="yb-hero-composition">
          <div className="yb-hero-photo-frame"><div className="yb-hero-photo-plane" data-sc-parallax="-0.07"><Image src="/images/lift-inceleme.jpg" alt="Liftteki aracı kontrol eden personel, temsili görsel" fill preload sizes="(max-width: 760px) 100vw, 54vw" className="yb-hero-new-photo" /></div><span className="yb-photo-note">Aracın yanında, sizin yerinize.</span></div>
          <div className="yb-hero-detail" data-sc-parallax="0.045"><div className="yb-detail-image"><Image src="/images/arac-kokpit.jpg" alt="İç kozmetik incelemesini temsil eden kokpit ve donanım detayları" fill sizes="(max-width: 760px) 170px, 240px" /></div><span><Ikon ad="kamera" /> İçinden dışına, tüm detaylarıyla.</span></div>
          <div className="yb-hero-expert"><Ikon ad="kalkan" /><span>Alanında uzman personel<br /><strong>Sizin yerinize, aracın yanında.</strong></span></div>
          <span className="yb-hero-photo-credit">Fotoğraflar temsili olarak kullanılmıştır.</span>
        </div>
      </div>
      <div className="yb-wrap yb-hero-strip"><span><Ikon ad="konum" /> Yerinde araç incelemesi</span><span><Ikon ad="kisi" /> Alanında uzman personel</span><span><Ikon ad="belge" /> Tüm raporlar müşteri panelinde</span></div>
    </section>
  );
}
