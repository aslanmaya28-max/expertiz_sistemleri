import type { Metadata } from "next";
import RehberSayfasi from "@/bilesenler/RehberSayfasi";
import { BOLGE_YERINDE, HIZMET_YERINDE, SITE_URL } from "@/lib/hizmetBilgisi";

const slug = "boyali-degisen-parca-fiyat-etkisi";
const baslik = "Boyalı ve değişen parça araç fiyatını nasıl etkiler?";
const ozet = "Boya, lokal boya ve değişen parça arasındaki farkları; tavan, direk ve şasi bulgularının neden ayrıca değerlendirilmesi gerektiğini sade bir dille okuyun.";

export const metadata: Metadata = {
  title: baslik,
  description: ozet,
  alternates: { canonical: `${SITE_URL}/rehber/${slug}` },
};

export default function BoyaliDegisenParcaSayfasi() {
  return (
    <RehberSayfasi
      slug={slug}
      baslik={baslik}
      ozet={ozet}
      guncellemeTarihi="2026-11-02"
      kisaca={[
        "Boya yüzey işlemini, değişen ise parçanın yenilenmesini anlatır.",
        "Parça sayısı kadar işlemin yeri, nedeni ve niteliği de önemlidir.",
        "Tavan, direk ve şasi bulgularında yapısal durumu ayrıca sorgulayın.",
        "Satıcı beyanını belge ve yerinde incelemeyle doğrulatın.",
      ]}
      bolumler={[
        {
          id: "tanimlar", baslik: "Boyalı, lokal boyalı ve değişen ne demek?",
          icerik: <p>Boyalı ifadesi bir parçanın yüzeyine sonradan boya uygulandığını anlatır. Lokal boyada işlem parçanın belirli bir alanıyla sınırlı olabilir; ancak ilandaki kullanım her zaman aynı ayrıntıyı ifade etmeyebilir. Değişen ise mevcut parçanın başka bir parçayla yenilendiğini belirtir. Bu ifadeler tek başına işlemin nedenini açıklamaz. Çizik, yüzey yenileme veya darbe onarımı gibi olasılıkları ayırmak için satıcıdan hangi alanın neden işlem gördüğünü açıkça anlatmasını isteyin.</p>,
        },
        {
          id: "parca-ve-onarim", baslik: "Neden yalnız parça sayısını saymamalısınız?",
          icerik: <p>İki araçta aynı sayıda boyalı parça bulunması aynı geçmişe sahip olduklarını göstermez. Parçaların konumu, birbirine komşu olup olmadığı ve onarımın kapsamı farklı sorular doğurur. Değişen parçanın ne olduğu, bağlantılarının durumu ve çevresindeki bulgular da önemlidir. Boya ölçümü bir başlangıçtır; onarımın niteliği yalnız tek ölçüm sonucuyla anlaşılmaz. Fotoğraflar, faturalar ve inceleme bulguları birlikte değerlendirilirse açıklamanın tutarlılığı daha iyi anlaşılır.</p>,
        },
        {
          id: "kritik-bolgeler", baslik: "Tavan, direk ve şasi neden ayrıca incelenir?",
          icerik: <p>Direk ve şasi gibi taşıyıcı bölgelerdeki işlem, aracın yapısal durumuna ilişkin ek sorular getirir. Tavandaki boya veya onarımın da nedeni açıklığa kavuşturulmalıdır; yalnız boya bilgisiyle olayın türünü belirleyemezsiniz. Darbenin yayılımı, düzeltme veya birleştirme bulguları ve ilgili güvenlik bileşenlerinin durumu uzman değerlendirmesi gerektirebilir. Bu alanlarda bir ifade gördüğünüzde fiyat pazarlığına geçmeden önce kapsamlı inceleme isteyin. İnceleme kapsamına girmeyen alanlar varsa bunları ayrıca sorun.</p>,
        },
        {
          id: "fiyat-yorumu", baslik: "Fiyat etkisi nasıl değerlendirilir?",
          icerik: <p>Her boyalı veya değişen parça için sabit bir değer kaybı oranı yoktur. Etki; parçaya, onarıma ve araca göre değişir. Aynı model ve kasadaki benzer ilanları incelerken yıl, kilometre, donanım ve bildirilen hasarları birlikte karşılaştırın. Satıcıların istediği bedellerin gerçekleşmiş satış fiyatı olmadığını unutmayın. Çok farklı hasar geçmişlerini tek bir ortalamaya karıştırmak yerine karşılaştırmanın neden uygun olduğunu sorgulayın. Belgelenmeyen işlem konusunda kesin bir fiyat hükmü vermeyin.</p>,
        },
        {
          id: "beyan-dogrulama", baslik: "Satıcı beyanını nasıl doğrulatın?",
          icerik: <p>Parçaları araç üzerinde tek tek tarif ettirin ve varsa eski hasar fotoğraflarını isteyin. İlan, satıcı açıklaması ve ekspertiz raporundaki isimlerin aynı parçayı anlattığını kontrol edin. Farklılık varsa açıklama alın; belirsizliği yalnız indirimle kapatmayın. Çevrim içi değerleme, sizin girdiğiniz boya ve değişen bilgilerini kullanır; aracı görerek ölçüm yapmaz. Önce fiziksel bulguları netleştirip ardından güncel bilgilerle fiyatı değerlendirmek, kararın dayandığı varsayımları görünür kılar.</p>,
        },
      ]}
      sorular={[
        { soru: "Boyalı parça mutlaka ağır darbe anlamına mı gelir?", yanit: "Hayır. Boya işleminin farklı nedenleri olabilir. Nedeni anlamak için onarım belgeleri, parçanın çevresi ve yerinde inceleme bulguları birlikte değerlendirilmelidir." },
        { soru: "Lokal boya fiyatı hiç etkilemez mi?", yanit: "Böyle bir genelleme yapılamaz. İşlemin yeri ve kapsamı, aracın özellikleri ve benzer ilanların durumu fiyat yorumunu etkiler." },
        { soru: "Değişen parçası olan araç alınır mı?", yanit: "Kararı yalnız bu etikete bağlamayın. Parçanın ne olduğu, değişim nedeni, onarım niteliği ve aracın mevcut durumu netleştirildikten sonra fiyatla birlikte değerlendirin." },
      ]}
      cta={{ href: "/yerinde-inceleme", etiket: HIZMET_YERINDE, aciklama: `Boya ve değişen beyanlarını yerinde bulgularla karşılaştırın. Hizmet bölgesi: ${BOLGE_YERINDE}.` }}
    />
  );
}
