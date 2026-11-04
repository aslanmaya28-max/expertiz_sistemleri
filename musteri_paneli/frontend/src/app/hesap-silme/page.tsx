import type { Metadata } from 'next';
import Link from 'next/link';
import YasalSayfa from '@/bilesenler/YasalSayfa';
import HesapSilmeFormu from './silme-formu';

export const metadata: Metadata = { title: 'Hesap Silme — YerimeBak' };

export default function HesapSilmeSayfasi() {
  return (
    <YasalSayfa baslik="YerimeBak hesabını silme" guncelleme="Kasım 2026">
      <p>YerimeBak web sitesi ve Android uygulamasında kullandığınız hesabınızı aşağıdaki formdan silebilirsiniz.
        İşlem için hesabınıza giriş yapmanız ve şifrenizi doğrulamanız gerekir. Uygulamada da profil ayarlarından
        aynı işlemi yapabilirsiniz.</p>
      <h2>Silinen ve anonimleştirilen bilgiler</h2>
      <p>Adınız, e-posta adresiniz, telefonunuz ve profilinizdeki şirket, vergi ve adres bilgileri hesabınızdan
        kaldırılır. İlgili sipariş ve raporlardaki müşteri iletişim kopyaları anonimleştirilir. Oturum ve hesap
        kurtarma bağlantıları geçersiz olur. Kalan analiz kredileri sıfırlanır; bu işlem geri alınamaz.</p>
      <h2>Saklanan kayıtlar ve süreleri</h2>
      <p>Satın alma, ödeme, iade ve muhasebe kayıtları yasal saklama yükümlülükleri nedeniyle korunur.
        Vergi mevzuatındaki süre, ilgili yılı izleyen takvim yılından başlayarak 5 yıldır; Türk Ticaret Kanunu
        kapsamındaki ticari kayıtlar için ilgili takvim yılı sonundan itibaren 10 yıllık süre uygulanır.
        Yasal saklama zorunluluğu sona erdiğinde kayıtlar silinir veya anonimleştirilir.</p>
      <p>Araç analiz ve ekspertiz raporları müşteri iletişim alanları anonimleştirilerek korunur.
        Hesap silme, Google Play üzerinden otomatik para iadesi yapmaz. Satın alma ve iade talepleri ilgili
        ödeme sağlayıcısının sürecinden yürütülür. Aynı e-postayla yeniden hesap açabilirsiniz; önceki
        hesabınızın kredileri ve raporları yeni hesaba aktarılmaz.</p>
      <p>Bilgi ve başvuru yolları için <Link href="/kvkk">KVKK Aydınlatma Metni</Link> ve{' '}
        <Link href="/gizlilik">Gizlilik Politikası</Link> sayfalarını inceleyebilirsiniz.
        Hesabınıza erişemiyorsanız <Link href="/sifremi-unuttum">şifre sıfırlama</Link> veya{' '}
        <Link href="/iletisim">iletişim</Link> yolunu kullanabilirsiniz.</p>
      <HesapSilmeFormu />
    </YasalSayfa>
  );
}
