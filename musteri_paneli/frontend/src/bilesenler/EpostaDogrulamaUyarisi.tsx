"use client";

import { useState } from "react";
import { resendVerification } from "@/lib/api";

/** E-postasi dogrulanmamis musteriye panelde gosterilir. */
export default function EpostaDogrulamaUyarisi({ email }: { email: string }) {
  const [mesaj, setMesaj] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function tekrarGonder() {
    setBusy(true);
    try {
      const res = await resendVerification();
      setMesaj(res.already_verified ? "E-posta adresiniz zaten doğrulanmış." : "Doğrulama e-postası tekrar gönderildi.");
    } catch (err) {
      setMesaj(err instanceof Error ? err.message : "Gönderilemedi");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-6 flex flex-col gap-3 rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-sm text-yellow-900 sm:flex-row sm:items-center sm:justify-between">
      <span>
        <strong>{email}</strong> adresini henüz doğrulamadınız. E-postanızdaki bağlantıya tıkladığınızda 3 ücretsiz analiz krediniz yüklenir.
        {mesaj ? <span className="block mt-1 font-medium">{mesaj}</span> : null}
      </span>
      <button type="button" onClick={tekrarGonder} disabled={busy}
        className="whitespace-nowrap rounded-lg border border-yellow-400 px-3 py-2 font-semibold disabled:opacity-50">
        {busy ? "Gönderiliyor..." : "Tekrar gönder"}
      </button>
    </div>
  );
}
