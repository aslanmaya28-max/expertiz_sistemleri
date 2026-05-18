"use client";

import { useState } from "react";
import type { FormEvent } from "react";
import { createUrlAnalysis } from "@/lib/api";

export default function AracAnalizSayfasi() {
  const [url, setUrl] = useState("");
  const [mesaj, setMesaj] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [yukleniyor, setYukleniyor] = useState(false);

  async function gonder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setYukleniyor(true);
    setMesaj(null);

    try {
      await createUrlAnalysis({ url, source: "manual_paste" });
      setMesaj({ type: "success", text: "Ilan linki alindi. Analiz kuyruga eklendi." });
      setUrl("");
    } catch (err) {
      setMesaj({ type: "error", text: err instanceof Error ? err.message : "Link gonderilemedi." });
    } finally {
      setYukleniyor(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="mb-2 text-3xl font-bold text-metin-birincil">Arac Analiz</h1>
      <p className="mb-8 text-metin-ikincil">Ilan linkini yapistirin, analiz isteginizi kuyruga ekleyelim.</p>

      <form onSubmit={gonder} className="space-y-4 rounded-xl border border-kenarlik-acik bg-white p-6">
        <div>
          <label className="mb-1 block text-sm font-medium text-metin-birincil">Ilan Linki</label>
          <input
            required
            type="url"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            className="w-full rounded-lg border border-kenarlik-acik px-3 py-2 text-sm"
            placeholder="https://..."
          />
        </div>
        <button
          type="submit"
          disabled={yukleniyor}
          className="w-full rounded-lg bg-birincil py-3 font-medium text-white transition-colors hover:bg-birincil-koyu disabled:opacity-50"
        >
          {yukleniyor ? "Gonderiliyor..." : "Analize Gonder"}
        </button>
      </form>

      {mesaj && (
        <div
          className={`mt-4 rounded-lg border px-4 py-3 text-sm ${
            mesaj.type === "success"
              ? "border-green-200 bg-green-50 text-green-700"
              : "border-red-200 bg-red-50 text-red-700"
          }`}
        >
          {mesaj.text}
        </div>
      )}
    </div>
  );
}
