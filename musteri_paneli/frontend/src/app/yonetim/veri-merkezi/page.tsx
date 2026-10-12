"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import YonetimLayout from "@/bilesenler/YonetimLayout";
import { useAuth } from "@/kancalar/yetkiKullan";
import {
  getMarketBackfillTargets,
  getMarketCoverageSummary,
  type MarketBackfillTarget,
  type MarketCoverageSummaryResponse,
} from "@/lib/api";

const emptySummary: MarketCoverageSummaryResponse = {
  success: false,
  total_rows: 0,
  healthy: 0,
  underfilled: 0,
  filled_imbalanced: 0,
  stale: 0,
  coverage: [],
};

function statusLabel(status: string) {
  switch (status) {
    case "healthy":
      return "Saglikli";
    case "underfilled":
      return "Eksik";
    case "filled_imbalanced":
      return "Dengesiz";
    case "stale":
      return "Eski";
    default:
      return status || "-";
  }
}

function reasonClass(reason: string) {
  switch (reason) {
    case "underfilled":
      return "bg-red-100 text-red-700";
    case "filled_imbalanced":
      return "bg-yellow-100 text-yellow-700";
    case "stale":
      return "bg-blue-100 text-blue-700";
    default:
      return "bg-gray-100 text-gray-700";
  }
}

function valueOrDash(value?: string | null) {
  return value && value !== "unknown" ? value : "-";
}

export default function VeriMerkeziPage() {
  const { user, loading: authLoading } = useAuth();
  const [summary, setSummary] = useState<MarketCoverageSummaryResponse>(emptySummary);
  const [targets, setTargets] = useState<MarketBackfillTarget[]>([]);
  const [targetTotal, setTargetTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastLoadedAt, setLastLoadedAt] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && (!user || user.role !== "admin")) {
      window.location.href = "/";
    }
  }, [authLoading, user]);

  const loadCoverage = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [coverageResponse, backfillResponse] = await Promise.all([
        getMarketCoverageSummary(),
        getMarketBackfillTargets(),
      ]);
      setSummary(coverageResponse);
      setTargets(backfillResponse.targets || []);
      setTargetTotal(backfillResponse.total || 0);
      setLastLoadedAt(new Date().toLocaleTimeString("tr-TR"));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Veri merkezi bilgileri alinamadi");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (user?.role !== "admin") return;
    // Ilk yukleme bir sonraki tikte: effect icinde senkron setState olmasin
    const first = window.setTimeout(() => loadCoverage(), 0);
    return () => window.clearTimeout(first);
  }, [loadCoverage, user?.role]);

  const coverageRate = useMemo(() => {
    if (!summary.total_rows) return "0%";
    return `${Math.round((summary.healthy / summary.total_rows) * 100)}%`;
  }, [summary.healthy, summary.total_rows]);

  if (authLoading || loading) {
    return (
      <YonetimLayout aktif="/yonetim/veri-merkezi">
        <div className="text-metin-ikincil">Veri merkezi yukleniyor...</div>
      </YonetimLayout>
    );
  }

  if (!user || user.role !== "admin") return null;

  return (
    <YonetimLayout aktif="/yonetim/veri-merkezi">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-metin-birincil">Veri Merkezi</h2>
          <p className="mt-1 text-sm text-metin-ikincil">
            Piyasa referans verisinin marka, model ve yil kovasi bazinda sagligini izleyin.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={loadCoverage}
            className="rounded-lg border border-kenarlik-acik px-4 py-2 text-sm font-medium text-metin-birincil"
          >
            Yenile
          </button>
          <Link href="/yonetim/kaziyici" className="rounded-lg bg-birincil px-4 py-2 text-sm font-medium text-white">
            Kaziyici Kontrol
          </Link>
        </div>
      </div>

      {error && (
        <div className="mt-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
        <SummaryCard label="Kapsam" value={coverageRate} />
        <SummaryCard label="Toplam kova" value={summary.total_rows.toString()} />
        <SummaryCard label="Saglikli" value={summary.healthy.toString()} tone="green" />
        <SummaryCard label="Eksik" value={summary.underfilled.toString()} tone="red" />
        <SummaryCard label="Dengesiz" value={summary.filled_imbalanced.toString()} tone="yellow" />
        <SummaryCard label="Eski" value={summary.stale.toString()} tone="blue" />
      </div>

      <div className="mt-6 flex flex-col gap-2 border-b border-kenarlik-acik pb-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="text-base font-semibold text-metin-birincil">Backfill Hedefleri</h3>
          <p className="mt-1 text-sm text-metin-ikincil">
            Ilk {targets.length} hedef gosteriliyor. Toplam hedef: {targetTotal}.
          </p>
        </div>
        <div className="text-xs text-metin-ikincil">Son guncelleme: {lastLoadedAt || "-"}</div>
      </div>

      {targets.length === 0 ? (
        <div className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6 text-sm text-metin-ikincil">
          Backfill hedefi bulunmuyor.
        </div>
      ) : (
        <div className="mt-4 overflow-x-auto rounded-lg border border-kenarlik-acik bg-white">
          <table className="min-w-full divide-y divide-kenarlik-acik text-sm">
            <thead className="bg-gray-50 text-left text-xs uppercase tracking-wide text-metin-ikincil">
              <tr>
                <th className="px-4 py-3">Arac</th>
                <th className="px-4 py-3">Segment</th>
                <th className="px-4 py-3">Yil kovasi</th>
                <th className="px-4 py-3">Eksik</th>
                <th className="px-4 py-3">Yakit</th>
                <th className="px-4 py-3">Vites</th>
                <th className="px-4 py-3">Sebep</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-kenarlik-acik">
              {targets.map((target, index) => (
                <BackfillRow key={`${target.brand}-${target.model}-${target.year_bucket}-${index}`} target={target} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </YonetimLayout>
  );
}

function SummaryCard({ label, value, tone = "default" }: { label: string; value: string; tone?: "default" | "green" | "red" | "yellow" | "blue" }) {
  const toneClass = {
    default: "text-metin-birincil",
    green: "text-green-700",
    red: "text-red-700",
    yellow: "text-yellow-700",
    blue: "text-blue-700",
  }[tone];

  return (
    <div className="rounded-lg border border-kenarlik-acik bg-white p-4">
      <div className="text-xs text-metin-ikincil">{label}</div>
      <div className={`mt-1 text-xl font-bold ${toneClass}`}>{value}</div>
    </div>
  );
}

function BackfillRow({ target }: { target: MarketBackfillTarget }) {
  return (
    <tr className="hover:bg-gray-50">
      <td className="px-4 py-3">
        <div className="font-semibold text-metin-birincil">{target.brand}</div>
        <div className="text-xs text-metin-ikincil">{target.model}</div>
      </td>
      <td className="px-4 py-3 text-metin-ikincil">{target.segment}</td>
      <td className="px-4 py-3 text-metin-ikincil">{target.year_bucket}</td>
      <td className="px-4 py-3 font-semibold text-metin-birincil">{target.missing_count}</td>
      <td className="px-4 py-3 text-metin-ikincil">{valueOrDash(target.preferred_fuel)}</td>
      <td className="px-4 py-3 text-metin-ikincil">{valueOrDash(target.preferred_transmission)}</td>
      <td className="px-4 py-3">
        <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${reasonClass(target.reason)}`}>
          {statusLabel(target.reason)}
        </span>
      </td>
    </tr>
  );
}
