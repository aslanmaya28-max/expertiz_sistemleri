"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { getToken } from "@/lib/yetki";
import YonetimLayout from "@/bilesenler/YonetimLayout";

export default function VitrinYonetimi() {
  const { user, loading } = useAuth();
  const [esik, setEsik] = useState(70);
  const [islemSonucu, setIslemSonucu] = useState<string | null>(null);
  const [yukleniyor, setYukleniyor] = useState(false);

  // Vitrin yazma uçları admin yetkisi ister.
  const authHeaders = (): Record<string, string> => {
    const token = getToken();
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (token) h["Authorization"] = `Bearer ${token}`;
    return h;
  };

  useEffect(() => {
    if (!loading && (!user || user.role !== "admin")) {
      window.location.href = "/";
    }
  }, [loading, user]);

  if (!user || user.role !== "admin") {
    return null;
  }

  const topluAnaliz = async () => {
    setYukleniyor(true);
    setIslemSonucu(null);
    try {
      const r = await fetch(`/api/v1/vitrin/vehicles?min_score=0&limit=200&status=active`);
      const data = await r.json();
      let analyzed = 0;
      for (const v of data.vehicles || []) {
        try {
          const res = await fetch(`/api/v1/vitrin/${v.id}/analyze`, { method: "POST", headers: authHeaders() });
          if (res.ok) analyzed++;
        } catch { /* skip failed */ }
      }
      setIslemSonucu(`${analyzed} araç yeniden analiz edildi`);
    } catch {
      setIslemSonucu("Hata oluştu");
    } finally {
      setYukleniyor(false);
    }
  };

  const gizliAktiflestir = async () => {
    setYukleniyor(true);
    setIslemSonucu(null);
    try {
      const r = await fetch(`/api/v1/vitrin/vehicles?status=hidden&limit=200`);
      const data = await r.json();
      let activated = 0;
      for (const v of data.vehicles || []) {
        try {
          const res = await fetch(`/api/v1/vitrin/${v.id}/status`, {
            method: "PATCH",
            headers: authHeaders(),
            body: JSON.stringify({ status: "active" }),
          });
          if (res.ok) activated++;
        } catch { /* skip failed */ }
      }
      setIslemSonucu(`${activated} araç aktifleştirildi`);
    } catch {
      setIslemSonucu("Hata oluştu");
    } finally {
      setYukleniyor(false);
    }
  };

  return (
    <YonetimLayout aktif="/yonetim/vitrin">
      <h2 className="text-lg font-semibold text-metin-birincil mb-4">Vitrin Yönetimi</h2>
      <div className="bg-white border border-kenarlik-acik rounded-xl p-6 space-y-6">
        <div>
          <label className="block text-sm font-medium text-metin-birincil mb-2">Minimum AI Puanı Eşiği</label>
          <input type="range" min={0} max={100} value={esik} onChange={(e) => setEsik(Number(e.target.value))} className="w-full accent-[#14b8a6]" />
          <div className="flex justify-between text-xs text-metin-ikincil mt-1">
            <span>0</span>
            <span className="font-medium text-birincil">{esik}</span>
            <span>100</span>
          </div>
          <p className="text-xs text-metin-ikincil mt-2">AI puanı bu değerin altında olan araçlar vitrinde gösterilmez</p>
        </div>
        <div>
          <h3 className="text-sm font-medium text-metin-birincil mb-2">Toplu İşlemler</h3>
          <div className="flex gap-3">
            <button onClick={topluAnaliz} disabled={yukleniyor} className="px-4 py-2 bg-birincil text-white text-sm font-medium rounded-lg hover:bg-birincil-koyu disabled:opacity-50">
              {yukleniyor ? "İşleniyor..." : "Tümünü Yeniden Analiz Et"}
            </button>
            <button onClick={gizliAktiflestir} disabled={yukleniyor} className="px-4 py-2 border border-kenarlik-acik text-sm font-medium rounded-lg hover:border-birincil disabled:opacity-50">
              Gizli Olanları Aktifleştir
            </button>
          </div>
          {islemSonucu && <p className="text-sm text-birincil mt-2">{islemSonucu}</p>}
        </div>
      </div>
    </YonetimLayout>
  );
}
