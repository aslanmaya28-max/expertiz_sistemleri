"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { getStats, type VitrinStats } from "@/lib/api";
import YonetimLayout from "@/bilesenler/YonetimLayout";

export default function YonetimGenelBakis() {
  const { user, loading: authLoading } = useAuth();
  const [stats, setStats] = useState<VitrinStats | null>(null);

  useEffect(() => {
    if (!authLoading && (!user || user.role !== "admin")) {
      window.location.href = "/";
      return;
    }
    if (user?.role === "admin") {
      getStats().then(setStats).catch(console.error);
    }
  }, [user, authLoading]);

  if (authLoading) return <div className="max-w-7xl mx-auto px-4 py-12 text-center text-metin-ikincil">Yükleniyor...</div>;
  if (!user || user.role !== "admin") return null;

  return (
    <YonetimLayout aktif="/yonetim">
      <h2 className="text-lg font-semibold text-metin-birincil mb-4">Genel Bakış</h2>
      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <StatKart baslik="Toplam Araç" deger={stats?.total_listings ?? "-"} />
        <StatKart baslik="Analiz Edilen" deger={stats?.analyzed_listings ?? "-"} />
        <StatKart baslik="Ort. AI Puanı" deger={stats?.avg_ai_score ?? "-"} />
        <StatKart baslik="AL Fırsatları" deger={stats?.buy_opportunities ?? "-"} />
        <StatKart baslik="Ort. Fiyat" deger={stats?.avg_price ? `${(stats.avg_price).toLocaleString("tr-TR")} ₺` : "-"} />
        <StatKart baslik="Son 24 Saat" deger={stats?.daily_new_listings ?? "-"} />
      </div>
      {stats?.by_source && (
        <div className="mt-6">
          <h3 className="text-sm font-medium text-metin-ikincil mb-2">Kaynak Dağılımı</h3>
          <div className="flex gap-4">
            {Object.entries(stats.by_source).map(([k, v]) => (
              <div key={k} className="px-4 py-2 bg-white border border-kenarlik-acik rounded-lg">
                <div className="text-xs text-metin-ikincil">{k}</div>
                <div className="text-lg font-bold text-metin-birincil">{v}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </YonetimLayout>
  );
}

function StatKart({ baslik, deger }: { baslik: string; deger: string | number }) {
  return (
    <div className="bg-white border border-kenarlik-acik rounded-xl p-4">
      <div className="text-sm text-metin-ikincil">{baslik}</div>
      <div className="text-2xl font-bold text-metin-birincil mt-1">{deger}</div>
    </div>
  );
}
