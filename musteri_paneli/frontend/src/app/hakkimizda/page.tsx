import IncelemeBaglantisi from "@/bilesenler/IncelemeBaglantisi";
import type { Metadata } from "next";
import Link from "next/link";
import YasalSayfa from "@/bilesenler/YasalSayfa";

export const metadata: Metadata = { title: "Hakkımızda" };

export default function HakkimizdaSayfasi() {
  return (
    <YasalSayfa baslik="Hakkımızda">
      <p>
        YerimeBak, araç satın alma sürecindeki mesafeyi ve bilgi eksikliğini azaltmak için çalışır.
        Satın almayı düşündüğünüz aracın inceleme sürecini alanında uzman personelimizle yürütür,
        tespitleri fotoğraflar ve raporlarla belgelendiririz.
      </p>
      <h2>Ne yapıyoruz?</h2>
      <ul>
        <li><strong>Yerinde inceleme:</strong> İç ve dış kozmetik, boya ve kaporta durumunu yerinde inceler; gözlemleri ve fotoğrafları kayıt altına alırız.</li>
        <li><strong>Kurumsal ekspertiz:</strong> Talepleriniz doğrultusunda, tercih ettiğiniz kurumsal ekspertiz firmasında seçilen paket kapsamındaki kontrollerin gerçekleştirilmesini sağlarız.</li>
        <li><strong>Dört rapor, tek panel:</strong> İç ekspertiz, dış ekspertiz, yapay zekâ değerleme ve kurumsal ekspertiz raporlarını yönetim kontrolünün ardından müşteri panelinizde sunarız.</li>
      </ul>
      <h2>Misyonumuz</h2>
      <p>Uzman incelemesi, belgelenmiş bulgular ve anlaşılır raporlarla alıcıların bilinçli karar vermesine katkı sağlamak.</p>
      <h2>Vizyonumuz</h2>
      <p>İstanbul’da başlayan pilot hizmetimizi Türkiye’nin 81 iline taşımak; gelecekte vekâleten araç satın alma ve çekiciyle araç transferi hizmetleriyle daha kapsamlı destek sunmak. Bu iki hizmet planlama aşamasındadır ve henüz sunulmamaktadır.</p>
      <p>
        <IncelemeBaglantisi className="text-birincil underline">Ekspertiz talebi oluşturun</IncelemeBaglantisi> veya{" "}
        <Link href="/arac-analiz" className="text-birincil underline">araç analizine başlayın</Link>.
      </p>
    </YasalSayfa>
  );
}
