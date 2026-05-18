export default function OrnekRaporSayfasi() {
  return (
    <div className="max-w-5xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-metin-birincil mb-2">Örnek Analiz Raporu</h1>
      <p className="text-metin-ikincil mb-8">Kredi harcamadan örnek bir AI analiz raporu inceleyin</p>

      <div className="bg-white rounded-xl border border-kenarlik-acik p-6">
        <div className="flex items-center gap-4 mb-6">
          <div className="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center text-metin-ikincil">SUV</div>
          <div>
            <h2 className="text-xl font-bold text-metin-birincil">Volkswagen T-Roc 2022</h2>
            <p className="text-metin-ikincil">1.5 TSI EVO DSG R-Line • 45.000 km • Otomatik • Benzin</p>
          </div>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <div className="bg-birincil/5 rounded-xl p-4 text-center">
            <div className="text-3xl font-bold text-birincil">82</div>
            <div className="text-sm text-metin-ikincil mt-1">AI Puanı</div>
          </div>
          <div className="bg-green-50 rounded-xl p-4 text-center">
            <div className="text-3xl font-bold text-green-600">+45.000 ₺</div>
            <div className="text-sm text-metin-ikincil mt-1">Tahmini Kâr</div>
          </div>
          <div className="bg-yellow-50 rounded-xl p-4 text-center">
            <div className="text-3xl font-bold text-yellow-600">18 gün</div>
            <div className="text-sm text-metin-ikincil mt-1">Satış Süresi</div>
          </div>
          <div className="bg-green-50 rounded-xl p-4 text-center">
            <div className="text-3xl font-bold text-green-700">AL</div>
            <div className="text-sm text-metin-ikincil mt-1">Karar</div>
          </div>
        </div>

        <div className="space-y-4">
          {[
            { baslik: "Piyasa Analizi", detay: "İlan fiyatı 850.000 ₺, piyasa ortalaması 920.000 ₺. Fiyat piyasa ortalamasının %7.6 altında." },
            { baslik: "Risk Değerlendirmesi", detay: "DÜŞÜK risk. KM yaşa uygun (45K), 2 parça boyalı, değişen yok." },
            { baslik: "Kârlılık", detay: "Optimal alış fiyatı 820.000 ₺, tahmini çıkış 890.000 ₺. Net kâr 45.000 ₺ (%5.2 marj)." },
            { baslik: "Likidite", detay: "Likidite skoru 75/100. VW T-Roc yüksek talep görüyor. Tahmini satış süresi 18 gün." },
          ].map((bolum) => (
            <div key={bolum.baslik} className="border border-kenarlik-acik rounded-lg p-4">
              <h3 className="font-semibold text-metin-birincil">{bolum.baslik}</h3>
              <p className="text-sm text-metin-ikincil mt-1">{bolum.detay}</p>
            </div>
          ))}
        </div>

        <div className="mt-8 text-center">
          <a href="/kayit-ol" className="inline-flex items-center px-6 py-3 bg-birincil text-white rounded-lg font-medium hover:bg-birincil-koyu transition-colors">
            Ücretsiz Dene — 3 Kredi Hediye
          </a>
        </div>
      </div>
    </div>
  );
}
