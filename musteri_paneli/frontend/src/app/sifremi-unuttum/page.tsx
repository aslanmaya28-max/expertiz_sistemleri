"use client";

import Link from "next/link";
import { useState } from "react";
import { requestPasswordReset } from "@/lib/api";

export default function SifremiUnuttumSayfasi() {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [mesaj, setMesaj] = useState<string | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  async function gonder(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setHata(null);
    try {
      await requestPasswordReset(email.trim());
      setMesaj("Bu e-posta adresi kayıtlıysa şifre sıfırlama bağlantısı gönderdik. Gelen kutunuzu (ve istenmeyen klasörünü) kontrol edin. Bağlantı 1 saat geçerlidir.");
    } catch (err) {
      setHata(err instanceof Error ? err.message : "İstek gönderilemedi");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <h1 className="text-2xl font-bold text-metin-birincil text-center">Şifremi Unuttum</h1>
        <p className="mt-1 text-center text-metin-ikincil">Kayıtlı e-posta adresinizi girin, size yeni şifre bağlantısı gönderelim.</p>
        {mesaj ? (
          <div className="mt-8 rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-800">{mesaj}</div>
        ) : (
          <form onSubmit={gonder} className="mt-8 space-y-4">
            <input required type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="ornek@email.com"
              className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" />
            {hata && <p className="text-sm text-tehlike">{hata}</p>}
            <button type="submit" disabled={busy} className="w-full py-3 bg-birincil text-white font-medium rounded-lg disabled:opacity-50">
              {busy ? "Gönderiliyor..." : "Bağlantı Gönder"}
            </button>
          </form>
        )}
        <p className="mt-6 text-center text-sm"><Link href="/giris" className="text-birincil hover:underline">Girişe dön</Link></p>
      </div>
    </div>
  );
}
