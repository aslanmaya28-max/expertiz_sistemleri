import type { Metadata } from "next";
import Link from "next/link";
import HizmetSayfasi from "@/bilesenler/HizmetSayfasi";
import DegerlemeKapsami from "@/bilesenler/DegerlemeKapsami";
import { BOLGE_DEGERLEME, ISLETME, KREDI_PAKETLERI, ORTAK_SORULAR, SITE_URL, type SSS } from "@/lib/hizmetBilgisi";

export const metadata: Metadata = {
  title: "Araç değerleme raporu — ilan fiyatı doğru mu?",
  description:
    "İkinci el aracın ilan fiyatı piyasaya uygun mu? Benzer ilanları bu araca göre düzelten değerleme, hasarın fiyat etkisi, adil fiyat aralığı, pazarlık planı ve modelin kullanıcı şikâyetleri tek raporda. 1 rapor 100 TL, Türkiye geneli.",
  alternates: { canonical: `${SITE_URL}/arac-degerleme` },
};

const tl = (n: number) => new Intl.NumberFormat("tr-TR").format(n) + " TL";

const SORULAR: SSS[] = [
  {
    soru: "Yeterli benzer ilan bulunamazsa ne olur?",
    yanit: "Aynı model ve kasadan yeterli ilan bulunamazsa rapor üretilmez ve krediniz düşülmez. Aracınızın kasası yeni değiştiyse ve o kasada henüz ilan yoksa da, yanıltıcı olmaması için eski kasanın fiyatıyla değerleme yapmayız.",
  },
  {
    soru: "Sahibinden ilanını değerletebilir miyim?",
    yanit: "Evet. İlan sayfasındaki fiyatı, özellikler listesini ve açıklamayı kopyalayıp forma yapıştırmanız yeterli; telefonda metin seçilemiyorsa ilanın ekran görüntüsünü yükleyin. Marka, model, paket, yıl, kilometre ve fiyat otomatik dolar. Boya, değişen ve tramer bilgisi açıklamada yazıyorsa o da okunur; isterseniz kendiniz düzeltebilirsiniz.",
  },
  {
    soru: "Rapor ne kadar sürede hazırlanır?",
    yanit: "Genellikle bir dakikadan kısa sürede. Rapor müşteri panelinizde saklanır ve PDF olarak indirilebilir.",
  },
  ...ORTAK_SORULAR,
];

