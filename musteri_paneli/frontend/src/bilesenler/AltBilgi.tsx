import IncelemeBaglantisi from "@/bilesenler/IncelemeBaglantisi";
import Link from "next/link";
import Marka from "./Marka";
import Ikon from "./Ikon";

export default function AltBilgi() {
  return (
    <footer className="yb-footer"><div className="yb-wrap">
      <div className="yb-footer-grid"><div className="yb-footer-brand"><Link href="/" aria-label="YerimeBak ana sayfa"><Marka acik /></Link><p>Yerinde inceleme.<br />Belgeli süreç.<br />Bilinçli karar.</p><span><Ikon ad="konum" /> İstanbul’da pilot hizmet</span></div>
        <div><h2>YerimeBak</h2><Link href="/#hizmetimiz">Hizmetimiz</Link><Link href="/#nasil-calisir">Nasıl çalışır?</Link><Link href="/#raporlar">Dört rapor, tek panel</Link><Link href="/hakkimizda">Hakkımızda</Link><Link href="/iletisim">İletişim</Link></div>
        <div><h2>İşlemleriniz</h2><IncelemeBaglantisi>İnceleme talebi oluştur</IncelemeBaglantisi><Link href="/panel">Müşteri paneli</Link><Link href="/ornek-rapor">Örnek rapor</Link><Link href="/fiyatlar">Fiyatlar</Link><Link href="/arac-analiz">Araç değerleme</Link><Link href="/vitrin">Araç vitrini</Link></div>
        <div><h2>Bilgilendirme</h2><Link href="/kvkk">KVKK Aydınlatma Metni</Link><Link href="/gizlilik">Gizlilik ve Çerez Politikası</Link><Link href="/kullanim-kosullari">Kullanım Koşulları</Link><Link href="/mesafeli-satis">Mesafeli Satış Sözleşmesi</Link><Link href="/iptal-iade">İptal ve İade Koşulları</Link></div>
      </div>
      <div className="yb-footer-bottom"><span>© {new Date().getFullYear()} YerimeBak. Tüm hakları saklıdır.</span><span>Bugün İstanbul. Hedefimiz 81 il.</span><a href="#icerik">Yukarı dön ↑</a></div>
    </div></footer>
  );
}
