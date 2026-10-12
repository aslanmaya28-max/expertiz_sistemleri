"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  getMyExpertizReport,
  type CustomerAiAnalysis,
  type ExpertizReportDetailResponse,
  type InspectionValuation,
  type ReportChecklistItem,
  type ReportMedia,
} from "@/lib/api";
import { useAuth } from "@/kancalar/yetkiKullan";

function formatPrice(value?: number | null): string {
  if (!value) return "-";
  return new Intl.NumberFormat("tr-TR").format(Math.round(value)) + " TL";
}

function formatPct(value?: number | null, signed = false): string {
  if (typeof value !== "number" || Number.isNaN(value)) return "-";
  const text = Math.abs(value).toLocaleString("tr-TR", { maximumFractionDigits: 1, minimumFractionDigits: 1 });
  const sign = value < 0 ? "−" : signed && value > 0 ? "+" : "";
  return `${sign}%${text}`;
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
          <Info label="Yapay zeka degeri" value={formatPrice(report.summary?.market_value)} />
        </div>

        {report.admin_note && (
          <div className="mt-6 rounded-lg border border-blue-200 bg-blue-50 p-4">
            <div className="text-sm font-semibold text-blue-800">Uzman notu</div>
            <p className="mt-1 whitespace-pre-line text-sm leading-6 text-blue-900">{report.admin_note}</p>
          </div>
        )}

        <AracOzeti tamRapor={tamRapor} vehicle={report.vehicle} />
      </div>

      {report.ai && <AiDegerleme ai={report.ai} />}

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

const KARAR_STIL: Record<string, string> = {
  AVANTAJLI: "bg-green-100 text-green-800",
  MAKUL: "bg-emerald-50 text-emerald-700",
  PAZARLIK: "bg-orange-100 text-orange-800",
  YUKSEK: "bg-red-100 text-red-700",
};

const KARAR_ETIKET: Record<string, string> = {
  AVANTAJLI: "Fiyat avantajli",
  MAKUL: "Fiyat uygun",
  PAZARLIK: "Pazarlik onerilir",
  YUKSEK: "Fiyat yuksek",
};

/** Yapay zeka degerlemesi: piyasa degeri − ekspertiz bulgularinin deger kaybi = AI fiyati */
function AiDegerleme({ ai }: { ai: CustomerAiAnalysis }) {
  const d: InspectionValuation | undefined = ai.ekspertizDegerleme;
  const ozet = ai.raporOzeti;
  const skor = ai.skorlar;
  const yorum = d?.fiyatYorumu;
  const kritik = ai.kritikSorunlar ?? [];
  const oneriler = (ai.oneriler ?? []).slice(0, 6);
  const ref = ai.piyasaReferansi;

  return (
    <section className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-metin-birincil">Yapay zeka degerlemesi</h2>
          <p className="mt-1 text-sm text-metin-ikincil">
            Guncel piyasa fiyatindan, ekspertizde tespit edilen her bulgunun deger kaybi dusulerek hesaplandi.
          </p>
        </div>
        {d?.agirHasar && (
          <span className="rounded-full bg-red-100 px-3 py-1 text-xs font-semibold text-red-700">Agir hasar bulgusu</span>
        )}
      </div>

      {d?.degerlemeYapildi && d.aiDegeri ? (
        <div className="mt-5 grid gap-4 sm:grid-cols-3">
          <div className="rounded-lg bg-birincil/5 p-4 ring-1 ring-birincil/20 sm:col-span-1">
            <div className="text-xs text-metin-ikincil">Aracin degeri</div>
            <div className="mt-1 text-2xl font-bold text-birincil">{formatPrice(d.aiDegeri)}</div>
            {d.adilFiyatAraligi && (
              <div className="mt-1 text-xs text-metin-ikincil">
                Adil aralik: {formatPrice(d.adilFiyatAraligi.min)} – {formatPrice(d.adilFiyatAraligi.max)}
              </div>
            )}
          </div>
          <div className="rounded-lg border border-kenarlik-acik p-4">
            <div className="text-xs text-metin-ikincil">Hasarsiz piyasa degeri</div>
            <div className="mt-1 text-lg font-semibold text-metin-birincil">{formatPrice(d.temizPiyasaDegeri)}</div>
            <div className="mt-1 text-xs text-red-600">
              Deger kaybi: {formatPct(d.toplamDegerKaybiYuzde)} ({formatPrice(d.toplamDegerKaybiTutar)})
            </div>
          </div>
          <div className="rounded-lg border border-kenarlik-acik p-4">
            <div className="text-xs text-metin-ikincil">Onerilen alim fiyati</div>
            <div className="mt-1 text-lg font-semibold text-metin-birincil">{formatPrice(d.onerilenAlimFiyati)}</div>
            {yorum && (
              <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
                <span className={`rounded-full px-2 py-0.5 font-semibold ${KARAR_STIL[yorum.karar] ?? "bg-gray-100 text-metin-ikincil"}`}>
                  {KARAR_ETIKET[yorum.karar] ?? yorum.karar}
                </span>
                <span className="text-metin-ikincil">
                  Ilan {formatPrice(d.ilanFiyati)} ({formatPct(yorum.farkYuzde, true)})
                </span>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="mt-5 rounded-lg border border-orange-200 bg-orange-50 px-4 py-3 text-sm text-orange-800">
          Bu arac icin yeterli guncel piyasa verisi bulunamadigindan TL degeri hesaplanamadi.
          {d && ` Ekspertiz bulgularinin toplam deger kaybi etkisi ${formatPct(d.toplamDegerKaybiYuzde)}.`}
        </div>
      )}

      {d && (
        <div className="mt-6">
          <h3 className="text-sm font-semibold text-metin-birincil">Deger kaybi dokumu</h3>
          <div className="mt-2 overflow-x-auto">
            <table className="w-full min-w-[420px] text-sm">
              <tbody className="divide-y divide-kenarlik-acik">
                {d.degerlemeYapildi && (
                  <tr>
                    <td className="py-2 text-metin-ikincil">
                      Piyasa degeri
                      {d.piyasaYontemi && <span className="block text-xs">{d.piyasaYontemi}</span>}
                    </td>
                    <td className="py-2 text-right font-medium text-metin-birincil">{formatPrice(d.piyasaDegeri)}</td>
                  </tr>
                )}
                {d.degerlemeYapildi &&
                  (d.piyasaDuzeltmeleri ?? []).map((a) => (
                    <tr key={a.baslik}>
                      <td className="py-2 text-metin-ikincil">
                        {a.baslik} ({formatPct(a.yuzde, true)})
                        {a.aciklama && <span className="block text-xs">{a.aciklama}</span>}
                      </td>
                      <td className="py-2 text-right text-metin-birincil">
                        {a.tutar >= 0 ? "+" : "−"}
                        {formatPrice(Math.abs(a.tutar))}
                      </td>
                    </tr>
                  ))}
                {d.kalemler.length === 0 && (
                  <tr>
                    <td className="py-2 text-green-700" colSpan={2}>Deger kaybettiren bulgu tespit edilmedi.</td>
                  </tr>
                )}
                {d.kalemler.map((k) => (
                  <tr key={`${k.kategori}-${k.anahtar}`}>
                    <td className="py-2">
                      <span className="font-medium text-metin-birincil">{k.baslik}</span>
                      <span className="ml-2 rounded bg-orange-50 px-1.5 py-0.5 text-xs font-semibold text-orange-700">{k.durum}</span>
                      {k.aciklama && <span className="block text-xs text-metin-ikincil">{k.aciklama}</span>}
                    </td>
                    <td className="whitespace-nowrap py-2 text-right text-red-600">
                      {d.degerlemeYapildi ? `−${formatPrice(k.tutar)}` : ""} <span className="text-xs">({formatPct(-k.yuzde)})</span>
                    </td>
                  </tr>
                ))}
                {d.degerlemeYapildi && (
                  <tr className="font-semibold">
                    <td className="py-2 text-metin-birincil">Yapay zeka degeri</td>
                    <td className="py-2 text-right text-birincil">{formatPrice(d.aiDegeri)}</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {skor && (
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          <Skor label="Genel puan" value={skor.genelPuan} />
          <Skor label="Kaporta / hasar" value={skor.hasarPuan} />
          <Skor label="Motor / mekanik" value={skor.motorMekanikPuan} />
          <Skor label="Ic-dis kondisyon" value={skor.aracDurumuPuan} />
        </div>
      )}

      {(ozet?.onayRedOnerisi || ozet?.ozetAciklama) && (
        <div className="mt-6 rounded-lg bg-gray-50 p-4">
          {ozet?.onayRedOnerisi && <div className="text-sm font-semibold text-metin-birincil">{ozet.onayRedOnerisi}</div>}
          {ozet?.ozetAciklama && <p className="mt-2 text-sm leading-6 text-metin-ikincil">{ozet.ozetAciklama}</p>}
        </div>
      )}

      {kritik.length > 0 && (
        <div className="mt-4 rounded-lg border border-red-200 bg-red-50 p-4">
          <div className="text-sm font-semibold text-red-800">Dikkat edilmesi gerekenler</div>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-red-800">
            {kritik.map((k) => (
              <li key={k}>{k}</li>
            ))}
          </ul>
        </div>
      )}

      {oneriler.length > 0 && (
        <div className="mt-4">
          <h3 className="text-sm font-semibold text-metin-birincil">Oneriler</h3>
          <ul className="mt-2 space-y-2">
            {oneriler.map((o) => (
              <li key={o.baslik} className="rounded-lg border border-kenarlik-acik p-3 text-sm">
                <div className="font-medium text-metin-birincil">{o.baslik}</div>
                {o.aciklama && <div className="mt-0.5 text-metin-ikincil">{o.aciklama}</div>}
                {o.onerilenEylem && <div className="mt-0.5 text-xs text-birincil">→ {o.onerilenEylem}</div>}
              </li>
            ))}
          </ul>
        </div>
      )}

      {ref?.bulundu && ref.emsalSayisi > 0 && (
        <details className="mt-4 rounded-lg border border-kenarlik-acik p-4 text-sm">
          <summary className="cursor-pointer font-semibold text-metin-birincil">
            Piyasa karsilastirmasi ({ref.emsalSayisi} emsal ilan, {ref.hasarsizEmsalSayisi} hasarsiz)
          </summary>
          <p className="mt-2 text-metin-ikincil">
            Emsal fiyat araligi {formatPrice(ref.min)} – {formatPrice(ref.max)}, medyan {formatPrice(ref.medyan)}
            {ref.guncelGun ? ` (son ${ref.guncelGun} gun oncelikli)` : ""}.
          </p>
          <ul className="mt-2 divide-y divide-kenarlik-acik">
            {ref.emsaller.map((e, i) => (
              <li key={i} className="flex justify-between gap-3 py-1.5">
                <span className="text-metin-ikincil">
                  {e.title || "Emsal ilan"} {e.year ? `• ${e.year}` : ""} {e.km ? `• ${new Intl.NumberFormat("tr-TR").format(e.km)} km` : ""}
                  {e.condition === "clean" ? " • hasarsiz" : ""}
                </span>
                <span className="whitespace-nowrap font-medium text-metin-birincil">{formatPrice(e.price)}</span>
              </li>
            ))}
          </ul>
        </details>
      )}

      <p className="mt-4 text-xs text-metin-ikincil">
        Bu degerleme emsal ilanlar ve ekspertiz bulgularina dayanan bir tahmindir; kesin satis fiyati veya teklif degildir.
      </p>
    </section>
  );
}

function Skor({ label, value }: { label: string; value?: number }) {
  const v = typeof value === "number" ? Math.max(0, Math.min(100, value)) : 0;
  const renk = v >= 80 ? "bg-green-500" : v >= 60 ? "bg-orange-400" : "bg-red-500";
  return (
    <div>
      <div className="flex justify-between text-xs">
        <span className="text-metin-ikincil">{label}</span>
        <span className="font-semibold text-metin-birincil">{typeof value === "number" ? v.toFixed(0) : "-"} / 100</span>
      </div>
      <div className="mt-1 h-2 rounded-full bg-gray-100">
        <div className={`h-2 rounded-full ${renk}`} style={{ width: `${v}%` }} />
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
