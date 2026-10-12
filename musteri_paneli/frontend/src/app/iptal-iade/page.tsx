import type { Metadata } from "next";
import YasalSayfa from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "İptal ve İade Koşulları" };

export default async function IptalIadeSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="İptal ve İade Koşulları" guncelleme="Ekim 2026">
      <h2>1. Kredi paketleri</h2>
      <ul>
        <li>Hiç kullanılmamış kredi paketleri için, satın alma tarihinden itibaren <strong>14 gün</strong> içinde iade talep edebilirsiniz; ödemenin tamamı iade edilir.</li>
        <li>Paketteki kredilerden kullanılanlar elektronik ortamda anında ifa edilmiş sayılır ve iade edilmez. Kısmen kullanılmış paketler iade kapsamında değildir.</li>
        <li>E-posta doğrulamasıyla verilen ücretsiz hoş geldin kredileri nakde çevrilemez.</li>
      </ul>

      <h2>2. Ekspertiz hizmeti</h2>
      <ul>
        <li><strong>Uzman göreve çıkmadan önce</strong> (talebiniz &quot;Ekspertiz uzmanı atandı&quot; aşamasındayken veya henüz atama yapılmamışken) yapılan iptallerde ödemenin tamamı iade edilir.</li>
        <li><strong>Uzman harekete geçtikten sonra</strong> hizmetin ifasına başlanmış olur; bu aşamadan sonra cayma hakkı kullanılamaz.</li>
        <li>Hizmetin YerimeBak&apos;tan veya anlaşmalı ekspertiz firmasından kaynaklanan bir nedenle verilememesi halinde ödemenin tamamı iade edilir.</li>
        <li>Rapor panelinize yayınlandıktan sonra iptal yapılamaz; rapora ilişkin itirazlarınızı aşağıdaki adrese iletebilirsiniz.</li>
      </ul>

      <h2>3. İade süreci</h2>
      <ul>
        <li>İptal ve iade talebinizi, sipariş numaranızla birlikte <strong>{s.eposta}</strong> adresine kayıtlı e-posta adresinizden iletin.</li>
        <li>Onaylanan iadeler, ödemenin yapıldığı karta PayTR üzerinden en geç 14 gün içinde yapılır; tutarın hesabınıza yansıması bankanıza bağlı olarak birkaç iş günü sürebilir.</li>
        <li>İade gerçekleştiğinde panelinizde ve e-posta ile bilgilendirilirsiniz.</li>
      </ul>
    </YasalSayfa>
  );
}
