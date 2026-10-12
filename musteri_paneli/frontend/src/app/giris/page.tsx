"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/kancalar/yetkiKullan";

function GirisFormu() {
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [yukleniyor, setYukleniyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const { login } = useAuth();
  const oturumBitti = params.get("oturum") === "bitti";

  const gonder = async (e: React.FormEvent) => {
    e.preventDefault();
    setYukleniyor(true);
    setHata(null);
    try {
      await login(email, password);
      // Yalnizca site ici donus adresi (acik yonlendirme olmasin)
      const donus = params.get("donus");
      window.location.href = donus && donus.startsWith("/") && !donus.startsWith("//") ? donus : "/panel";
    } catch (err) {
      setHata(err instanceof Error ? err.message : "Giriş başarısız");
    } finally {
      setYukleniyor(false);
    }
  };

  return (
    <>
      {oturumBitti && (
        <div className="mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-800">
          Oturumunuzun süresi doldu, lütfen tekrar giriş yapın.
        </div>
      )}
      <form onSubmit={gonder} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-metin-birincil mb-1">E-posta</label>
          <input required type="email" value={email} onChange={(e) => setEmail(e.target.value)} className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" placeholder="ornek@email.com" autoComplete="email" />
        </div>
        <div>
          <label className="block text-sm font-medium text-metin-birincil mb-1">Şifre</label>
          <input required type="password" value={password} onChange={(e) => setPassword(e.target.value)} className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" placeholder="••••••••" autoComplete="current-password" />
        </div>
        <div className="text-right -mt-2">
          <Link href="/sifremi-unuttum" className="text-sm text-birincil hover:underline">Şifremi unuttum</Link>
        </div>
        {hata && <p className="text-sm text-tehlike">{hata}</p>}
        <button type="submit" disabled={yukleniyor} className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
          {yukleniyor ? "Giriş Yapılıyor..." : "Giriş Yap"}
        </button>
      </form>
    </>
  );
}

export default function GirisSayfasi() {
  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-metin-birincil">Giriş Yap</h1>
          <p className="text-metin-ikincil mt-1">E-posta ve şifrenizle giriş yapın</p>
        </div>
        <Suspense fallback={null}>
          <GirisFormu />
        </Suspense>
        <p className="mt-6 text-center text-sm text-metin-ikincil">
          Hesabınız yok mu? <Link href="/kayit-ol" className="text-birincil font-medium hover:underline">Üye Ol (3 ücretsiz analiz)</Link>
        </p>
      </div>
    </div>
  );
}
