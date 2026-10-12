import type { Metadata } from "next";
import Link from "next/link";
import YasalSayfa from "@/bilesenler/YasalSayfa";

export const metadata: Metadata = { title: "Hakkımızda" };

export default function HakkimizdaSayfasi() {
  return (
    <YasalSayfa baslik="Hakkımızda">
      <p>
        YerimeBak, ikinci el araç alırken &quot;bu araç gerçekten kaç para eder?&quot; sorusuna veriyle cevap vermek için kuruldu.
        Galericilik tecrübesini güncel piyasa verisi ve yapay zekâ destekli değerlemeyle birleştiriyoruz.
      </p>
      <h2>Ne yapıyoruz?</h2>
      <ul>
        <li><strong>Araç değerleme:</strong> İlan linkini paylaşın ya da aracı elle girin; piyasa ortalaması, boya-değişen-tramer kaynaklı değer kaybı, önerilen fiyat ve satın alma önerisini saniyeler içinde görün.</li>
        <li><strong>Yerinde ekspertiz:</strong> Aracın bulunduğu ildeki uzmanımız aracı yerinde inceler ve seçtiğiniz anlaşmalı kurumsal ekspertiz firmasında kontrol ettirir; süreci adım adım panelinizden izlersiniz.</li>
        <li><strong>Vitrin:</strong> Piyasadaki ilanları tek yerde, değerlendirme puanlarıyla birlikte sunuyoruz.</li>
      </ul>
      <p>
        <Link href="/ekspertiz-talebi" className="text-birincil underline">Ekspertiz talebi oluşturun</Link> veya{" "}
        <Link href="/arac-analiz" className="text-birincil underline">araç analizine başlayın</Link>.
      </p>
    </YasalSayfa>
  );
}
