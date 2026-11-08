"use client";

import { useEffect, useRef, useState } from "react";
import { uploadInspectionPhoto, type InspectionPhotoResult } from "@/lib/api";
import { raporFotografiHatasi } from "@/lib/ekspertizFotografi";

export default function EkspertizFotografi({ disabled, onBusy, onApply, onReset, labels }: {
  disabled: boolean;
  onBusy: (value: boolean) => void;
  onApply: (result: InspectionPhotoResult) => void;
  onReset: () => void;
  labels: Record<string, string>;
}) {
  const [files, setFiles] = useState<File[]>([]);
  const [result, setResult] = useState<InspectionPhotoResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [consent, setConsent] = useState(false);
  const [reading, setReading] = useState(false);
  const alive = useRef(true);
  const inFlight = useRef(false);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  async function read() {
    if (inFlight.current) return;
    const invalid = raporFotografiHatasi(files);
    if (invalid) { setError(invalid); return; }
    inFlight.current = true;
    setReading(true); onBusy(true); setError(null); setResult(null); setConsent(false);
    try {
      const response = await uploadInspectionPhoto(files);
      if (alive.current) setResult(response);
    } catch (err) {
      if (alive.current) setError(err instanceof Error ? err.message : "Fotoğraflar okunamadı.");
    } finally {
      inFlight.current = false;
      if (alive.current) { setReading(false); onBusy(false); }
    }
  }
  return <section className="rounded-xl border border-kenarlik-acik bg-white p-6" aria-label="Ekspertiz raporu fotoğrafı">
    <h2 className="text-lg font-semibold text-metin-birincil">Ekspertiz raporunuz var mı? Fotoğrafını yükleyin</h2>
    <p className="mt-2 text-sm text-metin-ikincil">1–4 JPEG, PNG, WEBP veya HEIC; her biri en fazla 8 MB. Plaka, ad, telefon ve imzayı yüklemeden önce kapatın. Görüntüler kalıcı kaydedilmez; okuma için yapay zekâ hizmetine iletilir.</p>
    <label className="mt-3 block text-sm font-medium">Rapor fotoğrafları
      <input type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif,.webp,.heic,.heif" multiple disabled={disabled || reading}
        className="mt-2 block w-full text-sm" onChange={(event) => {
          const next = Array.from(event.target.files || []);
          setFiles(next); setResult(null); setConsent(false); setError(raporFotografiHatasi(next)); onReset();
        }} />
    </label>
    <button type="button" disabled={disabled || reading || !files.length} onClick={read}
      className="mt-3 rounded-lg border border-birincil px-4 py-2 text-sm font-semibold text-birincil disabled:opacity-50">
      {reading ? "Fotoğraflar okunuyor…" : "Rapordaki bilgileri oku"}
    </button>
    {error && <p role="alert" className="mt-3 text-sm text-tehlike">{error}</p>}
    {result && <div className="mt-4 space-y-3 text-sm" aria-live="polite">
      <p>{result.message}</p>
      {result.firma_adi && <p>Firma: {result.firma_adi}{result.rapor_tarihi ? ` · ${result.rapor_tarihi}` : ""}</p>}
      <ul className="list-disc pl-5">{Object.entries(result.parts).map(([key, status]) => <li key={key}>{labels[key] || key}: {({ orijinal: "Orijinal", boyali: "Boyalı", lokal_boyali: "Lokal boyalı", degisen: "Değişen" })[status]}</li>)}</ul>
      <p>Tramer: {result.tramer_amount == null ? "Okunamadı / belirtilmedi" : `${result.tramer_amount.toLocaleString("tr-TR")} TL`}; kayıt adedi: {result.tramer_count ?? "belirtilmedi"}</p>
      {result.bulgular.some((item) => item.ciddiyet === "ciddi") && <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-tehlike" role="alert">
        <strong>Satın almadan önce yerinde doğrulatın</strong>
        <ul className="mt-1 list-disc pl-5">{result.bulgular.filter((item) => item.ciddiyet === "ciddi").map((item, index) => <li key={index}>{item.metin}</li>)}</ul>
      </div>}
      <ul className="list-disc pl-5">{result.bulgular.filter((item) => item.ciddiyet !== "ciddi").map((item, index) => <li key={index}>{item.metin} ({item.ciddiyet === "pazarlik" ? "kozmetik / küçük onarım" : "bilgi"})</li>)}</ul>
      {result.okunamayan_alanlar.length > 0 && <p>Okunamayan veya belirtilmeyen alanlar: {result.okunamayan_alanlar.map((key) => labels[key] || key).join(", ")}. Eksik parçalar orijinal sayılmaz.</p>}
      {result.found && <>
        <label className="flex items-start gap-2"><input type="checkbox" checked={consent} onChange={(event) => setConsent(event.target.checked)} />
          <span>Okunan bilgileri raporla karşılaştırdım. Forma aktaracağım; eksik veya hatalı alanları düzelteceğim.</span></label>
        <button type="button" disabled={!consent || disabled} onClick={() => { onApply(result); setResult(null); setFiles([]); }}
          className="rounded-lg bg-birincil px-4 py-2 font-semibold text-white disabled:opacity-50">Onayla ve forma aktar</button>
      </>}
    </div>}
  </section>;
}
