"use client";

import { useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";

export default function KayitOlSayfasi() {
  const [form, setForm] = useState({ ad: "", soyad: "", email: "", telefon: "", password: "" });
  const [yukleniyor, setYukleniyor] = useState(false);
  const { register } = useAuth();

  const kaydol = async (e: React.FormEvent) => {
    e.preventDefault();
    setYukleniyor(true);
    try {
      await register(form.email, form.password, `${form.ad} ${form.soyad}`, form.telefon);
      window.location.href = "/panel";
    } catch (err) {
      alert(err instanceof Error ? err.message : "Kayit basarisiz");
    } finally {
      setYukleniyor(false);
    }
  };

  const g = (key: string, val: string) => setForm((p) => ({ ...p, [key]: val }));

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-metin-birincil">Üye Ol</h1>
          <p className="text-metin-ikincil mt-1">
            <span className="text-birincil font-semibold">3 ücretsiz analiz</span> hediye ile başlayın
          </p>
        </div>

        <form onSubmit={kaydol} className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-medium text-metin-birincil mb-1">Ad</label>
              <input required value={form.ad} onChange={(e) => g("ad", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-metin-birincil mb-1">Soyad</label>
              <input required value={form.soyad} onChange={(e) => g("soyad", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">E-posta</label>
            <input required type="email" value={form.email} onChange={(e) => g("email", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Telefon</label>
            <input value={form.telefon} onChange={(e) => g("telefon", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" placeholder="05XX XXX XX XX" />
          </div>
          <div>
            <label className="block text-sm font-medium text-metin-birincil mb-1">Şifre</label>
            <input required type="password" value={form.password} onChange={(e) => g("password", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" placeholder="En az 6 karakter" minLength={6} />
          </div>
          <button type="submit" disabled={yukleniyor} className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
            {yukleniyor ? "Kayıt Yapılıyor..." : "Kayıt Ol — 3 Ücretsiz Analiz Kazan"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-metin-ikincil">
          Hesabınız var mı? <a href="/giris" className="text-birincil font-medium hover:underline">Giriş Yap</a>
        </p>
      </div>
    </div>
  );
}
