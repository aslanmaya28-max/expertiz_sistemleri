"use client";

import Link from "next/link";
import Image from "next/image";
import { useState } from "react";
import { addFavorite, removeFavorite, type VehicleCard } from "@/lib/api";
import { useAuth } from "@/kancalar/yetkiKullan";

function formatPrice(price: number): string {
  return new Intl.NumberFormat("tr-TR").format(price) + " ₺";
}

function formatKm(km: number): string {
  return new Intl.NumberFormat("tr-TR").format(km) + " km";
}

function getScoreColor(score: number | null): string {
  if (!score) return "text-metin-ikincil";
  if (score >= 70) return "text-basarili";
  if (score >= 50) return "text-uyari";
  return "text-tehlike";
}

function getDecisionBadge(decision: string | null): { text: string; cls: string } {
  if (!decision) return { text: "-", cls: "bg-gray-100 text-gray-500" };
  const map: Record<string, { text: string; cls: string }> = {
    STRONG_BUY: { text: "KUVVETLİ AL", cls: "bg-green-100 text-green-700" },
    BUY: { text: "AL", cls: "bg-green-100 text-green-700" },
    NEGOTIATE: { text: "PAZARLIK", cls: "bg-yellow-100 text-yellow-700" },
    HOLD: { text: "BEKLE", cls: "bg-yellow-100 text-yellow-700" },
    AVOID: { text: "KAÇIN", cls: "bg-red-100 text-red-700" },
  };
  return map[decision] || { text: decision, cls: "bg-gray-100 text-gray-500" };
}

function getSourceBadge(source: string): { text: string; cls: string } {
  const map: Record<string, { text: string; cls: string }> = {
    arabam: { text: "Arabam.com", cls: "bg-blue-100 text-blue-700" },
    borusan: { text: "Borusan", cls: "bg-purple-100 text-purple-700" },
  };
  return map[source] || { text: source, cls: "bg-gray-100 text-gray-500" };
}

export default function AracKarti({ arac }: { arac: VehicleCard }) {
  const { user } = useAuth();
  const karar = getDecisionBadge(arac.decision);
  const kaynak = getSourceBadge(arac.source);
  const [favorite, setFavorite] = useState(Boolean(arac.is_favorite));
  const [favoriteLoading, setFavoriteLoading] = useState(false);
  const [favoriteError, setFavoriteError] = useState<string | null>(null);

  async function toggleFavorite() {
    if (!user) {
      window.location.href = "/giris";
      return;
    }
    setFavoriteLoading(true);
    setFavoriteError(null);
    try {
      if (favorite) {
        await removeFavorite(arac.id);
        setFavorite(false);
      } else {
        await addFavorite(arac.id);
        setFavorite(true);
      }
    } catch (err) {
      setFavoriteError(err instanceof Error ? err.message : "Favori islemi tamamlanamadi");
    } finally {
      setFavoriteLoading(false);
    }
  }

  return (
    <div className="group bg-white rounded-xl border border-kenarlik-acik overflow-hidden hover:shadow-lg hover:border-birincil/30 transition-all duration-200">
      <Link href={`/arac-analiz/${arac.id}`} className="block">
        <div className="relative h-48 bg-gray-100">
          {arac.image_url ? (
            <Image
              src={arac.image_url}
              alt={arac.title || `${arac.brand} ${arac.model}`}
              fill
              sizes="(min-width: 1280px) 25vw, (min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw"
              className="object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-metin-ikincil">
              <svg className="w-12 h-12 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
          )}

          {arac.ai_score !== null && (
            <div className="absolute top-3 left-3 w-12 h-12 rounded-full bg-white shadow-md flex items-center justify-center">
              <span className={`text-sm font-bold ${getScoreColor(arac.ai_score)}`}>{arac.ai_score}</span>
            </div>
          )}

          <div className="absolute top-3 right-3">
            <span className={`text-xs px-2 py-1 rounded-full font-medium ${kaynak.cls}`}>{kaynak.text}</span>
          </div>

          {arac.price_deviation_pct < -5 && (
            <div className="absolute bottom-3 left-3">
              <span className="text-xs px-2 py-1 rounded-full font-medium bg-green-100 text-green-700">
                %{Math.abs(arac.price_deviation_pct).toFixed(1)} altında
              </span>
            </div>
          )}
        </div>

        <div className="p-4">
          <h3 className="font-semibold text-metin-birincil truncate group-hover:text-birincil transition-colors">
            {arac.title || `${arac.brand} ${arac.model} ${arac.year}`}
          </h3>

          <div className="mt-2 flex items-center justify-between">
            <span className="text-lg font-bold text-metin-birincil">{formatPrice(arac.price)}</span>
            <span className={`text-xs px-2 py-0.5 rounded font-semibold ${karar.cls}`}>{karar.text}</span>
          </div>

          <div className="mt-3 flex flex-wrap gap-2 text-xs text-metin-ikincil">
            <span>{arac.year}</span>
            <span>•</span>
            <span>{formatKm(arac.km)}</span>
            {arac.fuel && arac.fuel !== 'Belirtilmemiş' && arac.fuel !== 'Bilinmiyor' && (
              <>
                <span>•</span>
                <span>{arac.fuel}</span>
              </>
            )}
            {arac.transmission && arac.transmission !== 'Belirtilmemiş' && arac.transmission !== 'Bilinmiyor' && (
              <>
                <span>•</span>
                <span>{arac.transmission}</span>
              </>
            )}
          </div>

          {arac.location && (
            <div className="mt-2 text-xs text-metin-ikincil flex items-center gap-1">
              <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              {arac.location}
            </div>
          )}

          {(arac.paint_summary.painted > 0 || arac.paint_summary.changed > 0) && (
            <div className="mt-2 flex gap-1">
              {arac.paint_summary.painted > 0 && (
                <span className="text-xs px-1.5 py-0.5 bg-yellow-50 text-yellow-600 rounded">{arac.paint_summary.painted} boyalı</span>
              )}
              {arac.paint_summary.local > 0 && (
                <span className="text-xs px-1.5 py-0.5 bg-orange-50 text-orange-600 rounded">{arac.paint_summary.local} lokal</span>
              )}
              {arac.paint_summary.changed > 0 && (
                <span className="text-xs px-1.5 py-0.5 bg-red-50 text-red-600 rounded">{arac.paint_summary.changed} değişen</span>
              )}
            </div>
          )}
        </div>
      </Link>

      <div className="px-4 pb-4 grid grid-cols-3 gap-2">
        <button
          type="button"
          onClick={toggleFavorite}
          disabled={favoriteLoading}
          title={favorite ? "Favoriden kaldir" : "Favoriye ekle"}
          className="text-center text-sm font-medium border border-kenarlik-acik rounded-lg py-2 text-metin-birincil hover:border-birincil disabled:opacity-60 transition-colors"
        >
          {favorite ? "Kayitli" : "Kaydet"}
        </button>
        <Link href={`/arac-analiz/${arac.id}`} className="text-center text-sm font-medium border border-kenarlik-acik rounded-lg py-2 text-metin-birincil hover:border-birincil transition-colors">
          Detay
        </Link>
        <Link href={`/ekspertiz-talebi?aracId=${arac.id}`} className="text-center text-sm font-semibold rounded-lg py-2 bg-birincil text-white hover:opacity-90 transition-opacity">
          Ekspertiz Talebi
        </Link>
      </div>
      {favoriteError && <div className="px-4 pb-4 text-xs text-tehlike">{favoriteError}</div>}
    </div>
  );
}
