import type { Metadata } from "next";
import Link from "next/link";
import HizmetSayfasi from "@/bilesenler/HizmetSayfasi";
import { BOLGE_YERINDE, HIZMET_BEDELI_TL, ISLETME, KDV_ORANI, ORTAK_SORULAR, SITE_URL, type SSS } from "@/lib/hizmetBilgisi";

const tl = (n: number) => new Intl.NumberFormat("tr-TR").format(n) + " TL";

export const metadata: Metadata = {
  title: "Yerinde araç inceleme ve ekspertiz — İstanbul",
  description:
    "Almayı düşündüğünüz ikinci el aracı siz gitmeden uzman personelimiz bulunduğu yerde incelesin: iç ve dış ekspertiz, boya-kaporta, kurumsal ekspertiz ve değerleme raporları müşteri panelinizde. İstanbul Avrupa ve Anadolu yakası.",
  alternates: { canonical: `${SITE_URL}/yerinde-inceleme` },
};

const SORULAR: SSS[] = [
  {
    soru: "Yerinde incelemeye ben de katılmak zorunda mıyım?",
    yanit: "Hayır. Hizmetin amacı sizin gitmenize gerek kalmadan aracın yerinde incelenmesidir. Süreç boyunca personelin yola çıktığı, araç başına ulaştığı ve raporların hazır olduğu adımlar size bildirilir.",
  },
  {
    soru: "Kurumsal ekspertiz firmasını seçebilir miyim?",
    yanit: "Evet. Talebinizi oluştururken çalıştığımız kurumsal ekspertiz firmaları ve paketleri arasından seçim yaparsınız; firmanın raporu müşteri panelinize eklenir.",
  },
  {
    soru: "Raporların gerçek olduğunu satıcıya veya üçüncü kişilere nasıl gösterebilirim?",
    yanit: "Onaylanan raporlar YerimeBak mührü ve doğrulama koduyla verilir. Kodu bilen herkes yerimebak.com.tr/dogrula sayfasından raporun gerçekliğini kontrol edebilir; kişisel bilgileriniz bu sayfada gösterilmez.",
  },
  ...ORTAK_SORULAR,
];

