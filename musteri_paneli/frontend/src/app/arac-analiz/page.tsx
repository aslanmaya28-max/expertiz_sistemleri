"use client";

import { useState } from "react";
import { getToken } from "@/lib/yetki";

export default function AracAnalizSayfasi() {
  const [form, setForm] = useState({ brand: "", model: "", year: "", km: "", price: "", fuel: "Benzin", gear: "Otomatik" });
  const [sonuc, setSonuc] = useState<Record<string, unknown> | null>(null);
  const [yukleniyor, setYukleniyor] = useState(false);

  const gonder = async (e: React.FormEvent) => {
    e.preventDefault();
    setYukleniyor(true);
    try {
      const token = getToken();
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (token) headers["Authorization"] = `Bearer ${token}`;
      const res = await fetch("/api/v1/analyze", {
        method: "POST",
        headers,
        body: JSON.stringify({
          brand: form.brand, model: form.model, year: Number(form.year),
          mileage_km: Number(form.km), fuel_type: form.fuel, gear_type: form.gear,
          listed_price: Number(form.price),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || "Analiz başarısız");
      setSonuc(data);
    } catch (err) {
      alert(err instanceof Error ? err.message : "Bir hata oluştu");
    } finally {
      setYukleniyor(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-metin-birincil mb-2">Araç Analiz</h1>
      <p className="text-metin-ikincil mb-8">Araç bilgilerini girin, AI analiz yapsın</p>

      <form onSubmit={gonder} className="bg-white rounded-xl border border-kenarlik-acik p-6 space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Marka</label>
            <input required value={form.brand} onChange={(e) => setForm({ ...form, brand: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" placeholder="Volkswagen" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Model</label>
            <input required value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" placeholder="T-Roc" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Yıl</label>
            <input required type="number" value={form.year} onChange={(e) => setForm({ ...form, year: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" placeholder="2022" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">KM</label>
            <input required type="number" value={form.km} onChange={(e) => setForm({ ...form, km: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" placeholder="45000" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Yakıt</label>
            <select value={form.fuel} onChange={(e) => setForm({ ...form, fuel: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
              <option>Benzin</option><option>Dizel</option><option>Hibrit</option><option>Elektrik</option><option>LPG</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Vites</label>
            <select value={form.gear} onChange={(e) => setForm({ ...form, gear: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
              <option>Otomatik</option><option>Manuel</option><option>Yarı Otomatik</option>
            </select>
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-metin-birincil mb-1">İlan Fiyatı (₺)</label>
          <input required type="number" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} className="w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" placeholder="850000" />
        </div>
        <button type="submit" disabled={yukleniyor} className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
          {yukleniyor ? "Analiz Ediliyor..." : "Analiz Yap (1 Kredi)"}
        </button>
      </form>

      {sonuc && (
        <div className="mt-8 bg-white rounded-xl border border-kenarlik-acik p-6">
          <h2 className="text-xl font-bold text-metin-birincil mb-4">Analiz Sonucu</h2>
          <pre className="text-xs bg-gray-50 p-4 rounded-lg overflow-auto max-h-96">{JSON.stringify(sonuc, null, 2)}</pre>
        </div>
      )}
    </div>
  );
}
