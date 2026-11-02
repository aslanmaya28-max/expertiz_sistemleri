import type { Metadata } from "next";
import RehberSayfasi from "@/bilesenler/RehberSayfasi";
import { BOLGE_DEGERLEME, HIZMET_DEGERLEME, SITE_URL } from "@/lib/hizmetBilgisi";

const slug = "ilan-fiyati-dogru-mu-nasil-anlasilir";
const baslik = "İlan fiyatının doğru olduğu nasıl anlaşılır?";
const ozet = "Benzer ilanları model, kasa, motor, yıl ve kilometreyle karşılaştırın; kasa geçişini, hasar bilgisini ve pazarlık payını fiyat yorumuna nasıl katacağınızı öğrenin.";

export const metadata: Metadata = {
  title: baslik,
  description: ozet,
  alternates: { canonical: `${SITE_URL}/rehber/${slug}` },
};

export default function IlanFiyatiSayfasi() {
  return (
    <RehberSayfasi
      slug={slug}
      baslik={baslik}
      ozet={ozet}
      guncellemeTarihi="2026-11-02"
      kisaca={[
        "Önce aynı model ve kasayı, sonra motor, şanzıman ve donanımı eşleştirin.",
        "Yıl ve kilometre farklarını görünür tutun; yalnız ilan başlığına güvenmeyin.",
        "Hasar bilgisini doğrulatmadan fiyat sonucunu kesin kabul etmeyin.",
        "İstenen ilan bedeliyle gerçekleşen satış bedelini birbirine karıştırmayın.",
      ]}
      bolumler={[
        {
          id: "dogru-emsal", baslik: "Hangi ilanlar gerçekten benzer?",
          icerik: <p>İlk adım aynı marka ve model adını bulmaktan fazlasıdır. Kasa, motor, yakıt türü, şanzıman ve donanım paketini eşleştirin. Görsel olarak yakın duran iki araç farklı teknik özelliklere sahip olabilir. İlan başlığıyla özellik listesinin uyuşmasını kontrol edin; eksik bilgiyi satıcıdan öğrenin. Birkaç farklı örnekle çalışın ve olağan dışı düşük veya yüksek bedellerin nedenini araştırın. Tek bir ilanın fiyatını bütün piyasanın karşılığı saymayın.</p>,
        },
        {
          id: "kasa-gecisi", baslik: "Kasa geçiş yılında neye dikkat edilmeli?",
          icerik: <p>Aynı model yılında eski ve yeni kasa ilanlarıyla karşılaşabilirsiniz. Yıl eşitliği kasa eşitliği anlamına gelmez. Fotoğraflar, teknik bilgiler ve gerektiğinde araç belgeleriyle hangi kasanın söz konusu olduğunu netleştirin. Eski ve yeni kasayı aynı fiyat grubuna toplamak, hedef aracın pahalı veya ucuz görünmesine yol açabilir. Yeterli benzer kasa ilanı yoksa karşılaştırmanın sınırını kabul edin; başka kasanın ortalamasından kesin sonuç çıkarmayın.</p>,
        },
        {
          id: "yil-kilometre", baslik: "Yıl ve kilometre nasıl birlikte okunur?",
          icerik: <p>Yakın özellikteki ilanlarda yıl ve kilometre farklarını ayrı ayrı not edin. Daha yeni yıl veya daha düşük kilometre, bakım geçmişi bilinmeden tek başına karar gerekçesi olmaz. Kullanım biçimi, belgelenen bakımlar ve yaklaşan bakım ihtiyaçları da sorulmalıdır. Her kilometre farkına aynı tutarı eklemek veya çıkarmak yerine benzer ilanların dağılımına bakın. Kıyasladığınız araçlar hedef araçtan çok uzaksa ulaştığınız fiyat aralığının güveni de sınırlı kalır.</p>,
        },
        {
          id: "hasar-etkisi", baslik: "Hasar bilgisi karşılaştırmayı nasıl değiştirir?",
          icerik: <p>Boyalı ve değişen parçalar ile hasar kaydını karşılaştırma tablonuza ekleyin. Sadece kayıt tutarını değil, hangi parçanın etkilendiğini ve onarım açıklamasını da değerlendirin. Fiyat etkisi tutara, parçaya ve araca göre değişir; her araca uygulanan sabit bir indirim oranı kullanmayın. Bilgisi eksik ilanı hasarsız kabul etmek karşılaştırmayı bozabilir. Satıcı beyanını fiziksel incelemeyle doğrulatın ve yeni bir bulgu çıkarsa fiyat değerlendirmenizi de güncelleyin.</p>,
        },
        {
          id: "pazarlik", baslik: "Pazarlık payı nasıl düşünülmeli?",
          icerik: <p>İlan bedeli satıcının talebidir; o bedelden satış gerçekleştiğini göstermez. Pazarlık için benzer ilanları, açıklanan farkları ve incelemede ortaya çıkan ihtiyaçları gerekçe olarak kullanın. Kendi bütçenizle uyumlu bir hedef ve üst sınır belirleyin; her ilanda aynı pazarlık payı bulunduğunu varsaymayın. Çevrim içi değerleme, ilan bilgileri ve beyanlarla benzer ilanları karşılaştırır, aracı görmez. Sonuçtaki aralığı inceleme bulgularıyla birlikte okuyun; tek bir rakamı kesin satış bedeli saymayın.</p>,
        },
      ]}
      sorular={[
        { soru: "Piyasa ortalamasının altındaki ilan fırsat mıdır?", yanit: "Önce karşılaştırılan araçların gerçekten benzer olduğunu ve ilan bilgilerinin eksiksizliğini kontrol edin. Düşük bedelin nedeni açıklanmadan fırsat sonucu çıkarmayın." },
        { soru: "Aynı yıl ve model olması yeterli mi?", yanit: "Kasa, motor, şanzıman, donanım ve hasar geçmişi de eşleşmelidir. Özellikle kasa geçiş yıllarında model yılı tek başına yeterli değildir." },
        { soru: "Değerleme raporu aracın durumunu doğrular mı?", yanit: "Hayır. Rapor ilan bilgilerine ve bildirilen duruma dayanır; araç görülmez. Boya, değişen ve mekanik durum için fiziksel kontrol gerekir." },
      ]}
      cta={{ href: "/arac-degerleme", etiket: HIZMET_DEGERLEME, aciklama: `Benzer ilanlara ve beyan edilen araç bilgilerine dayanan fiyat karşılaştırmasının kapsamını inceleyin. Bölge: ${BOLGE_DEGERLEME}. Araç fiziksel olarak incelenmez.` }}
    />
  );
}
