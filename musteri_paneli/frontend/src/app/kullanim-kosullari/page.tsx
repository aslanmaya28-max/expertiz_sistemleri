import type { Metadata } from "next";
import Link from "next/link";
import YasalSayfa from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "Kullanım Koşulları" };

export default async function KullanimKosullariSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="Kullanım Koşulları" guncelleme="Ekim 2026">
      <p>
        Bu koşullar, {s.unvan} (&quot;YerimeBak&quot;) tarafından sunulan yerimebak.com.tr internet sitesi ve uygulamalarının
        (&quot;Platform&quot;) kullanımını düzenler. Üye olarak bu koşulları kabul etmiş olursunuz.
      </p>

      <h2>1. Hizmetler</h2>
      <ul>
        <li><strong>Araç değerleme analizi:</strong> Girdiğiniz araç bilgileri ve platformdaki güncel piyasa ilanları kullanılarak tahmini
          piyasa değeri, boya/değişen/tramer kaynaklı değer kaybı ve satın alma önerisi hesaplanır. Her analiz 1 kredi kullanır.</li>
        <li><strong>Ekspertiz hizmeti:</strong> Talebiniz, aracın bulunduğu ildeki YerimeBak uzmanına yönlendirilir; uzman aracı inceler
          ve seçtiğiniz anlaşmalı kurumsal ekspertiz firmasında kontrol yaptırır. Hazırlanan rapor panelinizde yayınlanır.</li>
        <li><strong>Vitrin:</strong> Piyasadaki ilanların derlenmiş görünümü; ilanlar ilgili ilan sitelerindeki satıcılara aittir.</li>
      </ul>

      <h2>2. Değerlemelerin niteliği</h2>
      <p>
        Değerleme sonuçları, mevcut piyasa verilerine dayalı istatistiksel tahminlerdir; bilgi amaçlıdır, kesin satış fiyatı veya
        yatırım tavsiyesi değildir. Satın alma kararının sorumluluğu kullanıcıya aittir. Kurumsal ekspertiz raporunun içeriğinden
        raporu düzenleyen ekspertiz firması sorumludur.
      </p>

      <h2>3. Üyelik ve hesap güvenliği</h2>
      <ul>
        <li>Üyelik için doğru ve güncel bilgi vermeniz ve e-posta adresinizi doğrulamanız gerekir.</li>
        <li>Şifrenizin gizliliğinden siz sorumlusunuz; yetkisiz kullanımı fark ederseniz derhal bize bildirin.</li>
        <li>Hoş geldin kredisi kişi başına bir kez verilir; birden fazla hesap açarak ücretsiz kredi elde etmek yasaktır.</li>
      </ul>

      <h2>4. Yasaklı kullanımlar</h2>
      <ul>
        <li>Platformdaki verilerin otomatik araçlarla toplanması, kopyalanması veya ticari amaçla yeniden yayınlanması,</li>
        <li>Sistemin güvenliğini aşmaya, başkasının hesabına erişmeye veya hizmeti aksatmaya yönelik girişimler,</li>
        <li>Gerçeğe aykırı araç veya kişi bilgisi girilmesi.</li>
      </ul>
      <p>Bu koşullara aykırılık halinde YerimeBak üyeliği askıya alma veya sonlandırma hakkını saklı tutar.</p>

      <h2>5. Ücretler ve ödeme</h2>
      <p>
        Kredi paketi ve ekspertiz ücretleri sipariş sırasında KDV dahil olarak gösterilir. Satın alma, iptal ve iade koşulları{" "}
        <Link href="/mesafeli-satis" className="text-birincil underline">Mesafeli Satış Sözleşmesi</Link> ve{" "}
        <Link href="/iptal-iade" className="text-birincil underline">İptal ve İade Koşulları</Link>&apos;nda düzenlenmiştir.
      </p>

      <h2>6. Fikri mülkiyet</h2>
      <p>Platformun yazılımı, tasarımı, YerimeBak adı ve logosu YerimeBak&apos;a aittir; izinsiz kullanılamaz.</p>

      <h2>7. Değişiklikler</h2>
      <p>
        Bu koşullar güncellenebilir; önemli değişiklikler Platform üzerinden duyurulur. Güncel metin her zaman bu sayfada yer alır.
      </p>

      <h2>8. Uygulanacak hukuk</h2>
      <p>
        Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır. Tüketici işlemlerinden doğan uyuşmazlıklarda, Ticaret Bakanlığınca ilan
        edilen parasal sınırlar dahilinde tüketici hakem heyetleri, aşan durumlarda tüketici mahkemeleri yetkilidir.
      </p>
      <p>İletişim: <strong>{s.eposta}</strong></p>
    </YasalSayfa>
  );
}
