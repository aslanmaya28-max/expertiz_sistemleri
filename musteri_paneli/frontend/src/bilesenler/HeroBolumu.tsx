import Link from "next/link";

export default function HeroBolumu() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-teal-50 via-white to-teal-50">
      <div className="absolute inset-0 opacity-5">
        <div className="absolute top-20 left-10 w-72 h-72 bg-birincil rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-birincil-koyu rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-32">
        <div className="grid md:grid-cols-2 gap-12 items-center">
          <div className="animate-fade-in-up">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-birincil/10 text-birincil rounded-full text-sm font-medium mb-6">
              <span className="w-2 h-2 bg-birincil rounded-full animate-pulse" />
              AI Destekli Araç Değerleme
            </div>

            <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-metin-birincil leading-tight">
              Bu Araç<br />
              <span className="text-birincil">Kaç TL?</span>
            </h1>

            <p className="mt-6 text-lg text-metin-ikincil max-w-lg">
              20 yıllık galericilik tecrübesi kodlanmış yapay zeka motorumuz ile aracın gerçek değerini anında öğrenin.
              Risk analizi, kazanç hesabı, piyasa karşılaştırması.
            </p>

            <div className="mt-8 flex flex-col sm:flex-row gap-4">
              <Link
                href="/vitrin"
                className="inline-flex items-center justify-center px-6 py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors animate-pulse-teal"
              >
                Vitrini Keşfet
                <svg className="ml-2 w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </Link>
              <Link
                href="/arac-analiz"
                className="inline-flex items-center justify-center px-6 py-3 border border-kenarlik-acik text-metin-birincil font-medium rounded-lg hover:border-birincil hover:text-birincil transition-colors"
              >
                Araç Analiz Yap
              </Link>
            </div>
          </div>

          <div className="animate-fade-in-up hidden md:block" style={{ animationDelay: "0.3s" }}>
            <div className="relative">
              <div className="bg-white rounded-2xl shadow-xl border border-kenarlik-acik p-6 max-w-sm mx-auto">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-birincil/10 rounded-full flex items-center justify-center">
                    <svg className="w-5 h-5 text-birincil" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                    </svg>
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-metin-birincil">VW T-Roc 2022</div>
                    <div className="text-xs text-metin-ikincil">1.5 TSI DSG</div>
                  </div>
                </div>

                <div className="space-y-3">
                  <div className="flex justify-between text-sm">
                    <span className="text-metin-ikincil">İlan Fiyatı</span>
                    <span className="font-semibold">850.000 ₺</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-metin-ikincil">Piyasa Ortalaması</span>
                    <span className="font-semibold">920.000 ₺</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-metin-ikincil">AI Puanı</span>
                    <span className="font-bold text-birincil">82/100</span>
                  </div>
                  <hr className="border-kenarlik-acik" />
                  <div className="flex justify-between text-sm">
                    <span className="text-metin-ikincil">Tahmini Kâr</span>
                    <span className="font-bold text-basarili">+45.000 ₺</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-metin-ikincil">Karar</span>
                    <span className="px-2 py-0.5 bg-basarili/10 text-basarili rounded text-xs font-semibold">AL</span>
                  </div>
                </div>
              </div>

              <div className="absolute -top-4 -right-4 w-24 h-24 bg-birincil/10 rounded-full blur-xl" />
              <div className="absolute -bottom-4 -left-4 w-32 h-32 bg-birincil/5 rounded-full blur-xl" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
