"use client";

import { useEffect, useState } from "react";
import HeroBolumu from "@/bilesenler/HeroBolumu";
import AracKarti from "@/bilesenler/AracKarti";
import FiyatKartlari from "@/bilesenler/FiyatKartlari";
import IstatistikSayaci from "@/bilesenler/IstatistikSayaci";
import { getVehicles, getStats, type VehicleCard, type VitrinStats } from "@/lib/api";

export default function AnaSayfa() {
  const [araclar, setAraclar] = useState<VehicleCard[]>([]);
  const [istatistik, setIstatistik] = useState<VitrinStats | null>(null);

  useEffect(() => {
    getVehicles({ limit: 6, sort_by: "opportunity_score", sort_order: "desc" })
      .then((r) => setAraclar(r.vehicles))
      .catch(() => {});
    getStats().then(setIstatistik).catch(() => {});
  }, []);

  return (
    <>
      <HeroBolumu />

      <section className="py-16 bg-arkaplan-acik">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            <IstatistikSayaci hedef={istatistik?.total_listings || 1250} etiket="Toplam Araç" />
            <IstatistikSayaci hedef={istatistik?.analyzed_listings || 890} etiket="Analiz Edilen" />
            <IstatistikSayaci hedef={istatistik?.buy_opportunities || 145} etiket="Fırsat Araç" />
            <IstatistikSayaci hedef={istatistik?.avg_ai_score || 68} etiket="Ort. AI Puanı" />
          </div>
        </div>
      </section>

      {araclar.length > 0 && (
        <section className="py-16">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center justify-between mb-8">
              <div>
                <h2 className="text-2xl font-bold text-metin-birincil">Öne Çıkan Araçlar</h2>
                <p className="text-metin-ikincil mt-1">En yüksek AI puanına sahip araçlar</p>
              </div>
              <a href="/vitrin" className="text-sm font-medium text-birincil hover:underline">Tümünü Gör →</a>
            </div>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {araclar.map((arac) => <AracKarti key={arac.id} arac={arac} />)}
            </div>
          </div>
        </section>
      )}

      <section className="py-16 bg-arkaplan-acik">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-metin-birincil">8 Kategori Analiz</h2>
            <p className="mt-3 text-metin-ikincil">Her araç 8 farklı kategoride detaylı analiz edilir</p>
          </div>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {[
              { baslik: "AI Puanı", aciklama: "0-100 arası genel değerleme skoru", ikon: "🎯" },
              { baslik: "Fiyat Analizi", aciklama: "Piyasa ortalaması ile karşılaştırma", ikon: "💰" },
              { baslik: "Risk Değerlendirmesi", aciklama: "KM, boya, değişen risk skoru", ikon: "⚠️" },
              { baslik: "Boy/Değişen Analizi", aciklama: "Parça bazlı hasar tespiti", ikon: "🎨" },
              { baslik: "Kârlılık Hesabı", aciklama: "Net kâr ve marj oranı", ikon: "📈" },
              { baslik: "Likidite Skoru", aciklama: "Satış hızı tahmini", ikon: "⏱️" },
              { baslik: "Çıkış Stratejisi", aciklama: "Optimal satış fiyatı", ikon: "🚀" },
              { baslik: "Galericilik Kararı", aciklama: "AL / BEKLE / KAÇIN önerisi", ikon: "✅" },
            ].map((kat) => (
              <div key={kat.baslik} className="bg-white p-6 rounded-xl border border-kenarlik-acik hover:shadow-md transition-shadow">
                <div className="text-2xl mb-3">{kat.ikon}</div>
                <h3 className="font-semibold text-metin-birincil">{kat.baslik}</h3>
                <p className="text-sm text-metin-ikincil mt-1">{kat.aciklama}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-metin-birincil">Nasıl Çalışır?</h2>
            <p className="mt-3 text-metin-ikincil">3 basit adımda aracınızı analiz edin</p>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              { adim: "1", baslik: "Araç Bilgilerini Girin", aciklama: "Marka, model, yıl, KM ve fiyat bilgilerini girin veya ilan linkini paylaşın." },
              { adim: "2", baslik: "AI Analiz Yapsın", aciklama: "Motor V8 + Risk Motoru V8 ile 8 kategoride detaylı analiz yapılır." },
              { adim: "3", baslik: "Karar Verin", aciklama: "Galericilik kararı, kârlılık hesabı ve risk değerlendirmesi ile güvenle karar verin." },
            ].map((item) => (
              <div key={item.adim} className="text-center">
                <div className="w-12 h-12 bg-birincil text-white rounded-full flex items-center justify-center text-xl font-bold mx-auto mb-4">
                  {item.adim}
                </div>
                <h3 className="font-semibold text-metin-birincil text-lg">{item.baslik}</h3>
                <p className="text-metin-ikincil mt-2 text-sm">{item.aciklama}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <FiyatKartlari />
    </>
  );
}
