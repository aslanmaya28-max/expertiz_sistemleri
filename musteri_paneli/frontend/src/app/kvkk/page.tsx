import type { Metadata } from "next";
import YasalSayfa, { SirketTablosu } from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "KVKK Aydınlatma Metni" };

export default async function KvkkSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="Kişisel Verilerin Korunması Aydınlatma Metni" guncelleme="Ekim 2026">
      <p>
        6698 sayılı Kişisel Verilerin Korunması Kanunu (&quot;KVKK&quot;) uyarınca, {s.unvan} (&quot;YerimeBak&quot;) olarak veri
        sorumlusu sıfatıyla kişisel verilerinizi aşağıda açıklanan kapsamda işliyoruz.
      </p>

      <h2>1. Veri sorumlusu</h2>
      <SirketTablosu s={s} />

      <h2>2. İşlenen kişisel veriler</h2>
      <ul>
        <li><strong>Kimlik ve iletişim:</strong> ad soyad, e-posta adresi, telefon numarası.</li>
        <li><strong>Müşteri işlem:</strong> sipariş ve ödeme kayıtları, satın alınan kredi paketleri, ekspertiz talepleri, iade kayıtları.</li>
        <li><strong>Fatura:</strong> firma ünvanı, vergi/T.C. kimlik numarası, vergi dairesi, fatura adresi (girdiğiniz takdirde).</li>
        <li><strong>Araç ve konum:</strong> plaka, marka/model/yıl/kilometre, ilan bağlantısı, aracın bulunduğu il ve ilçe, ekspertiz bulguları ve fotoğrafları, kurumsal ekspertiz raporu.</li>
        <li><strong>İşlem güvenliği:</strong> şifrenizin geri döndürülemez özeti, IP adresi, oturum bilgisi, yasal metin onay kayıtları.</li>
      </ul>
      <p>Kart bilgileriniz YerimeBak tarafından görülmez ve saklanmaz; ödeme, lisanslı ödeme kuruluşu PayTR&apos;nin güvenli sayfasında alınır.</p>

      <h2>3. İşleme amaçları</h2>
      <ul>
        <li>Üyelik oluşturma, kimlik doğrulama, şifre sıfırlama ve hesap güvenliği,</li>
        <li>Araç değerleme analizi, ekspertiz talebinin bölgedeki uzmana yönlendirilmesi ve raporun hazırlanması,</li>
        <li>Ödeme, iade ve fatura süreçlerinin yürütülmesi,</li>
        <li>Talep durumu (uzman atandı, yola çıktı, rapor hazır vb.) hakkında bilgilendirme,</li>
        <li>Hukuki yükümlülüklerin (vergi, tüketici mevzuatı) yerine getirilmesi, uyuşmazlıklarda delil olarak kullanılması,</li>
        <li>Kötüye kullanımın (sahte hesap, ücretsiz kredi istismarı) önlenmesi.</li>
      </ul>

      <h2>4. Hukuki sebepler</h2>
      <p>
        Kişisel verileriniz KVKK m.5/2 kapsamında; sözleşmenin kurulması ve ifası (c), hukuki yükümlülüğün yerine getirilmesi (ç),
        bir hakkın tesisi, kullanılması veya korunması (e) ve temel hak ve özgürlüklerinize zarar vermemek kaydıyla meşru
        menfaatimiz (f) hukuki sebeplerine dayanılarak işlenir.
      </p>

      <h2>5. Aktarım</h2>
      <p>Kişisel verileriniz yalnızca yukarıdaki amaçlar için gerekli olduğu ölçüde aşağıdaki alıcılara aktarılır:</p>
      <ul>
        <li><strong>PayTR Ödeme ve Elektronik Para Kuruluşu A.Ş.:</strong> ödeme ve iade işlemleri,</li>
        <li><strong>Seçtiğiniz kurumsal ekspertiz firması:</strong> aracın incelenmesi için araç ve iletişim bilgileri,</li>
        <li><strong>Görevlendirilen ekspertiz uzmanı (personelimiz):</strong> talebin yerine getirilmesi için gerekli bilgiler,</li>
        <li><strong>Barındırma (sunucu) ve e-posta hizmeti sağlayıcıları:</strong> sistemin çalışması ve bildirimlerin iletilmesi,</li>
        <li><strong>Yetkili kamu kurum ve kuruluşları:</strong> mevzuattan kaynaklanan talepler halinde.</li>
      </ul>
      <p>
        Hizmet sağlayıcılarımızın sunucuları yurt dışında bulunuyorsa aktarım, KVKK m.9&apos;da öngörülen şartlara uygun olarak yapılır.
      </p>

      <h2>6. Toplama yöntemi</h2>
      <p>
        Verileriniz internet sitesi ve mobil/web uygulamalarımız üzerinden, sizin girdiğiniz bilgilerle ve ekspertiz sırasında
        uzmanlarımızca oluşturulan kayıtlarla elektronik ortamda toplanır.
      </p>

      <h2>7. Saklama süresi</h2>
      <p>
        Veriler, işleme amacının gerektirdiği süre ve ilgili mevzuatta öngörülen süreler (örneğin vergi ve tüketici mevzuatı
        kapsamındaki saklama yükümlülükleri) boyunca saklanır; süre sonunda silinir, yok edilir veya anonim hale getirilir.
      </p>

      <h2>8. Haklarınız</h2>
      <p>KVKK m.11 uyarınca; kişisel verilerinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, amacına uygun kullanılıp
        kullanılmadığını öğrenme, aktarıldığı üçüncü kişileri bilme, eksik veya yanlış işlenmişse düzeltilmesini, şartları oluştuğunda
        silinmesini veya yok edilmesini isteme, bu işlemlerin aktarılan kişilere bildirilmesini isteme, otomatik sistemlerle analiz
        edilmesi sonucu aleyhinize bir sonuca itiraz etme ve kanuna aykırı işleme nedeniyle zarara uğramanız halinde zararın
        giderilmesini talep etme haklarına sahipsiniz.</p>
      <p>
        Başvurularınızı <strong>{s.kvkkEposta}</strong> adresine kayıtlı e-posta adresinizden, KEP adresimize ({s.kep}) veya yazılı
        olarak yukarıdaki adresimize iletebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır.
      </p>
    </YasalSayfa>
  );
}
