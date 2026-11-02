import type { Metadata } from "next";
import RehberSayfasi from "@/bilesenler/RehberSayfasi";
import { BOLGE_YERINDE, HIZMET_YERINDE, SITE_URL } from "@/lib/hizmetBilgisi";

const slug = "ikinci-el-arac-alirken-kontrol-listesi";
const baslik = "İkinci el araç alırken kontrol listesi";
const ozet = "İlanı elemekten satıcıyla görüşmeye, yerinde kontrolden ekspertiz ve satış hazırlığına kadar satın alma kararınızı adım adım değerlendirin.";

export const metadata: Metadata = {
  title: baslik,
  description: ozet,
  alternates: { canonical: `${SITE_URL}/rehber/${slug}` },
};

export default function KontrolListesiSayfasi() {
  return (
    <RehberSayfasi
      slug={slug}
      baslik={baslik}
      ozet={ozet}
      guncellemeTarihi="2026-11-02"
      kisaca={[
        "İlan bilgisini, satıcı beyanını ve inceleme bulgusunu ayrı tutun.",
        "Görüşmeye gitmeden bakım, hasar ve parça bilgilerini isteyin.",
        "Fiyat karşılaştırmasını aracın teknik kontrolüyle birlikte değerlendirin.",
        "Satış ve ödeme adımlarını güncel resmî kanallardan doğrulayın.",
      ]}
      bolumler={[
        {
          id: "ilan-asamasi", baslik: "İlan aşamasında neyi elemelisiniz?",
          icerik: <p>Önce ihtiyaçlarınıza uyan kasa, motor, şanzıman ve donanımı belirleyin. İlandaki model yılı, kilometre ve parça açıklamalarının birbirini destekleyip desteklemediğine bakın. Fotoğraflarda görünmeyen tarafları sorun; güzel fotoğrafı teknik durumun kanıtı saymayın. Aynı modelin farklı motorunu ya da eski kasasını fiyat karşılaştırmasına katmayın. İlan metnini ve satıcının sonradan verdiği bilgileri not edin; böylece görüşmede değişen bir açıklamayı yeniden sorabilirsiniz.</p>,
        },
        {
          id: "saticiyla-gorusme", baslik: "Satıcıya hangi soruları sorun?",
          icerik: <p>Aracı ne zamandır kullandığını, satış nedenini, bakım geçmişini ve bilinen sorunlarını sorun. Boyalı veya değişen parçaları tek tek öğrenin; hasar kaydının açıklamasını ve varsa onarım belgelerini isteyin. Bakım faturaları ile kilometre bilgisinin birlikte değerlendirilmesini sağlayın. Satıcının aracı incelemeye götürmeye yaklaşımını önceden konuşun. Eksik cevabı olumlu cevap gibi kabul etmeyin; belirsiz kalan maddeler için kontrol planı oluşturun.</p>,
        },
        {
          id: "aracin-yaninda", baslik: "Aracın yanında nelere bakın?",
          icerik: <p>Aracı mümkünse aydınlık ortamda, temiz yüzeylerle görün. Kaporta aralıkları, renk farkları, camlar, lastikler ve iç mekân aşınmasını birlikte gözden geçirin. Gösterge uyarılarını ve elektrikli donanımları kontrol edin; ilk çalıştırmanın koşullarını not alın. Güvenli ve uygun koşullarda yapılabilen bir sürüşte ses, titreşim ve vites davranışına dikkat edin. Bu gözlemler yalnızca sorulacak konuları belirler; görünür bir sorun olmaması mekanik sağlamlığı doğrulamaz.</p>,
        },
        {
          id: "ekspertiz", baslik: "Ekspertiz raporunu nasıl okuyun?",
          icerik: <p>Kontrolün kapsamını önceden öğrenin. Boya ve kaporta bulgularını, yapısal bölümleri ve kapsama giren mekanik kontrolleri ayrı ayrı değerlendirin. Satıcının beyanıyla raporu karşılaştırın; farklılık varsa nedenini açıklatın. Raporda erişilemeyen veya test edilemeyen alanlara da bakın. Gerekirse ilgili arıza için ek uzman görüşü alın. İlan verisine dayanan fiyat değerlendirmesi aracın fiziksel durumunu doğrulamaz; iki değerlendirme farklı sorulara cevap verir.</p>,
        },
        {
          id: "satis-hazirligi", baslik: "Noter ve ödeme öncesinde son kontrol",
          icerik: <p>Satışa konu araç ve taraf bilgilerinin belgelerle uyuşmasını kontrol edin. Devir için gereken belgeler, işleme engel olabilecek durumlar ve ödeme yöntemi konusunda güncel bilgiyi ilgili resmî kanallardan veya noterden teyit edin. İşlem koşulları araca ve taraflara göre değişebilir. Ödeme ve devir sırasını önceden netleştirin; doğrulanmamış yönlendirmeyle hareket etmeyin. İnceleme sonuçları, üzerinde anlaşılan bedel ve teslim edilecek anahtar veya belgeleri son kez gözden geçirin.</p>,
        },
      ]}
      sorular={[
        { soru: "İlk görüşmede kapora vermeli miyim?", yanit: "Önce araç, satıcı ve işlem koşullarını doğrulayın. Belirsiz bilgiler varken ödeme kararını aceleye getirmeyin; bağlayıcı koşulları anlamak için gerektiğinde yetkin bir uzmandan görüş alın." },
        { soru: "Hasar kaydı yoksa ekspertiz gerekli mi?", yanit: "Kayıt bulunmaması aracın mevcut fiziksel durumunu göstermez. Onarım geçmişi, kaporta ve mekanik durum ayrıca incelenmelidir." },
        { soru: "Değerleme raporu bu kontrolleri yapar mı?", yanit: "Hayır. Değerleme, ilan bilgileri ve beyanlarla fiyatı karşılaştırır; aracı görmez. Fiziksel bulgular yerinde kontrol gerektirir." },
      ]}
      cta={{ href: "/yerinde-inceleme", etiket: HIZMET_YERINDE, aciklama: `Satıcı beyanını fiziksel bulgularla karşılaştırmak için hizmet kapsamını inceleyin. Hizmet bölgesi: ${BOLGE_YERINDE}.` }}
      kaynaklar={[{ ad: "Ticaret Bakanlığı — Motorlu kara taşıtlarının ticaretine ilişkin resmî duyuru", href: "https://ticaret.gov.tr/haberler/ticaret-bakanligi-motorlu-kara-tasitlarinin-ticareti-hakkinda-yeni-kurallar-getirdi" }]}
    />
  );
}