export default function AracDegerlemeSayfasi() {
  return (
    <HizmetSayfasi
      ust="ÇEVRİM İÇİ ARAÇ DEĞERLEME"
      baslik="İlan fiyatı doğru mu? Aracı görmeden öğrenin"
      ozet="Telefonunuzdan ya da bilgisayarınızdan ilan bilgilerini girin; benzer ilanları sizin aracınıza göre düzelterek adil fiyat aralığını, bildirilen hasarın fiyat etkisini, pazarlık planını ve modelin bilinen sorunlarını tek raporda verelim."
      bolge={BOLGE_DEGERLEME}
      birincil={{ href: "/arac-analiz", etiket: "Araç değerleme raporu al" }}
      ikincil={{ href: "/ornek-rapor", etiket: "Örnek raporu incele" }}
      sorular={SORULAR}
      hizmetJsonLd={{
        "@type": "Service",
        name: "Araç değerleme raporu",
        serviceType: "İkinci el araç fiyat değerlemesi",
        provider: ISLETME,
        areaServed: { "@type": "Country", name: "Türkiye" },
        url: `${SITE_URL}/arac-degerleme`,
        description: "İlan bilgileri, müşteri beyanı ve internetteki benzer ilanlara dayanan değerleme: adil fiyat aralığı, hasarın fiyat etkisi, pazarlık planı ve satıcıya hazır mesaj, enflasyona göre 6 aylık ve yıllık kazanç tahmini, modelin kullanıcı şikâyetleri.",
        offers: { "@type": "Offer", price: "100", priceCurrency: "TRY", description: "1 değerleme raporu (1 kredi)" },
      }}
      // Kullanıcı isteği (09.11.2026): 100 TL'ye neler alınacağı sayfanın başında, gruplu kart olarak.
      onBolum={{ id: "kapsam", baslik: "100 TL'ye neler alırsınız?", icerik: <DegerlemeKapsami baslik={false} /> }}
      bolumler={[
        {
          id: "kimler-icin", baslik: "Kimler için?",
          icerik: (
            <ul>
              <li>Beğendiği ilanın fiyatının piyasaya uygun olup olmadığını öğrenmek isteyenler</li>
              <li>Satıcıyla pazarlığa hazırlıklı gitmek isteyenler</li>
              <li>Türkiye&apos;nin herhangi bir yerindeki aracı, gitmeden önce elemek isteyenler</li>
            </ul>
          ),
        },
        {
          id: "nasil-isler", baslik: "Nasıl işler?",
          icerik: (
            <ol>
              <li><strong>Bilgileri girin:</strong> ilan bağlantısını ya da ilan metnini yapıştırın, telefondaysanız ilanın ekran görüntüsünü yükleyin veya marka, model, yıl, kilometre ve fiyatı elle girin. Boyalı ve değişen parçaları araç çizimi üzerinde işaretleyin; elinizde ekspertiz raporu varsa fotoğrafını yükleyin, parçalar ve tramer okunup çizime işlenir (siz kontrol edersiniz).</li>
              <li><strong>Kredi:</strong> her rapor 1 kredi kullanır. Yeterli benzer ilan bulunamazsa kredi düşülmez.</li>
              <li><strong>Rapor:</strong> genellikle bir dakikadan kısa sürede hazırlanır; panelinizde saklanır ve PDF olarak indirilebilir.</li>
            </ol>
          ),
        },
        {
          id: "teslim", baslik: "Ne teslim edilir?",
          icerik: (
            <>
              <p>Ekranda ve PDF olarak değerleme raporu; YerimeBak doğrulama kodu ile. <Link href="/ornek-rapor" className="text-birincil underline">Örnek raporu inceleyin.</Link></p>
              <p><strong>Önemli:</strong> değerleme raporu ilan bilgilerine, sizin beyanınıza ve internetteki ilanlara dayanır; araç yerinde incelenmez. Boya, değişen ve hasar bilgisini doğrulatmak için <Link href="/yerinde-inceleme" className="text-birincil underline">yerinde inceleme</Link> isteyebilirsiniz.</p>
            </>
          ),
        },
        {
          id: "ucret", baslik: "Ücret",
          icerik: (
            <>
              <ul>
                {KREDI_PAKETLERI.map((p) => <li key={p.kredi}>{p.kredi} kredi: {tl(p.fiyat)}{p.kredi > 1 ? ` (rapor başı ${tl(p.fiyat / p.kredi)})` : ""}</li>)}
              </ul>
              <p>1 kredi = 1 değerleme raporu. Krediler herkes için aynı fiyattadır.</p>
            </>
          ),
        },
        {
          id: "bolge", baslik: "Hangi bölgelerde?",
          icerik: <p>Değerleme raporu çevrim içi bir hizmettir; <strong>Türkiye&apos;nin her yerindeki</strong> araç için kullanılabilir.</p>,
        },
        {
          id: "ilgili-rehberler", baslik: "İlgili rehberler",
          icerik: (
            <ul>
              <li><Link href="/rehber/ilan-fiyati-dogru-mu-nasil-anlasilir" className="text-birincil underline">İlan fiyatı doğru mu, nasıl anlaşılır?</Link></li>
              <li><Link href="/rehber/boyali-degisen-parca-fiyat-etkisi" className="text-birincil underline">Boyalı ve değişen parçanın fiyata etkisi</Link></li>
              <li><Link href="/rehber/tramer-kaydi-nedir" className="text-birincil underline">Tramer kaydı nedir?</Link></li>
            </ul>
          ),
        },
      ]}
    />
  );
}
