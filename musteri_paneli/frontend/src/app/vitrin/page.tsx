"use client";

import { useEffect, useState, useCallback } from "react";
import AracKarti from "@/bilesenler/AracKarti";
import FiltreCubugu from "@/bilesenler/FiltreCubugu";
import { getVehicles, type VehicleCard } from "@/lib/api";

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

export default function VitrinSayfasi() {
  const [araclar, setAraclar] = useState<VehicleCard[]>([]);
  const [toplam, setToplam] = useState(0);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [sayfa, setSayfa] = useState(0);
  const limit = 24;

  const [filtreler, setFiltreler] = useState<Filtreler>({
    brand: "", model: "", min_price: "", max_price: "", min_score: "", source: "", decision: "", sort_by: "updated_at",
  });

  const araclarGetir = useCallback(async (offset: number, reset = false) => {
    setYukleniyor(true);
    try {
      const params: Record<string, string | number | undefined> = {
        limit, offset,
        brand: filtreler.brand || undefined,
        model: filtreler.model || undefined,
        min_price: filtreler.min_price ? Number(filtreler.min_price) : undefined,
        max_price: filtreler.max_price ? Number(filtreler.max_price) : undefined,
        min_score: filtreler.min_score ? Number(filtreler.min_score) : undefined,
        source: filtreler.source || undefined,
        decision: filtreler.decision || undefined,
        sort_by: filtreler.sort_by || "updated_at",
      };
      const sonuc = await getVehicles(params);
      setToplam(sonuc.total);
      setAraclar(reset ? sonuc.vehicles : (prev) => [...prev, ...sonuc.vehicles]);
    } catch (hata) {
      console.error("Vitrin yükleme hatası:", hata);
    } finally {
      setYukleniyor(false);
    }
  }, [filtreler, limit]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      araclarGetir(0, true);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [filtreler, araclarGetir]);

  const filtreleriGuncelle = (yeniFiltreler: Filtreler) => {
    setSayfa(0);
    setFiltreler(yeniFiltreler);
  };

  const dahaFazla = () => {
    const yeniSayfa = sayfa + 1;
    setSayfa(yeniSayfa);
    araclarGetir(yeniSayfa * limit);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-metin-birincil">Araç Vitrini</h1>
        <p className="text-metin-ikincil mt-1">AI ile analiz edilmiş araçları keşfedin</p>
      </div>

      <FiltreCubugu filtreler={filtreler} onChange={filtreleriGuncelle} />

      <div className="mt-6 flex items-center justify-between">
        <span className="text-sm text-metin-ikincil">{toplam} araç bulundu</span>
      </div>

      {yukleniyor && araclar.length === 0 ? (
        <div className="mt-12 text-center text-metin-ikincil">
          <div className="animate-spin w-8 h-8 border-2 border-birincil border-t-transparent rounded-full mx-auto mb-4" />
          Araçlar yükleniyor...
        </div>
      ) : araclar.length === 0 ? (
        <div className="mt-12 text-center text-metin-ikincil">
          <p className="text-lg">Araç bulunamadı</p>
          <p className="text-sm mt-2">Filtreleri değiştirmeyi deneyin</p>
        </div>
      ) : (
        <>
          <div className="mt-6 grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {araclar.map((arac) => <AracKarti key={arac.id} arac={arac} />)}
          </div>
          {araclar.length < toplam && (
            <div className="mt-8 text-center">
              <button onClick={dahaFazla} disabled={yukleniyor} className="px-6 py-3 bg-white border border-kenarlik-acik rounded-lg text-sm font-medium text-metin-birincil hover:border-birincil transition-colors disabled:opacity-50">
                {yukleniyor ? "Yükleniyor..." : "Daha Fazla Göster"}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
