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
              <li><span className="hover:text-birincil transition-colors cursor-pointer">Hakkımızda</span></li>
              <li><span className="hover:text-birincil transition-colors cursor-pointer">İletişim</span></li>
              <li><span className="hover:text-birincil transition-colors cursor-pointer">Gizlilik Politikası</span></li>
              <li><span className="hover:text-birincil transition-colors cursor-pointer">Kullanım Koşulları</span></li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold mb-4">İletişim</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li>info@yerimebak.ai</li>
              <li>+90 (212) 000 00 00</li>
              <li>İstanbul, Türkiye</li>
            </ul>
          </div>
        </div>

        <div className="border-t border-gray-700 mt-8 pt-8 text-center text-sm text-gray-500">
          © {new Date().getFullYear()} yerimebak.ai — Tüm hakları saklıdır.
        </div>
      </div>
    </footer>
  );
}
