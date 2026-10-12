import type { Metadata } from "next";
import Link from "next/link";
import YasalSayfa, { SirketTablosu } from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "Mesafeli Satış Sözleşmesi ve Ön Bilgilendirme Formu" };

export default async function MesafeliSatisSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="Ön Bilgilendirme Formu ve Mesafeli Satış Sözleşmesi" guncelleme="Ekim 2026">
      <p>
        Bu metin, 6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Mesafeli Sözleşmeler Yönetmeliği uyarınca, yerimebak.com.tr
        üzerinden yapılan satın almalarda ön bilgilendirme formu ve sözleşme hükümlerini içerir. Ödeme adımında bu metni onaylamanız,
        sözleşmenin elektronik ortamda kurulduğu anlamına gelir; onay kaydı ve sipariş numarası sistemimizde saklanır.
      </p>

      <h2>1. Satıcı / hizmet sağlayıcı</h2>
      <SirketTablosu s={s} />

      <h2>2. Alıcı</h2>
      <p>Siparişi veren üyenin üyelik bilgilerinde kayıtlı ad soyad, e-posta, telefon ve (girilmişse) fatura bilgileri.</p>

      <h2>3. Sözleşmenin konusu ve hizmetler</h2>
      <ul>
        <li>
          <strong>Araç değerleme kredi paketi:</strong> Her kredi bir araç değerleme analizi hakkı verir. Paket adı, kredi adedi ve
          KDV dahil fiyatı sipariş ekranında gösterilir.
        </li>
        <li>
          <strong>Ekspertiz hizmeti:</strong> YerimeBak hizmet bedeli ile seçilen anlaşmalı kurumsal ekspertiz firmasının paket bedelinden
          oluşur. Kalemler ve KDV dahil toplam tutar ödeme öncesinde ayrı ayrı gösterilir. Hizmet; aracın bulunduğu ildeki YerimeBak
          uzmanının görevlendirilmesini, aracın incelenmesini, kurumsal ekspertiz firmasında kontrolü ve raporun panelinizde
          yayınlanmasını kapsar.
        </li>
      </ul>

      <h2>4. Ödeme</h2>
      <p>
        Ödeme, PayTR Ödeme ve Elektronik Para Kuruluşu A.Ş. altyapısıyla kredi kartı veya banka kartı ile tek çekim olarak alınır.
        Kart bilgileri satıcıya iletilmez. Fiyatlara KDV dahildir; sipariş sırasında gösterilen tutar dışında ek ücret talep edilmez.
      </p>

      <h2>5. İfa (hizmetin sunulması)</h2>
      <ul>
        <li><strong>Kredi paketi:</strong> Ödeme onaylandığı anda krediler hesabınıza yüklenir.</li>
        <li>
          <strong>Ekspertiz:</strong> Ödeme onayından sonra talebiniz bölgedeki uygun uzmana yönlendirilir. Uzmanın görevi kabul etmesi,
          yola çıkması, araç başına ve kurumsal ekspertiz noktasına ulaşması panelinizde ve e-posta ile bildirilir. Rapor, kalite
          kontrolünden sonra panelinizde yayınlanır.
        </li>
      </ul>

      <h2>6. Cayma hakkı</h2>
      <p>
        Mesafeli Sözleşmeler Yönetmeliği m.15 uyarınca; elektronik ortamda anında ifa edilen hizmetlerde (kullanılan krediler) ve
        cayma süresi dolmadan tüketicinin onayıyla ifasına başlanan hizmetlerde (uzmanın göreve çıkmasıyla başlayan ekspertiz
        hizmeti) cayma hakkı kullanılamaz. Ödeme adımında, hizmetin derhal ifasına başlanmasını onayladığınızı kabul edersiniz.
        Bu istisnaların dışında kalan durumlarda (kullanılmamış krediler, uzman göreve çıkmadan iptal) uygulanacak iade koşulları{" "}
        <Link href="/iptal-iade" className="text-birincil underline">İptal ve İade Koşulları</Link>&apos;nda yer alır.
      </p>

      <h2>7. Şikâyet ve itirazlar</h2>
      <p>
        Talep ve şikâyetlerinizi <strong>{s.eposta}</strong> adresine iletebilirsiniz. Uyuşmazlıklarda, Ticaret Bakanlığınca her yıl
        belirlenen parasal sınırlar dahilinde yerleşim yerinizdeki tüketici hakem heyetlerine, bu sınırları aşan durumlarda tüketici
        mahkemelerine başvurabilirsiniz.
      </p>

      <h2>8. Yürürlük</h2>
      <p>
        Bu sözleşme, alıcının ödeme adımında elektronik ortamda onay vermesiyle kurulur ve ödeme tamamlandığında yürürlüğe girer.
        Sözleşme ve sipariş bilgileri onay e-postası ve üye paneli üzerinden alıcıya sunulur.
      </p>
    </YasalSayfa>
  );
}
