"use client";

import Link from "next/link";
import HesapCercevesi from "@/bilesenler/HesapCercevesi";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { resetPassword } from "@/lib/api";
import { SIFRE_KURALI, sifreHatasi } from "@/lib/sifre";

function SifreSifirlaIcerigi() {
  const token = useSearchParams().get("token") || "";
  const [sifre, setSifre] = useState("");
  const [tekrar, setTekrar] = useState("");
  const [busy, setBusy] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [tamam, setTamam] = useState(false);

  async function gonder(e: React.FormEvent) {
    e.preventDefault();
    const kural = sifreHatasi(sifre);
    if (kural) return setHata(kural);
    if (sifre !== tekrar) return setHata("Şifreler eşleşmiyor");
    setBusy(true);
    setHata(null);
    try {
      await resetPassword(token, sifre);
      setTamam(true);
    } catch (err) {
      setHata(err instanceof Error ? err.message : "Şifre değiştirilemedi");
    } finally {
      setBusy(false);
    }
  }

  if (!token) {
    return <p className="text-center text-tehlike">Bağlantı eksik. E-postadaki bağlantıyı tekrar açın veya <Link href="/sifremi-unuttum" className="underline">yeni bağlantı isteyin</Link>.</p>;
  }
  if (tamam) {
    return (
      <div className="rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-800">
        Şifreniz değiştirildi. <Link href="/giris" className="font-semibold underline">Yeni şifrenizle giriş yapın</Link>.
      </div>
    );
  }
  return (
    <form onSubmit={gonder} className="yb-form space-y-4">
      <input required type="password" value={sifre} onChange={(e) => setSifre(e.target.value)} placeholder="Yeni şifre"
        className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" autoComplete="new-password" />
      <input required type="password" value={tekrar} onChange={(e) => setTekrar(e.target.value)} placeholder="Yeni şifre (tekrar)"
        className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" autoComplete="new-password" />
      <p className="text-xs text-metin-ikincil">{SIFRE_KURALI}</p>
      {hata && <p className="text-sm text-tehlike">{hata}</p>}
      <button type="submit" disabled={busy} className="yb-btn yb-btn-green w-full disabled:opacity-50">
        {busy ? "Kaydediliyor..." : "Şifremi Değiştir"}
      </button>
    </form>
  );
}

export default function SifreSifirlaSayfasi() {
  return (
    <HesapCercevesi>
      <div className="yb-account-recovery">
        <h1 className="mb-8 text-2xl font-bold text-metin-birincil text-center">Yeni Şifre Belirle</h1>
        <Suspense fallback={null}><SifreSifirlaIcerigi /></Suspense>
      </div>
    </HesapCercevesi>
  );
}
