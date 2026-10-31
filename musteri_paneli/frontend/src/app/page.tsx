import IncelemeBaglantisi, { HesapBaglantisi } from "@/bilesenler/IncelemeBaglantisi";
import Image from "next/image";
import Link from "next/link";
import HeroBolumu from "@/bilesenler/HeroBolumu";
import Ikon, { type IkonAdi } from "@/bilesenler/Ikon";
import ScrollSahnesi from "@/bilesenler/ScrollSahnesi";
import RaporDosyasi from "@/bilesenler/RaporDosyasi";

const raporlar: { no: string; ikon: IkonAdi; baslik: string; metin: string; kapsam: string }[] = [
  { no: "01", ikon: "arac", baslik: "İç ekspertiz raporu", metin: "İç kozmetik, döşemeler, kokpit ve iç donanımlara ilişkin kontroller. Gözlemler ve fotoğraflarla aracın içini yakından tanıyın.", kapsam: "İÇ KOZMETİK · DONANIM · FOTOĞRAFLAR" },
  { no: "02", ikon: "kamera", baslik: "Dış ekspertiz raporu", metin: "Dış kozmetik, boya ve kaporta incelemeleri. Görünür kusurları ve parça bazında tespitleri belgeleriyle değerlendirin.", kapsam: "DIŞ KOZMETİK · BOYA · KAPORTA" },
  { no: "03", ikon: "grafik", baslik: "Yapay zekâ değerleme raporu", metin: "Araç bilgileri, inceleme bulguları ve mevcut piyasa verileri üzerinden değerleme. Aracı, durumuyla ve piyasa bağlamıyla birlikte değerlendirin.", kapsam: "DEĞERLEME · PİYASA KARŞILAŞTIRMASI" },
  { no: "04", ikon: "kalkan", baslik: "Kurumsal ekspertiz raporu", metin: "Talebiniz doğrultusunda tercih ettiğiniz kurumsal ekspertiz firmasında, seçilen paket kapsamındaki teknik kontroller ve firmanın raporu.", kapsam: "TERCİH ETTİĞİNİZ FİRMA · TEKNİK KONTROLLER" },
];
const adimlar = [
  ["Talebinizi paylaşın", "İl, ilçe ve araç bilgilerini girin. İlan bağlantısını ve özellikle incelenmesini istediğiniz noktaları ekleyin."],
  ["Uzman personeli yönlendirelim", "Yönetim ekibimiz, aracın konumuna ve incelemenin ihtiyacına göre personel atamasını gerçekleştirsin."],
  ["Araç yerinde incelensin", "Kozmetik ve boya/kaporta incelemeleri yapılsın; tercihinize göre kurumsal ekspertiz süreci yürütülsün."],
  ["Raporlar kontrolden geçsin", "Tespitler ve belgeler yönetim ekibimiz tarafından incelensin; eksik görülen noktalar tamamlansın."],
  ["Kararınızı bilgiyle verin", "Onaylanan raporları, fotoğrafları ve değerlendirmeleri müşteri panelinizden birlikte inceleyin."],
];
const sorular = [
  ["YerimeBak benim için ne yapar?", "Satın almayı düşündüğünüz aracın bulunduğu yerde inceleme sürecini yürütür. Alanında uzman personel, iç ve dış kozmetik ile boya/kaporta durumunu inceler ve belgeler. Talebiniz doğrultusunda kurumsal ekspertiz kontrolleri de sürece dahil edilir."],
  ["Kurumsal ekspertiz firmasını seçebilir miyim?", "Evet. Tercih ettiğiniz kurumsal ekspertiz firmasını ve inceleme taleplerinizi bize iletebilirsiniz. Firma, konum, randevu ve paket kapsamı talebiniz değerlendirilirken netleştirilir."],
  ["Raporlarıma nereden ulaşırım?", "Yönetim kontrolü tamamlanıp onaylanan iç ekspertiz, dış ekspertiz, yapay zekâ değerleme ve kurumsal ekspertiz raporları ilgili araç talebiniz altında müşteri panelinizde sunulur."],
  ["Hangi illerde hizmet veriyorsunuz?", "Pilot hizmet bölgemiz İstanbul. Hizmet ağımızı aşamalı olarak Türkiye’nin 81 iline taşımayı hedefliyoruz. Diğer iller henüz aktif hizmet kapsamı olarak sunulmamaktadır."],
  ["İnceleme, aracın sorunsuz olduğunu garanti eder mi?", "İnceleme ve raporlar, kontrolün kapsamı ile inceleme anındaki bulguları ortaya koyar. Her türlü arızanın tespitini veya aracın gelecekteki durumunu garanti etmez; satın alma kararınızı daha kapsamlı bilgiyle vermenize yardımcı olur."],
];
export default function AnaSayfa() {
  return (
    <ScrollSahnesi>
      <HeroBolumu />
      <section className="yb-section yb-wrap" id="hizmetimiz" data-sc-in aria-labelledby="hizmet-baslik">
        <div className="yb-section-intro"><span className="yb-eyebrow">MESAFE SİZDEN, İNCELEME BİZDEN</span><h2 id="hizmet-baslik">Bir araç için yola çıkmadan,<br /><em>önce gerçeğine yaklaşın.</em></h2><p>Bir ilan, her detayı anlatmaz. YerimeBak, sizin adınıza sahaya gider; aracın durumunu anlamanızı sağlayan bilgileri kayıt altına alır.</p></div>
        <div className="yb-benefits">{[{ikon:"saat",baslik:"Zamanınız size kalsın.",metin:"İlk inceleme için seyahat etmeden, aracı bulunduğu yerde tanıyın."},{ikon:"kamera",baslik:"Sözle değil, belgeleriyle.",metin:"Tespitleri, fotoğrafları ve kontrol sonuçlarını birlikte değerlendirin."},{ikon:"belge",baslik:"Süreç elinizin altında.",metin:"Talebinizi ve onaylanan tüm raporlarınızı tek panelden takip edin."}].map((item)=><article className="yb-benefit" key={item.baslik}><span className="yb-icon-circle"><Ikon ad={item.ikon as IkonAdi} /></span><h3>{item.baslik}</h3><p>{item.metin}</p></article>)}</div>
      </section>
      <RaporDosyasi />
      <section className="yb-reports-section" id="raporlar" data-sc-in aria-labelledby="rapor-baslik"><div className="yb-wrap yb-section">
        <div className="yb-section-heading"><div><span className="yb-eyebrow">ARACINIZIN BÜTÜN RESMİ</span><h2 id="rapor-baslik">Dört rapor.<br /><em>Tek müşteri paneli.</em></h2></div><p>Görünümünden teknik bulgularına, mevcut durumundan piyasa değerine. Farklı değerlendirmeleri aynı araç dosyasında buluşturuyoruz.</p></div>
        <div className="yb-report-grid">{raporlar.map((rapor)=><article className="yb-report" key={rapor.no}><div className="yb-report-top"><Ikon ad={rapor.ikon} /></div><h3>{rapor.baslik}</h3><p>{rapor.metin}</p><div className="yb-report-scope">{rapor.kapsam}</div></article>)}</div>
        <div className="yb-report-note"><span><Ikon ad="kontrol" /> Yönetim kontrolünün ardından müşteri panelinizde.</span><Link href="/ornek-rapor" className="yb-text-link">Örnek raporu inceleyin <Ikon ad="capraz-ok" /></Link></div>
      </div></section>
      <section className="yb-section yb-wrap" id="nasil-calisir" data-sc-act="flow" aria-labelledby="surec-baslik">
        <div className="yb-section-heading"><div><span className="yb-eyebrow">HER ADIMDA HABERİNİZ OLSUN</span><h2 id="surec-baslik">Talebinizden raporunuza,<br /><em>kontrollü bir süreç.</em></h2></div><IncelemeBaglantisi className="yb-button yb-button-outline">İlk adımı atın <Ikon ad="ok" /></IncelemeBaglantisi></div>
        <ol className="yb-steps">{adimlar.map(([baslik,metin],i)=><li key={baslik} data-sc-reveal="up" data-sc-reveal-at={`${0.05+i*.06} ${0.28+i*.06}`}><span className="yb-step-no">0{i+1}</span><div><h3>{baslik}</h3><p>{metin}</p></div><Ikon ad="ok" /></li>)}</ol>
      </section>
      <section className="yb-expertise" aria-labelledby="uzman-baslik">
        <div className="yb-expertise-image"><Image src="/images/lift-kontrol-detay.jpg" alt="Liftte araç altı kontrolü yapan personel, temsili görsel" fill sizes="(max-width: 900px) 100vw, 50vw" /><span>Temsili görsel</span></div>
        <div className="yb-expertise-copy"><span className="yb-eyebrow">YERİNİZE BAKAN, İŞİNİ BİLEN BİR EKİP</span><h2 id="uzman-baslik">Uzman gözler.<br />Kayıtlı bulgular.<br /><em>Şeffaf bir süreç.</em></h2><p>İnceleme sürecini alanında uzman personelimizle yürütüyoruz. Özellikle kontrol edilmesini istediğiniz noktaları dinliyor, tespitleri görseller ve açıklamalarla belgeliyoruz.</p><p>Hazırlanan raporlar yönetim kontrolünden geçiyor. Eksik görülen bilgiler tamamlanıyor; onaylanan raporlar müşteri panelinize ulaşıyor.</p><div className="yb-expertise-foot"><Ikon ad="kalkan" /><span>Karar sizin.<br /><strong>Bilgiyi bir araya getirmek bizim işimiz.</strong></span></div></div>
      </section>
      <section className="yb-section yb-wrap" id="hakkimizda" aria-labelledby="vizyon-baslik">
        <div className="yb-vision-intro"><span className="yb-eyebrow">BUGÜN İSTANBUL. YARIN DAHA YAKININIZDA.</span><h2 id="vizyon-baslik">Mesafeleri aşan<br /><em>bir hizmet anlayışı.</em></h2></div>
        <div className="yb-vision-grid"><div className="yb-coverage"><div className="yb-coverage-icon"><Ikon ad="konum" /></div><span className="yb-pilot"><span /> İstanbul’da pilot hizmet</span><p>İlk adımımız İstanbul.<br />Hedefimiz <strong>81 il.</strong></p><span>Hizmet ağımızı aşamalı olarak genişletiyoruz.</span></div><div className="yb-purpose"><article><span>01 / AMACIMIZ</span><h3>Misyonumuz</h3><p>Araç satın alma sürecindeki mesafe ve bilgi eksikliğini azaltmak; uzman incelemesi, belgelenmiş bulgular ve anlaşılır raporlarla bilinçli karar vermenize katkı sağlamak.</p></article><article><span>02 / HEDEFİMİZ</span><h3>Vizyonumuz</h3><p>Türkiye’nin 81 iline uzanan güvenilir bir hizmet ağı kurarak araç inceleme ve satın alma desteğini herkes için erişilebilir hale getirmek.</p></article></div></div>
        <div className="yb-future" id="gelecek-hizmetler"><div><span className="yb-eyebrow">YOL HARİTAMIZ</span><h3>Yolculuğunuzun devamında da yanınızda.</h3><p>Vekâleten araç satın alma ve çekiciyle talep edilen konuma araç transferi, hizmet yol haritamızda yer alıyor.</p></div><span className="yb-future-label">Planlanan hizmetler <span>Henüz sunulmamaktadır</span></span></div>
      </section>
      <section className="yb-faq-section"><div className="yb-wrap yb-section yb-faq-layout"><div><span className="yb-eyebrow">AKLINIZDA SORU KALMASIN</span><h2>Sormanız<br /><em>çok doğal.</em></h2><p>Hizmet kapsamıyla ilgili başka bir sorunuz mu var?</p><Link href="/iletisim" className="yb-text-link">Bize ulaşın <Ikon ad="capraz-ok" /></Link></div><div className="yb-faq-list">{sorular.map(([soru,yanit])=><details key={soru}><summary>{soru}<span className="yb-faq-plus" aria-hidden="true">+</span></summary><p>{yanit}</p></details>)}</div></div></section>
      <section className="yb-wrap yb-final-section"><div className="yb-final-cta"><div><span className="yb-eyebrow">BİR SONRAKİ ARACINIZ İÇİN</span><h2>Önce tanıyın.<br /><em>Sonra karar verin.</em></h2><p>Hesabınızı oluşturun. Aracınızı ve taleplerinizi paylaşın.<br />Gerisini birlikte planlayalım.</p></div><HesapBaglantisi className="yb-button yb-button-mint"><Ikon ad="capraz-ok" /></HesapBaglantisi><span className="yb-cta-watermark" aria-hidden="true">Y</span></div></section>
    </ScrollSahnesi>
  );
}