export default function YerindeIncelemeSayfasi() {
  return (
    <HizmetSayfasi
      ust="YERİNDE ARAÇ İNCELEME VE EKSPERTİZ"
      baslik="Aracı siz gitmeden, uzmanımız yerinde incelesin"
      ozet="Almayı düşündüğünüz ikinci el aracı, alanında uzman personelimiz bulunduğu yerde inceler. İç ve dış durum, boya ve kaporta yerinde tespit edilir ve fotoğraflarla belgelenir; tercih ettiğiniz kurumsal ekspertiz firmasının raporu ve değerleme raporuyla birlikte müşteri panelinize gelir."
      bolge={BOLGE_YERINDE}
      birincil={{ href: "/ekspertiz-talebi", etiket: "Aracı yerinde incelet" }}
      ikincil={{ href: "/arac-degerleme", etiket: "Önce değerleme raporu al" }}
      sorular={SORULAR}
      hizmetJsonLd={{
        "@type": "Service",
        name: "Yerinde araç inceleme ve ekspertiz",
        serviceType: "İkinci el araç ekspertizi",
        provider: ISLETME,
        areaServed: { "@type": "City", name: "İstanbul" },
        url: `${SITE_URL}/yerinde-inceleme`,
        description: "Uzman personelin aracı bulunduğu yerde incelemesi; iç ekspertiz, dış ekspertiz (boya-kaporta), kurumsal ekspertiz ve değerleme raporlarının müşteri panelinde teslimi.",
        offers: {
          "@type": "Offer",
          priceSpecification: {
            "@type": "UnitPriceSpecification", price: String(HIZMET_BEDELI_TL), priceCurrency: "TRY", valueAddedTaxIncluded: false,
          },
          description: "YerimeBak hizmet bedeli (KDV hariç); kurumsal ekspertiz paket ücreti ayrıca eklenir.",
        },
      }}
      bolumler={[
        {
          id: "kimler-icin", baslik: "Kimler için?",
          icerik: (
            <ul>
              <li>İstanbul&apos;da satılık bir aracı almayı düşünen, ama aracı görmeye gidemeyen ya da ilk incelemeyi uzmana bırakmak isteyenler</li>
              <li>Başka bir şehirde yaşayıp İstanbul&apos;daki bir aracı almak isteyenler</li>
              <li>Satıcının beyanını (boya, değişen, hasar) bağımsız bir gözle doğrulatmak isteyenler</li>
            </ul>
          ),
        },
        {
          id: "kapsam", baslik: "Neleri kapsar?",
          icerik: (
            <>
              <ul>
                <li><strong>İç ekspertiz:</strong> iç kozmetik, döşemeler, kokpit ve iç donanım kontrolleri; fotoğraflarla belgelenir.</li>
                <li><strong>Dış ekspertiz:</strong> dış kozmetik, boya ve kaporta durumu; boyalı, lokal boyalı ve değişen parçalar parça parça işaretlenir.</li>
                <li><strong>Kurumsal ekspertiz:</strong> seçtiğiniz firmada, seçtiğiniz paket kapsamındaki teknik kontroller ve firmanın resmi raporu.</li>
                <li><strong>Değerleme:</strong> yerinde bulunan bulgulara ve benzer ilanlara göre aracın adil fiyat aralığı ve pazarlık rehberi.</li>
                <li><strong>Satıcı beyanıyla karşılaştırma:</strong> ilanda ya da formda bildirilen boya/değişen bilgisi ile yerinde bulunan durum yan yana gösterilir.</li>
              </ul>
              <p>Özellikle kontrol edilmesini istediğiniz noktaları talebinize not olarak ekleyebilirsiniz.</p>
            </>
          ),
        },
        {
          id: "nasil-isler", baslik: "Nasıl işler?",
          icerik: (
            <ol>
              <li><strong>Talep:</strong> araç bilgilerini, ilan bağlantısını, il ve ilçeyi girin; kurumsal ekspertiz firması ve paketini seçin. Değerleme raporunuz varsa araç bilgileri forma hazır gelir.</li>
              <li><strong>Ücret ve onay:</strong> toplam tutarı ödeme adımından önce görürsünüz.</li>
              <li><strong>Personel ataması:</strong> aracın konumuna göre uzman personelimiz telefonla teyit edilerek görevlendirilir.</li>
              <li><strong>Yerinde inceleme:</strong> personelin yola çıktığı ve araç başına ulaştığı size bildirilir; inceleme yapılır, fotoğraflar çekilir, gerekiyorsa araç kurumsal ekspertiz noktasına götürülür.</li>
              <li><strong>Kontrol ve teslim:</strong> raporlar yönetim ekibimizin kontrolünden geçer, eksikler tamamlanır ve onaylanan raporlar müşteri panelinize düşer.</li>
            </ol>
          ),
        },
        {
          id: "teslim", baslik: "Ne teslim edilir?",
          icerik: (
            <ul>
              <li>İç ekspertiz, dış ekspertiz, kurumsal ekspertiz ve değerleme raporları; hepsi aynı araç dosyasında, müşteri panelinizde</li>
              <li>İnceleme fotoğrafları (orijinal kalite). Fotoğraflar 7 gün panelde kalır, ardından arşive alınır; bu süre içinde toplu indirebilir, sonrasında arşivden talep edebilirsiniz.</li>
              <li>YerimeBak mührü ve doğrulama kodu: raporun gerçekliği <Link href="/dogrula" className="text-birincil underline">doğrulama sayfasından</Link> kontrol edilebilir.</li>
            </ul>
          ),
        },
        {
          id: "ucret", baslik: "Ücret",
          icerik: (
            <>
              <p className="!mb-0 text-2xl font-bold">YerimeBak hizmet bedeli: {tl(HIZMET_BEDELI_TL)}</p>
              <p className="text-xs text-metin-ikincil">KDV hariç · KDV dahil {tl(HIZMET_BEDELI_TL * (1 + KDV_ORANI))}</p>
              <p>
                Buna seçtiğiniz kurumsal ekspertiz firmasının paket ücreti eklenir. KDV ödeme adımında ayrı satır olarak
                hesaplanır; KDV dahil toplam tutar ödemeden önce açıkça gösterilir. Ayrıntılar{" "}
                <Link href="/fiyatlar" className="text-birincil underline">fiyatlar sayfasında</Link>.
              </p>
            </>
          ),
        },
        {
          id: "bolge", baslik: "Hangi bölgelerde?",
          icerik: (
            <p>
              Yerinde inceleme şu anda <strong>İstanbul&apos;un tamamında</strong>, Avrupa ve Anadolu yakasında sunulmaktadır. İstanbul
              dışındaki araçlar için henüz yerinde inceleme yapmıyoruz; bu araçlar için{" "}
              <Link href="/arac-degerleme" className="text-birincil underline">çevrim içi araç değerleme raporunu</Link> kullanabilirsiniz.
            </p>
          ),
        },
      ]}
    />
  );
}
