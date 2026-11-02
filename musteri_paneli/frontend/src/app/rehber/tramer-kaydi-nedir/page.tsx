import type { Metadata } from "next";
import RehberSayfasi from "@/bilesenler/RehberSayfasi";
import { BOLGE_YERINDE, HIZMET_YERINDE, SITE_URL } from "@/lib/hizmetBilgisi";

const slug = "tramer-kaydi-nedir";
const baslik = "Tramer kaydı nedir, araç alırken nasıl yorumlanır?";
const ozet = "Hasar kaydının ne anlatabileceğini, hangi soruları açık bıraktığını ve tutar ile onarılan parçaların fiyat değerlendirmesinde neden birlikte ele alındığını öğrenin.";

export const metadata: Metadata = {
  title: baslik,
  description: ozet,
  alternates: { canonical: `${SITE_URL}/rehber/${slug}` },
};

export default function TramerKaydiSayfasi() {
  return (
    <RehberSayfasi
      slug={slug}
      baslik={baslik}
      ozet={ozet}
      guncellemeTarihi="2026-11-02"
      kisaca={[
        "Hasar kaydı, aracın bütün onarım geçmişiyle aynı şey değildir.",
        "Tutarı; olay tarihi, onarılan parçalar ve belgelerle birlikte yorumlayın.",
        "Güncel sorgulama seçenekleri için e-Devlet ve SBM kanallarını kontrol edin.",
        "Kayıt ile satıcı beyanını yerinde inceleme bulgularıyla karşılaştırın.",
      ]}
      bolumler={[
        {
          id: "ne-gosterir", baslik: "Tramer kaydı neyi gösterir?",
          icerik: <p>İkinci el ilanlarında tramer sözcüğü genellikle sigorta hasar geçmişi için kullanılır. Sorgulamada sunulan bilgi, seçilen hizmetin kapsamına ve sisteme yansıyan kayıtlara bağlıdır. Bir kayıt varsa olay tarihi, gösterilen tutar ve varsa olay veya parça açıklaması birlikte okunmalıdır. Tek başına toplam tutarı görmek, darbenin nereden geldiğini ya da onarımın nasıl yapıldığını açıklamaz. Satıcıdan ilgili kayıtla eşleşen belge ve açıklama isteyin.</p>,
        },
        {
          id: "ne-gostermez", baslik: "Kayıt hangi soruları cevaplamaz?",
          icerik: <p>Sorguda kayıt görünmemesi, aracın hiç hasar almadığı sonucunu vermez. Sigorta kaydına yansımamış bir onarım bulunabilir; bu nedenle sorgu sonucunu aracın eksiksiz geçmişi olarak okumayın. Kayıt, bugünkü boya durumunu, onarım kalitesini veya motorun mevcut sağlığını da tek başına belirlemez. Aynı şekilde kayıt tutarı yüksek diye inceleme yapmadan aracın bütün durumunu tanımlamak doğru olmaz. Eksik bilgi olduğunda kesin hüküm yerine kontrol edilecek soruları çoğaltın.</p>,
        },
        {
          id: "nasil-sorgulanir", baslik: "Hasar kaydı nasıl sorgulanır?",
          icerik: <p>e-Devlet ve Sigorta Bilgi ve Gözetim Merkezi (SBM) üzerinden sunulan güncel hizmetleri kontrol edin. Erişim şartları, istenen bilgiler ve görüntülenebilen kayıtlar hizmete göre değişebilir; ilgili ekranın açıklamalarını okuyun. Aracı ve sorgunun kapsamını doğru tanımladığınızdan emin olun. Satıcının paylaştığı bir görüntüde tarih ve araç bilgilerini kontrol edin; eski veya eksik bir ekran görüntüsüyle yetinmeyin. Güncel yöntem ve koşulları resmî kanaldan doğrulayın, kişisel bilgilerinizi ilgisiz sitelere vermeyin.</p>,
        },
        {
          id: "fiyata-etkisi", baslik: "Aynı tutar neden farklı fiyat etkisi yaratır?",
          icerik: <p>Onarımın yapıldığı dönemin parça ve işçilik koşulları farklı olabilir. Bu nedenle farklı tarihlerdeki tutarları doğrudan karşılaştırmak yanıltabilir. Hangi parçanın etkilendiği, yapısal işlem bulunup bulunmadığı ve onarımın belgelenmesi değerlendirmeyi değiştirir. Bir dış kaporta parçasına yapılan işlemle taşıyıcı bölgedeki işlem aynı soruları doğurmaz. Fiyat etkisi tutara, parçaya ve araca göre değişir; her kayıt için geçerli tek bir indirim oranı kullanmayın.</p>,
        },
        {
          id: "birlikte-degerlendirme", baslik: "Satın alma kararına nasıl katın?",
          icerik: <p>Kayıt tarihlerini satıcının açıklaması, servis belgeleri ve ekspertiz bulgularıyla yan yana koyun. Açıklanamayan bir fark varsa satış kararından önce netleştirin. Onarılmış parçanın bugünkü durumu ile aynı model ve kasadaki benzer ilanların fiyatını birlikte değerlendirin. Çevrim içi değerleme aracın kendisini görmez; girilen hasar bilgisinin doğruluğuna bağlıdır. Yanlış veya eksik beyan, fiyat yorumunu da etkileyebilir. Fiziksel durumu doğrulamak için uygun kapsamlı bir inceleme planlayın.</p>,
        },
      ]}
      sorular={[
        { soru: "Tramer kaydı ile ekspertiz raporu aynı mı?", yanit: "Hayır. Hasar sorgusu kayıtlı geçmişe ilişkin bilgi sunar; ekspertiz ise belirli kapsamda aracın inceleme anındaki bulgularını değerlendirir. Birini diğerinin yerine kullanmayın." },
        { soru: "Kayıttaki tutar kadar indirim mi istemeliyim?", yanit: "Tutar doğrudan bugünkü değer kaybı değildir. Etkilenen parçalar, onarımın niteliği, aracın özellikleri ve benzer ilanlar birlikte ele alınmalıdır." },
        { soru: "Satıcının kayıt yok demesi yeterli mi?", yanit: "Beyanı güncel sorgu ve fiziksel incelemeyle karşılaştırın. Kayıt bulunmaması, bütün onarımların dışlandığı anlamına gelmez." },
      ]}
      cta={{ href: "/yerinde-inceleme", etiket: HIZMET_YERINDE, aciklama: `Hasar beyanının aracın mevcut durumuyla uyumunu inceletin. Hizmet bölgesi: ${BOLGE_YERINDE}.` }}
      kaynaklar={[{ ad: "Güncel sorgulama kapsamını kontrol etmek için SBM sıkça sorulan sorular", href: "https://sbm.org.tr/tr/sss/?cat=10" }]}
    />
  );
}
