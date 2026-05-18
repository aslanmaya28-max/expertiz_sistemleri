import Link from "next/link";

interface Paket {
  key: string;
  ad: string;
  fiyat: number;
  kredi: number;
  birimFiyat: string;
  ozellikler: string[];
  populer?: boolean;
}

const paketler: Paket[] = [
  {
    key: "tek",
    ad: "Tek Analiz",
    fiyat: 100,
    kredi: 1,
    birimFiyat: "100 ₺/analiz",
    ozellikler: ["1 araç analizi", "Detaylı AI raporu", "Risk değerlendirmesi", "30 gün geçerlilik"],
  },
  {
    key: "besli",
    ad: "5 Analiz",
    fiyat: 400,
    kredi: 5,
    birimFiyat: "80 ₺/analiz",
    ozellikler: ["5 araç analizi", "Detaylı AI raporu", "Boy/değişen analizi", "Piyasa karşılaştırması", "30 gün geçerlilik"],
  },
  {
    key: "onlu",
    ad: "10 Analiz",
    fiyat: 750,
    kredi: 10,
    birimFiyat: "75 ₺/analiz",
    ozellikler: ["10 araç analizi", "Tam detaylı rapor", "Chrome uzantı erişimi", "Vitrin özel filtreler", "Kârlılık hesabı", "60 gün geçerlilik"],
    populer: true,
  },
  {
    key: "kurumsal",
    ad: "Kurumsal",
    fiyat: 3000,
    kredi: 50,
    birimFiyat: "60 ₺/analiz",
    ozellikler: ["50 araç analizi", "Tam detaylı rapor", "Chrome uzantı erişimi", "Vitrin özel filtreler", "Öncelikli destek", "API erişimi", "90 gün geçerlilik"],
  },
];

export default function FiyatKartlari() {
  return (
    <section className="py-16 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-4">
          <h2 className="text-3xl font-bold text-metin-birincil">Fiyat Paketleri</h2>
          <p className="mt-3 text-metin-ikincil">İhtiyacınıza uygun kredi paketini seçin</p>
        </div>
        <div className="text-center mb-12">
          <span className="inline-flex items-center gap-2 px-4 py-2 bg-birincil/10 text-birincil rounded-full text-sm font-medium">
            Kayıt olana <strong>3 analiz ücretsiz</strong>
          </span>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {paketler.map((paket) => (
            <div
              key={paket.key}
              className={`relative rounded-2xl border p-6 flex flex-col ${
                paket.populer
                  ? "border-birincil shadow-lg shadow-birincil/10"
                  : "border-kenarlik-acik"
              }`}
            >
              {paket.populer && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-birincil text-white text-xs font-medium rounded-full">
                  En Popüler
                </div>
              )}

              <h3 className="text-lg font-bold text-metin-birincil">{paket.ad}</h3>
              <div className="mt-3">
                <span className="text-3xl font-bold text-metin-birincil">{paket.fiyat.toLocaleString("tr-TR")} ₺</span>
                <div className="text-sm text-metin-ikincil mt-1">{paket.kredi} kredi • {paket.birimFiyat}</div>
              </div>

              <ul className="mt-5 space-y-2.5 flex-1">
                {paket.ozellikler.map((oz) => (
                  <li key={oz} className="flex items-start gap-2 text-sm text-metin-ikincil">
                    <svg className="w-4 h-4 text-birincil flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    {oz}
                  </li>
                ))}
              </ul>

              <Link
                href="/kayit-ol"
                className={`mt-6 block text-center py-2.5 rounded-lg font-medium text-sm transition-colors ${
                  paket.populer
                    ? "bg-birincil text-white hover:bg-birincil-koyu"
                    : "border border-kenarlik-acik text-metin-birincil hover:border-birincil hover:text-birincil"
                }`}
              >
                Paketi Seç
              </Link>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
