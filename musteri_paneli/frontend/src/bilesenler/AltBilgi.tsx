import Image from "next/image";
import Link from "next/link";

export default function AltBilgi() {
  return (
    <footer className="bg-metin-birincil text-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div>
            {/* Logo koyu lacivert: koyu zeminde acik kart icinde */}
            <div className="mb-4 inline-flex rounded-lg bg-white px-3 py-2">
              <Image src="/logo-yerimebak.png" alt="YerimeBak" width={640} height={262} className="h-10 w-auto" />
            </div>
            <p className="text-sm text-gray-400">Yapay zeka destekli araç değerleme ve galericilik asistanı.</p>
          </div>

          <div>
            <h4 className="font-semibold mb-4">Hizmetler</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li><Link href="/vitrin" className="hover:text-birincil transition-colors">Araç Vitrini</Link></li>
              <li><Link href="/arac-analiz" className="hover:text-birincil transition-colors">Araç Analiz</Link></li>
              <li><Link href="/ornek-rapor" className="hover:text-birincil transition-colors">Örnek Rapor</Link></li>
              <li><Link href="/fiyatlar" className="hover:text-birincil transition-colors">Fiyatlar</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold mb-4">Kurumsal</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li><Link href="/hakkimizda" className="hover:text-birincil transition-colors">Hakkımızda</Link></li>
              <li><Link href="/iletisim" className="hover:text-birincil transition-colors">İletişim</Link></li>
              <li><Link href="/kullanim-kosullari" className="hover:text-birincil transition-colors">Kullanım Koşulları</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold mb-4">Yasal</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li><Link href="/kvkk" className="hover:text-birincil transition-colors">KVKK Aydınlatma Metni</Link></li>
              <li><Link href="/gizlilik" className="hover:text-birincil transition-colors">Gizlilik ve Çerez Politikası</Link></li>
              <li><Link href="/mesafeli-satis" className="hover:text-birincil transition-colors">Mesafeli Satış Sözleşmesi</Link></li>
              <li><Link href="/iptal-iade" className="hover:text-birincil transition-colors">İptal ve İade Koşulları</Link></li>
            </ul>
          </div>
        </div>

        <div className="border-t border-gray-700 mt-8 pt-8 flex flex-col items-center gap-2 text-center text-sm text-gray-500">
          <p>Ödemeler PayTR güvencesiyle kredi ve banka kartı ile alınır.</p>
          <p>© {new Date().getFullYear()} YerimeBak — yerimebak.com.tr — Tüm hakları saklıdır.</p>
        </div>
      </div>
    </footer>
  );
}
