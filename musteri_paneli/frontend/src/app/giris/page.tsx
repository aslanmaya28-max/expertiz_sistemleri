"use client";

import { useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";

export default function GirisSayfasi() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [yukleniyor, setYukleniyor] = useState(false);
  const { login } = useAuth();

  const gonder = async (e: React.FormEvent) => {
    e.preventDefault();
    setYukleniyor(true);
    try {
      await login(email, password);
      window.location.href = "/panel";
    } catch (err) {
      alert(err instanceof Error ? err.message : "Giris basarisiz");
    } finally {
      setYukleniyor(false);
    }
  };

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-metin-birincil">Giriş Yap</h1>
          <p className="text-metin-ikincil mt-1">E-posta ve şifrenizle giriş yapın</p>
        </div>

        <form onSubmit={gonder} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">E-posta</label>
            <input required type="email" value={email} onChange={(e) => setEmail(e.target.value)} className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" placeholder="ornek@email.com" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Şifre</label>
            <input required type="password" value={password} onChange={(e) => setPassword(e.target.value)} className="w-full px-4 py-3 border border-kenarlik-acik rounded-lg text-sm" placeholder="••••••••" />
          </div>
          <button type="submit" disabled={yukleniyor} className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
            {yukleniyor ? "Giriş Yapılıyor..." : "Giriş Yap"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-metin-ikincil">
          Hesabınız yok mu? <a href="/kayit-ol" className="text-birincil font-medium hover:underline">Üye Ol (3 ücretsiz analiz)</a>
        </p>
      </div>
    </div>
  );
}
