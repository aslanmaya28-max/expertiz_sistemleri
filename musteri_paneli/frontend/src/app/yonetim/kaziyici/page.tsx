"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import {
  getScraperStatus,
  startScraper,
  stopScraper,
  type ScraperActionResponse,
  type ScraperSource,
  type ScraperSourceStatus,
  type ScraperStatusResponse,
} from "@/lib/api";
import YonetimLayout from "@/bilesenler/YonetimLayout";

const sources = ["arabam", "borusan"] as const;

const fallbackStatus: ScraperStatusResponse = {
  arabam: { source: "arabam", status: "unknown", pid: null, last_activity: null },
  borusan: { source: "borusan", status: "unknown", pid: null, last_activity: null },
  active_workers: 0,
  total_workers: 2,
};

function sourceLabel(source: "arabam" | "borusan") {
  return source === "arabam" ? "Arabam.com" : "Borusan";
}

function statusText(status?: string) {
  switch (status) {
    case "running":
      return "Calisiyor";
    case "idle":
      return "Durdu";
    case "starting":
      return "Baslatiliyor";
    case "stopping":
      return "Durduruluyor";
    case "error":
      return "Hata";
    default:
      return "Bilinmiyor";
  }
}

function statusClass(status?: string) {
  switch (status) {
    case "running":
      return "bg-green-100 text-green-700";
    case "starting":
    case "stopping":
      return "bg-blue-100 text-blue-700";
    case "error":
      return "bg-red-100 text-red-700";
    case "idle":
      return "bg-gray-100 text-gray-700";
    default:
      return "bg-yellow-100 text-yellow-700";
  }
}

export default function KaziyiciKontrol() {
  const { user, loading: authLoading } = useAuth();
  const [status, setStatus] = useState<ScraperStatusResponse>(fallbackStatus);
  const [loading, setLoading] = useState(true);
  const [busySource, setBusySource] = useState<ScraperSource | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && (!user || user.role !== "admin")) {
      window.location.href = "/";
    }
  }, [authLoading, user]);

  const loadStatus = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    setError(null);
    try {
      const nextStatus = await getScraperStatus();
      setStatus(nextStatus);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Kaziyici durumu alinamadi");
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (user?.role !== "admin") return;
    const firstLoad = window.setTimeout(() => loadStatus(), 0);
    const interval = window.setInterval(() => loadStatus(true), 15000);
    return () => {
      window.clearTimeout(firstLoad);
      window.clearInterval(interval);
    };
  }, [loadStatus, user?.role]);

  const activeWorkers = useMemo(
    () => sources.filter((source) => status[source]?.status === "running").length,
    [status],
  );

  async function runAction(action: "start" | "stop", source: ScraperSource) {
    setBusySource(source);
    setMessage(null);
    setError(null);

    const optimisticStatus = action === "start" ? "starting" : "stopping";
    if (source !== "all") {
      setStatus((prev) => ({
        ...prev,
        [source]: { ...prev[source], status: optimisticStatus },
      }));
    }

    try {
      const result: ScraperActionResponse = action === "start"
        ? await startScraper(source)
        : await stopScraper(source);
      setMessage(result.message || `${source} ${action === "start" ? "baslatildi" : "durduruldu"}`);
      await loadStatus(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Islem tamamlanamadi");
      await loadStatus(true);
    } finally {
      setBusySource(null);
    }
  }

  if (authLoading || loading) {
    return (
      <YonetimLayout aktif="/yonetim/kaziyici">
        <div className="text-metin-ikincil">Kaziyici durumu yukleniyor...</div>
      </YonetimLayout>
    );
  }

  if (!user || user.role !== "admin") return null;

  return (
    <YonetimLayout aktif="/yonetim/kaziyici">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-metin-birincil">Kaziyici Kontrol</h2>
          <p className="mt-1 text-sm text-metin-ikincil">
            Arabam.com ve Borusan kaynaklarini vitrin icin tek noktadan yonetin.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => loadStatus()}
            disabled={Boolean(busySource)}
            className="rounded-lg border border-kenarlik-acik px-4 py-2 text-sm font-medium text-metin-birincil disabled:opacity-50"
          >
            Yenile
          </button>
          <button
            onClick={() => runAction("start", "all")}
            disabled={Boolean(busySource)}
            className="rounded-lg bg-basarili px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
          >
            Tumunu baslat
          </button>
          <button
            onClick={() => runAction("stop", "all")}
            disabled={Boolean(busySource)}
            className="rounded-lg bg-tehlike px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
          >
            Tumunu durdur
          </button>
        </div>
      </div>

      <div className="mt-5 grid gap-4 sm:grid-cols-3">
        <SummaryCard label="Aktif worker" value={`${activeWorkers}/${status.total_workers || 2}`} />
        <SummaryCard label="API durumu" value={error ? "Hata" : "Bagli"} />
        <SummaryCard label="Son kontrol" value={new Date().toLocaleTimeString("tr-TR")} />
      </div>

      {message && <div className="mt-5 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700">{message}</div>}
      {error && <div className="mt-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

      <div className="mt-6 grid gap-6 sm:grid-cols-2">
        {sources.map((source) => (
          <ScraperCard
            key={source}
            source={source}
            status={status[source]}
            busy={busySource === source || busySource === "all"}
            onStart={() => runAction("start", source)}
            onStop={() => runAction("stop", source)}
          />
        ))}
      </div>
    </YonetimLayout>
  );
}

function SummaryCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-kenarlik-acik bg-white p-4">
      <div className="text-xs text-metin-ikincil">{label}</div>
      <div className="mt-1 text-xl font-bold text-metin-birincil">{value}</div>
    </div>
  );
}

function ScraperCard({
  source,
  status,
  busy,
  onStart,
  onStop,
}: {
  source: "arabam" | "borusan";
  status: ScraperSourceStatus;
  busy: boolean;
  onStart: () => void;
  onStop: () => void;
}) {
  const running = status.status === "running";

  return (
    <div className="rounded-lg border border-kenarlik-acik bg-white p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="font-semibold text-metin-birincil">{sourceLabel(source)}</h3>
          <span className={`mt-2 inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(status.status)}`}>
            {statusText(status.status)}
          </span>
        </div>
        <div className="text-right text-xs text-metin-ikincil">
          <div>PID</div>
          <div className="mt-1 font-mono text-metin-birincil">{status.pid || "-"}</div>
        </div>
      </div>

      <div className="mt-5 rounded-lg bg-gray-50 px-3 py-2 text-xs text-metin-ikincil">
        Son aktivite: {status.last_activity || "-"}
      </div>

      <div className="mt-5 flex gap-3">
        <button
          onClick={onStart}
          disabled={busy || running}
          className="rounded-lg bg-basarili px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
        >
          Baslat
        </button>
        <button
          onClick={onStop}
          disabled={busy || !running}
          className="rounded-lg bg-tehlike px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
        >
          Durdur
        </button>
      </div>
    </div>
  );
}
