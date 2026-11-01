"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import DegerlemeSonucu from "@/bilesenler/DegerlemeSonucu";
import { useAuth } from "@/kancalar/yetkiKullan";
import { downloadValuationPdf, getValuationReport, type ValuationReportSummary, type ValuationResult } from "@/lib/api";

export default function DegerlemeDetayi() {
  const { id } = useParams<{ id: string }>();
  const { user, loading: authLoading } = useAuth();
  const [report, setReport] = useState<ValuationResult | ValuationReportSummary | null>(null);
  const [error, setError] = useState("");
  const [downloadError, setDownloadError] = useState("");
  const [downloading, setDownloading] = useState(false);
  const userId = user?.id;

  useEffect(() => {
    if (!userId) return;
    const controller = new AbortController();
    setReport(null);
    setError("");
    getValuationReport(id, controller.signal).then((data) => {
      if (!controller.signal.aborted) setReport(data);
    }).catch((err) => { if (!controller.signal.aborted) setError(err instanceof Error ? err.message : "Rapor alınamadı"); });
    return () => controller.abort();
  }, [id, userId]);

  async function download() {
    setDownloading(true);
    setDownloadError("");
    try {
      const blob = await downloadValuationPdf(id);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = `degerleme-${id}.pdf`;
      anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (err) {
      setDownloadError(err instanceof Error ? err.message : "PDF indirilemedi");
    } finally {
      setDownloading(false);
    }
  }

  return <main className="mx-auto max-w-4xl px-4 py-10">
    <Link href="/panel/degerlemeler" className="text-birincil underline">Raporlarım</Link>
    <h1 className="mt-4 text-3xl font-bold text-metin-birincil">Kredili değerleme raporu</h1>
    {authLoading ? <p role="status" className="mt-6">Yükleniyor…</p> : !user ? <Link href="/giris" className="mt-6 block text-birincil underline">Raporunuzu görmek için giriş yapın</Link> : <>
      {error && <p role="alert" className="mt-6 text-red-700">{error}</p>}
      {!report && !error && <p role="status" className="mt-6">Rapor yükleniyor…</p>}
      {report && ("ozet_kayit" in report ? <section className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
        <h2 className="text-xl font-semibold">Özet kayıt</h2>
        <p className="mt-2">{[report.arac.marka, report.arac.model, report.arac.yil].filter(Boolean).join(" ")}</p>
        <p className="mt-2">{new Date(report.created_at).toLocaleString("tr-TR")} • {report.karar || "Analiz"} • {report.kredi} kredi</p>
        <p className="mt-2 text-metin-ikincil">Bu eski analiz için yalnızca özet kaydedilmiş; tam rapor ve PDF bulunmuyor.</p>
      </section> : <>
        <button onClick={download} disabled={downloading} className="mt-6 rounded-lg bg-birincil px-5 py-2 font-semibold text-white disabled:opacity-50">{downloading ? "PDF hazırlanıyor…" : "PDF indir"}</button>
        {downloadError && <p role="alert" className="mt-3 text-red-700">{downloadError}</p>}
        <DegerlemeSonucu sonuc={report} />
      </>)}
    </>}
  </main>;
}
