import type { Metadata } from "next";
import Link from "next/link";
import YasalSayfa from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "Gizlilik ve Çerez Politikası" };

export default async function GizlilikSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="Gizlilik ve Çerez Politikası" guncelleme="Ekim 2026">
      <p>
        Bu politika, yerimebak.com.tr ve YerimeBak uygulamalarını kullanırken bilgilerinizin nasıl korunduğunu ve tarayıcınızda
        hangi verilerin saklandığını açıklar. Kişisel verilerin işlenmesine ilişkin ayrıntılar için{" "}
        <Link href="/kvkk" className="text-birincil underline">KVKK Aydınlatma Metni</Link>&apos;ni inceleyebilirsiniz.
      </p>

      <h2>1. Güvenlik</h2>
      <ul>
        <li>Siteye tüm erişim şifreli bağlantı (HTTPS) üzerinden yapılır.</li>
        <li>Şifreniz geri döndürülemez biçimde (bcrypt) saklanır; çalışanlarımız dahil kimse şifrenizi göremez.</li>
        <li>Kart bilgileriniz bizim sistemlerimize hiç ulaşmaz; ödeme PayTR&apos;nin güvenli ödeme sayfasında alınır.</li>
        <li>Ekspertiz fotoğrafları ve raporlar yalnızca sizin ve yetkili personelimizin açabileceği, süreli imzalı bağlantılarla paylaşılır.</li>
      </ul>

      <h2>2. Çerezler ve tarayıcı depolaması</h2>
      <table>
        <thead>
          <tr><th>Ad</th><th>Tür</th><th>Amaç</th><th>Süre</th></tr>
        </thead>
        <tbody>
          <tr><td>yerimebak_token</td><td>Zorunlu (yerel depolama)</td><td>Oturumunuzu açık tutmak</td><td>Çıkış yapana veya 24 saat dolana kadar</td></tr>
          <tr><td>Son sipariş bilgisi</td><td>Zorunlu (yerel depolama)</td><td>Ödeme sonucunu gösterebilmek</td><td>Ödeme sonucu görüntülenene kadar</td></tr>
          <tr><td>PayTR çerezleri</td><td>Zorunlu (üçüncü taraf)</td><td>Ödeme güvenliği; yalnızca ödeme ekranında</td><td>PayTR politikasına göre</td></tr>
        </tbody>
      </table>
      <p>
        Reklam, pazarlama veya kullanıcı takibi amaçlı çerez ya da analiz aracı kullanmıyoruz. Zorunlu depolama olmadan giriş
        yapılamaz; tarayıcı ayarlarınızdan dilediğiniz zaman silebilirsiniz.
      </p>

      <h2>3. İletişim</h2>
      <p>Gizlilikle ilgili sorularınız için: <strong>{s.kvkkEposta}</strong></p>
    </YasalSayfa>
  );
}
