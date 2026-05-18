"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { getMyExpertizReport, type ExpertizReportDetailResponse } from "@/lib/api";
import { useAuth } from "@/kancalar/yetkiKullan";

function formatPrice(value?: number | null): string {
  if (!value) return "-";
  return new Intl.NumberFormat("tr-TR").format(Math.round(value)) + " TL";
}

function formatDate(value?: string): string {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export default function MusteriRaporDetaySayfasi() {
  const { id } = useParams<{ id: string }>();
  const { user, loading } = useAuth();
  const [data, setData] = useState<ExpertizReportDetailResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dataLoading, setDataLoading] = useState(true);

  useEffect(() => {
    if (!loading && !user) {
      window.location.href = "/giris";
    }
  }, [loading, user]);

  useEffect(() => {
    if (!user || !id) return;

    async function loadReport() {
      setDataLoading(true);
      setError(null);
      try {
        setData(await getMyExpertizReport(id));
      } catch (err) {
        setError(err instanceof Error ? err.message : "Rapor yuklenemedi");
      } finally {
        setDataLoading(false);
      }
    }

    loadReport();
  }, [id, user]);

  if (loading || dataLoading) {
    return <div className="max-w-4xl mx-auto px-4 py-12 text-metin-ikincil">Rapor yukleniyor...</div>;
  }

  if (error || !data?.report) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12">
        <Link href="/panel" className="text-sm text-birincil hover:underline">Panele don</Link>
        <div className="mt-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error || "Rapor bulunamadi"}
        </div>
      </div>
    );
  }

  const report = data.report;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <Link href="/panel" className="text-sm text-birincil hover:underline">Panele don</Link>

      <div className="mt-4 rounded-lg border border-kenarlik-acik bg-white p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-metin-birincil">{report.plate || "Ekspertiz Raporu"}</h1>
            <p className="mt-1 text-metin-ikincil">{report.firm_name || "YerimeBak"} tarafindan hazirlanan yayinlanmis rapor.</p>
          </div>
          <span className="rounded-full bg-green-100 px-3 py-1 text-sm font-semibold text-green-700">Yayinlandi</span>
        </div>

        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <Info label="Yayin tarihi" value={formatDate(report.published_at)} />
          <Info label="Olusturma tarihi" value={formatDate(report.created_at)} />
          <Info label="Toplam tutar" value={formatPrice(report.summary?.total_tl)} />
          <Info label="Piyasa degeri" value={formatPrice(report.summary?.market_value)} />
        </div>

        {report.summary?.ai_comment && (
          <div className="mt-6 rounded-lg bg-gray-50 p-4">
            <div className="text-sm font-semibold text-metin-birincil">AI yorumu</div>
            <p className="mt-2 text-sm leading-6 text-metin-ikincil">{report.summary.ai_comment}</p>
          </div>
        )}

        <div className="mt-6 rounded-lg bg-gray-50 p-4">
          <div className="text-sm font-semibold text-metin-birincil">Arac ozeti</div>
          <pre className="mt-3 max-h-80 overflow-auto text-xs text-metin-ikincil">{JSON.stringify(report.vehicle || {}, null, 2)}</pre>
        </div>
      </div>
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="text-xs text-metin-ikincil">{label}</div>
      <div className="mt-1 font-semibold text-metin-birincil">{value}</div>
    </div>
  );
}
