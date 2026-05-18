"use client";

import { useState, useEffect } from "react";
import { getBrands, getModels, type BrandInfo, type ModelInfo } from "@/lib/api";

interface Filtreler {
  brand: string;
  model: string;
  min_price: string;
  max_price: string;
  min_score: string;
  source: string;
  decision: string;
  sort_by: string;
}

interface Props {
  filtreler: Filtreler;
  onChange: (f: Filtreler) => void;
}

export default function FiltreCubugu({ filtreler, onChange }: Props) {
  const [markalar, setMarkalar] = useState<BrandInfo[]>([]);
  const [modeller, setModeller] = useState<ModelInfo[]>([]);
  const [acik, setAcik] = useState(false);

  useEffect(() => {
    getBrands().then(setMarkalar).catch(() => {});
  }, []);

  useEffect(() => {
    if (filtreler.brand) {
      getModels(filtreler.brand).then(setModeller).catch(() => setModeller([]));
    }
  }, [filtreler.brand]);

  const guncelle = (key: keyof Filtreler, value: string) => {
    const yeni = { ...filtreler, [key]: value };
    if (key === "brand") {
      yeni.model = "";
    }
    onChange(yeni);
  };

  const temizle = () => {
    onChange({ brand: "", model: "", min_price: "", max_price: "", min_score: "", source: "", decision: "", sort_by: "updated_at" });
  };

  const aktifFiltreSayisi = Object.values(filtreler).filter((v) => v && v !== "updated_at").length;

  return (
    <div className="bg-white border border-kenarlik-acik rounded-xl p-4">
      <div className="flex items-center justify-between">
        <button onClick={() => setAcik(!acik)} className="flex items-center gap-2 text-sm font-medium text-metin-birincil">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
          </svg>
          Filtreler
          {aktifFiltreSayisi > 0 && (
            <span className="px-1.5 py-0.5 bg-birincil text-white text-xs rounded-full">{aktifFiltreSayisi}</span>
          )}
        </button>
        {aktifFiltreSayisi > 0 && (
          <button onClick={temizle} className="text-xs text-metin-ikincil hover:text-tehlike transition-colors">Temizle</button>
        )}
      </div>

      {acik && (
        <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-3">
          <select value={filtreler.brand} onChange={(e) => guncelle("brand", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
            <option value="">Tüm Markalar</option>
            {markalar.map((m) => <option key={m.brand} value={m.brand}>{m.brand} ({m.count})</option>)}
          </select>

          <select value={filtreler.model} onChange={(e) => guncelle("model", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" disabled={!filtreler.brand}>
            <option value="">Tüm Modeller</option>
            {modeller.map((m) => <option key={m.model} value={m.model}>{m.model} ({m.count})</option>)}
          </select>

          <input type="number" placeholder="Min Fiyat" value={filtreler.min_price} onChange={(e) => guncelle("min_price", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" />
          <input type="number" placeholder="Max Fiyat" value={filtreler.max_price} onChange={(e) => guncelle("max_price", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm" />

          <select value={filtreler.min_score} onChange={(e) => guncelle("min_score", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
            <option value="">AI Puanı</option>
            <option value="80">80+ (Mükemmel)</option>
            <option value="70">70+ (İyi)</option>
            <option value="50">50+ (Orta)</option>
          </select>

          <select value={filtreler.source} onChange={(e) => guncelle("source", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
            <option value="">Tüm Kaynaklar</option>
            <option value="arabam">Arabam.com</option>
            <option value="borusan">Borusan</option>
          </select>

          <select value={filtreler.decision} onChange={(e) => guncelle("decision", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
            <option value="">Tüm Kararlar</option>
            <option value="STRONG_BUY">Kuvvetli Al</option>
            <option value="BUY">Al</option>
            <option value="HOLD">Bekle</option>
            <option value="AVOID">Kaçın</option>
          </select>

          <select value={filtreler.sort_by} onChange={(e) => guncelle("sort_by", e.target.value)} className="px-3 py-2 border border-kenarlik-acik rounded-lg text-sm">
            <option value="updated_at">Son Güncelleme</option>
            <option value="opportunity_score">AI Puanı</option>
            <option value="price">Fiyat</option>
            <option value="year">Yıl</option>
          </select>
        </div>
      )}
    </div>
  );
}
