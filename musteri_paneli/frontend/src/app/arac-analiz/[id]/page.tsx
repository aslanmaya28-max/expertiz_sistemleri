"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { useParams } from "next/navigation";
import { getVehicleDetail, type VehicleCard } from "@/lib/api";

function formatPrice(price: number): string {
  return new Intl.NumberFormat("tr-TR").format(price) + " ₺";
}

export default function AracDetaySayfasi() {
  const { id } = useParams();
  const [arac, setArac] = useState<VehicleCard | null>(null);
  const [yukleniyor, setYukleniyor] = useState(true);

  useEffect(() => {
    if (id) getVehicleDetail(Number(id)).then(setArac).catch(console.error).finally(() => setYukleniyor(false));
  }, [id]);

  if (yukleniyor) return <div className="max-w-5xl mx-auto px-4 py-12 text-center text-metin-ikincil">Yükleniyor...</div>;
  if (!arac) return <div className="max-w-5xl mx-auto px-4 py-12 text-center text-metin-ikincil">Araç bulunamadı</div>;

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <a href="/vitrin" className="text-sm text-birincil hover:underline mb-4 inline-block">← Vitrine Dön</a>

      <div className="grid md:grid-cols-2 gap-8">
        <div className="relative bg-gray-100 rounded-xl overflow-hidden h-80">
          {arac.image_url ? (
            <Image
              src={arac.image_url}
              alt={arac.title || `${arac.brand} ${arac.model}`}
              fill
              sizes="(min-width: 768px) 50vw, 100vw"
              className="object-cover"
              priority
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-metin-ikincil">Görsel yok</div>
          )}
        </div>

        <div>
          <h1 className="text-2xl font-bold text-metin-birincil">{arac.title || `${arac.brand} ${arac.model}`}</h1>
          <div className="mt-2 text-3xl font-bold text-metin-birincil">{formatPrice(arac.price)}</div>

          <div className="mt-4 flex flex-wrap gap-2">
            <span className="px-3 py-1 bg-gray-100 rounded-full text-sm">{arac.year}</span>
            <span className="px-3 py-1 bg-gray-100 rounded-full text-sm">{arac.km?.toLocaleString("tr-TR")} km</span>
            <span className="px-3 py-1 bg-gray-100 rounded-full text-sm">{arac.fuel}</span>
            <span className="px-3 py-1 bg-gray-100 rounded-full text-sm">{arac.transmission}</span>
            {arac.location && <span className="px-3 py-1 bg-gray-100 rounded-full text-sm">{arac.location}</span>}
          </div>

          {arac.ai_score !== null && (
            <div className="mt-6 grid grid-cols-2 gap-4">
              <div className="bg-white border border-kenarlik-acik rounded-xl p-4 text-center">
                <div className="text-3xl font-bold text-birincil">{arac.ai_score}</div>
                <div className="text-xs text-metin-ikincil mt-1">AI Puanı</div>
              </div>
              <div className="bg-white border border-kenarlik-acik rounded-xl p-4 text-center">
                <div className="text-3xl font-bold">{arac.decision || "-"}</div>
                <div className="text-xs text-metin-ikincil mt-1">Karar</div>
              </div>
            </div>
          )}
        </div>
      </div>

      {(arac.ai_score !== null) && (
        <div className="mt-8 grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: "Piyasa Ortalaması", deger: arac.market_avg_price ? formatPrice(arac.market_avg_price) : "-" },
            { label: "Fiyat Sapması", deger: arac.price_deviation_pct ? `%${arac.price_deviation_pct.toFixed(1)}` : "-" },
            { label: "Risk Seviyesi", deger: arac.risk_level || "-" },
            { label: "Tahmini Kâr", deger: arac.net_profit_tl ? formatPrice(arac.net_profit_tl) : "-" },
            { label: "Net Marj", deger: arac.net_margin_pct ? `%${arac.net_margin_pct}` : "-" },
            { label: "Çıkış Fiyatı", deger: arac.exit_price ? formatPrice(arac.exit_price) : "-" },
            { label: "Satış Süresi", deger: arac.days_to_sell ? `${arac.days_to_sell} gün` : "-" },
            { label: "Alış Fiyatı (Max)", deger: arac.buy_price_max ? formatPrice(arac.buy_price_max) : "-" },
          ].map((item) => (
            <div key={item.label} className="bg-white border border-kenarlik-acik rounded-xl p-4">
              <div className="text-xs text-metin-ikincil">{item.label}</div>
              <div className="text-lg font-semibold text-metin-birincil mt-1">{item.deger}</div>
            </div>
          ))}
        </div>
      )}

      <div className="mt-8 bg-white border border-kenarlik-acik rounded-xl p-6">
        <h2 className="text-lg font-semibold text-metin-birincil mb-4">Boy / Değişen Özeti</h2>
        <div className="flex gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-yellow-600">{arac.paint_summary.painted}</div>
            <div className="text-xs text-metin-ikincil">Boyalı</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-orange-600">{arac.paint_summary.local}</div>
            <div className="text-xs text-metin-ikincil">Lokal</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-red-600">{arac.paint_summary.changed}</div>
            <div className="text-xs text-metin-ikincil">Değişen</div>
          </div>
        </div>
      </div>

      {arac.url && (
        <div className="mt-6 text-center">
          <a href={arac.url} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 px-6 py-3 bg-birincil text-white rounded-lg font-medium hover:bg-birincil-koyu transition-colors">
            Orijinal İlanı Gör
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
          </a>
        </div>
      )}
    </div>
  );
}
