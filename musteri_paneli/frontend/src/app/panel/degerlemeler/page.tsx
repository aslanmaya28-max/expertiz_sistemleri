"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { getValuationReports, type ValuationReportSummary } from "@/lib/api";

const PAGE_SIZE = 20;

export default function DegerlemeRaporlari() {
  const { user, loading: authLoading } = useAuth();
  const [reports, setReports] = useState<ValuationReportSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const userId = user?.id;

  useEffect(() => {
    if (!userId) return;
    const controller = new AbortController();
    setLoading(true);
    setError("");
    getValuationReports(PAGE_SIZE, offset, controller.signal).then((data) => {
      if (controller.signal.aborted) return;
      setReports(data.reports);
      setTotal(data.total);
    }).catch((err) => {
      if (!controller.signal.aborted) setError(err instanceof Error ? err.message : "Raporlar alınamadı");
    }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [userId, offset]);

  return <main className="mx-auto max-w-4xl px-4 py-10">
    <Link href="/panel" className="text-birincil underline">Panelim</Link>
    <h1 className="mt-4 text-3xl font-bold text-metin-birincil">Raporlarım — kredili değerlemeler</h1>
    <p className="mt-2 text-metin-ikincil">Ödediğiniz raporları tekrar açabilir, PDF indirebilir ve doğrulama kodunu paylaşabilirsiniz.</p>
    {authLoading ? <p className="mt-6" role="status">Yükleniyor…</p> : !user ? <Link href="/giris" className="mt-6 block text-birincil underline">Raporlarınızı görmek için giriş yapın</Link> : <>
      {error && <p role="alert" className="mt-6 text-red-700">{error}</p>}
      {loading ? <p role="status" className="mt-6">Raporlar yükleniyor…</p> : !error && <>
        {reports.length === 0 && <p className="mt-6">Henüz değerleme raporunuz yok. <Link href="/arac-analiz" className="text-birincil underline">Yeni analiz</Link></p>}
        <ul className="mt-6 space-y-3">{reports.map((report) => <li key={report.id}>
          <Link href={`/panel/degerlemeler/${encodeURIComponent(report.id)}`} className="block rounded-lg border border-kenarlik-acik bg-white p-5 hover:border-birincil">
            <span className="font-semibold">{[report.arac.marka, report.arac.model, report.arac.yil].filter(Boolean).join(" ") || "Araç analizi"}</span>
            <p className="mt-2 text-sm text-metin-ikincil">{new Date(report.created_at).toLocaleString("tr-TR")} • {report.karar || "Analiz"} • {report.kredi} kredi</p>
            <p className="mt-1 text-sm">{report.ozet_kayit ? "Özet kayıt — tam rapor bulunmuyor" : report.report_no}</p>
          </Link>
        </li>)}</ul>
        <nav aria-label="Rapor sayfaları" className="mt-6 flex items-center gap-4">
          <button disabled={offset === 0} onClick={() => setOffset(Math.max(0, offset-PAGE_SIZE))} className="text-birincil disabled:opacity-40">Önceki</button>
          <span className="text-sm">{total} kayıt • Sayfa {Math.floor(offset/PAGE_SIZE)+1}</span>
          <button disabled={offset+PAGE_SIZE >= total} onClick={() => setOffset(offset+PAGE_SIZE)} className="text-birincil disabled:opacity-40">Sonraki</button>
        </nav>
      </>}
    </>}
  </main>;
}
