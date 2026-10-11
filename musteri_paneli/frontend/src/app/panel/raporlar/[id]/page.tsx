"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  getMyExpertizReport,
  type ExpertizReportDetailResponse,
  type ReportChecklistItem,
  type ReportMedia,
} from "@/lib/api";
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
  const tamRapor = report.report as TamRapor;
  const kurumsal = asRecord(tamRapor?.adim5) as Record<string, string | undefined> | undefined;
  const bolumler = [
    { baslik: "Dis ekspertiz", bolum: "dis", items: checklist(tamRapor?.adim2) },
    { baslik: "Ic ekspertiz", bolum: "ic", items: checklist(tamRapor?.adim3) },
    { baslik: "Boya / kaporta", bolum: "boya_kaporta", items: checklist(tamRapor?.adim4) },
  ];

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

        <AracOzeti tamRapor={tamRapor} vehicle={report.vehicle} />
      </div>

      {(report.corporate_reports?.length ?? 0) > 0 && (
        <section className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
          <h2 className="text-lg font-semibold text-metin-birincil">Kurumsal ekspertiz raporu</h2>
          {kurumsal && (
            <p className="mt-1 text-sm text-metin-ikincil">
              {[kurumsal.kurumsalFirma, kurumsal.kurumsalPaket, kurumsal.kurumsalRaporNo && `Rapor No: ${kurumsal.kurumsalRaporNo}`]
                .filter(Boolean)
                .join(" • ")}
            </p>
          )}
          {kurumsal?.kurumsalSonucOzeti && (
            <p className="mt-3 text-sm leading-6 text-metin-ikincil">{String(kurumsal.kurumsalSonucOzeti)}</p>
          )}
          <ul className="mt-4 space-y-2">
            {report.corporate_reports!.map((m) => (
              <li key={m.id}>
                <a
                  href={m.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 rounded-lg border border-kenarlik-acik px-4 py-2 text-sm font-semibold text-birincil hover:bg-blue-50"
                >
                  {m.content_type === "application/pdf" ? "PDF" : "Gorsel"} – {m.original_name || "Kurumsal rapor"}
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {bolumler.map((bolum) => (
        <KontrolBolumu key={bolum.baslik} {...bolum} photos={report.photos ?? []} />
      ))}

      {(report.photos?.length ?? 0) > 0 && (
        <section className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
          <h2 className="text-lg font-semibold text-metin-birincil">Tum fotograflar ({report.photos!.length})</h2>
          <FotoGaleri photos={report.photos!} />
        </section>
      )}
    </div>
  );
}

type TamRapor = Record<string, unknown> | null | undefined;

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : undefined;
}

function checklist(step: unknown): ReportChecklistItem[] {
  const list = asRecord(step)?.kontrolListesi;
  return Array.isArray(list) ? (list as ReportChecklistItem[]) : [];
}

function AracOzeti({ tamRapor, vehicle }: { tamRapor: TamRapor; vehicle?: Record<string, unknown> }) {
  const adim1 = asRecord(tamRapor?.adim1);
  const satirlar: [string, unknown][] = [
    ["Marka / Model", adim1 ? `${adim1.marka ?? ""} ${adim1.model ?? ""}`.trim() : `${vehicle?.marka ?? ""} ${vehicle?.model ?? ""}`.trim()],
    ["Model yili", adim1?.yil ?? vehicle?.yil],
    ["Kilometre", adim1?.guncelKm ?? vehicle?.km],
    ["Yakit", adim1?.yakitTuru],
    ["Plaka", adim1?.plaka ?? vehicle?.plaka],
  ];
  return (
    <div className="mt-6 rounded-lg bg-gray-50 p-4">
      <div className="text-sm font-semibold text-metin-birincil">Arac ozeti</div>
      <dl className="mt-3 grid gap-2 sm:grid-cols-2">
        {satirlar
          .filter(([, v]) => v !== undefined && v !== null && String(v).trim() !== "")
          .map(([k, v]) => (
            <div key={k} className="flex justify-between gap-4 text-sm">
              <dt className="text-metin-ikincil">{k}</dt>
              <dd className="font-semibold text-metin-birincil">{String(v)}</dd>
            </div>
          ))}
      </dl>
    </div>
  );
}

function KontrolBolumu({
  baslik,
  bolum,
  items,
  photos,
}: {
  baslik: string;
  bolum: string;
  items: ReportChecklistItem[];
  photos: ReportMedia[];
}) {
  const [hepsi, setHepsi] = useState(false);
  if (items.length === 0) return null;
  const eksiklikler = items.filter((i) => i.eksiklik);
  const gorunen = hepsi ? items : eksiklikler;
  return (
    <section className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-lg font-semibold text-metin-birincil">{baslik}</h2>
        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${eksiklikler.length ? "bg-orange-100 text-orange-700" : "bg-green-100 text-green-700"}`}>
          {eksiklikler.length ? `${eksiklikler.length} bulgu` : "Bulgu yok"}
        </span>
      </div>
      {gorunen.length === 0 ? (
        <p className="mt-3 text-sm text-metin-ikincil">Kontrol edilen {items.length} maddede eksiklik bulunmadi.</p>
      ) : (
        <ul className="mt-4 divide-y divide-kenarlik-acik">
          {gorunen.map((item) => {
            const itemPhotos = photos.filter((p) => p.section === bolum && p.item_key === item.key);
            return (
              <li key={item.key} className="py-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-sm font-medium text-metin-birincil">{item.label}</span>
                  <span className={`rounded px-2 py-0.5 text-xs font-semibold ${item.eksiklik ? "bg-red-50 text-red-700" : "bg-gray-100 text-metin-ikincil"}`}>
                    {item.durumEtiket || item.durum || "-"}
                    {item.mikron ? ` • ${item.mikron} μm` : ""}
                  </span>
                </div>
                {item.not && <p className="mt-1 text-sm text-metin-ikincil">{item.not}</p>}
                {itemPhotos.length > 0 && <FotoGaleri photos={itemPhotos} kucuk />}
              </li>
            );
          })}
        </ul>
      )}
      <button
        type="button"
        onClick={() => setHepsi((v) => !v)}
        className="mt-3 text-sm font-semibold text-birincil hover:underline"
      >
        {hepsi ? "Sadece bulgulari goster" : `Tum ${items.length} maddeyi goster`}
      </button>
    </section>
  );
}

function FotoGaleri({ photos, kucuk = false }: { photos: ReportMedia[]; kucuk?: boolean }) {
  return (
    <div className={`mt-3 grid gap-3 ${kucuk ? "grid-cols-3 sm:grid-cols-5" : "grid-cols-2 sm:grid-cols-4"}`}>
      {photos.map((p) => (
        <a key={p.id} href={p.url} target="_blank" rel="noopener noreferrer" className="group block">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={p.url}
            alt={p.item_label || "Ekspertiz fotografi"}
            loading="lazy"
            className="aspect-square w-full rounded-lg object-cover ring-1 ring-kenarlik-acik group-hover:opacity-90"
          />
          {!kucuk && (
            <span className="mt-1 block text-xs text-metin-ikincil">
              {p.item_label || "-"}
              {p.note ? ` – ${p.note}` : ""}
            </span>
          )}
        </a>
      ))}
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
