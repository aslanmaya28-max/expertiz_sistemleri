"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { expertizSealUrl, verifyExpertizReport, type ReportVerification } from "@/lib/api";
import { isVerificationCode, normalizeVerificationCode } from "@/lib/raporDogrulama";

export default function RaporDogrulama({ initialCode = "" }: { initialCode?: string }) {
  const router = useRouter();
  const code = normalizeVerificationCode(initialCode);
  const [input, setInput] = useState(code);
  const [result, setResult] = useState<ReportVerification | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (!code || !isVerificationCode(code)) return;
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setResult(null);
    verifyExpertizReport(code, controller.signal).then(setResult).catch((err) => {
      if (!controller.signal.aborted) setError(err instanceof Error ? err.message : "Doğrulama yapılamadı. Lütfen tekrar deneyin.");
    }).finally(() => {
      if (!controller.signal.aborted) setLoading(false);
    });
    return () => controller.abort();
  }, [code, attempt]);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalized = normalizeVerificationCode(input);
    if (!isVerificationCode(normalized)) {
      setError("Doğrulama kodunu YB-XXXX-XXXX veya YD-XXXX-XXXX biçiminde girin.");
      return;
    }
    setError(null);
    if (normalized === code) setAttempt((value) => value + 1);
    else router.push(`/dogrula/${encodeURIComponent(normalized)}`);
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-12 sm:px-6">
      <h1 className="text-3xl font-bold text-metin-birincil">Rapor doğrula</h1>
      <p className="mt-3 text-metin-ikincil">Raporun üzerindeki doğrulama kodunu girerek YerimeBak kaydını kontrol edin.</p>
      <form onSubmit={submit} className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
        <label htmlFor="verification-code" className="block text-sm font-semibold text-metin-birincil">Doğrulama kodu</label>
        <div className="mt-2 flex flex-wrap gap-3">
          <input id="verification-code" value={input} onChange={(e) => setInput(e.target.value)} required maxLength={32} autoCapitalize="characters" autoComplete="off" spellCheck={false} placeholder="YB-XXXX-XXXX" className="min-w-0 flex-1 rounded-lg border border-kenarlik-acik px-3 py-2 uppercase text-metin-birincil" />
          <button type="submit" disabled={loading} className="rounded-lg bg-birincil px-5 py-2 font-semibold text-white disabled:opacity-50">{loading ? "Kontrol ediliyor…" : "Doğrula"}</button>
        </div>
      </form>
      {(error || (code && !isVerificationCode(code))) && <p role="alert" className="mt-4 rounded-lg bg-red-50 p-4 text-red-700">{error || "Doğrulama kodu YB-XXXX-XXXX veya YD-XXXX-XXXX biçiminde olmalıdır."}</p>}
      {result && <section aria-live="polite" className="mt-6 rounded-lg border border-kenarlik-acik bg-white p-6">
        {result.gecerli ? <>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={expertizSealUrl(code)} width={180} height={180} alt="YerimeBak dijital doğrulama mührü" className="mx-auto" />
          <h2 className="mt-4 text-xl font-semibold text-green-800">Rapor doğrulandı</h2>
          <p className="mt-2 text-sm text-metin-ikincil">{result.tur === "degerleme" ? "Kredili değerleme raporu — uzman incelemesi içermez" : "Ekspertiz raporu"}</p>
          <dl className="mt-4 space-y-3 text-sm">
            {([
              ["Rapor numarası", result.rapor_no],
              ["Tarih", result.tarih],
              ["Araç", [result.marka, result.model, result.yil].filter(Boolean).join(" ")],
              ...(result.tur === "degerleme" ? [] : [["Plaka", result.plaka_maskeli], ["Durum", result.durum === "arsivlendi" ? "Arşivlendi" : "Yayınlandı"]]),
            ] as const).map(([label, value]) => <div key={label} className="flex flex-wrap justify-between gap-3"><dt className="text-metin-ikincil">{label}</dt><dd className="font-semibold text-metin-birincil">{value || "—"}</dd></div>)}
          </dl>
        </> : <><h2 className="text-xl font-semibold text-red-700">Rapor doğrulanamadı</h2><p className="mt-2 text-metin-ikincil">Bu kodla yayınlanmış bir rapor bulunamadı. Kodu kontrol ederek tekrar deneyin.</p></>}
      </section>}
    </div>
  );
}
