"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { SIFRE_KURALI, sifreHatasi } from "@/lib/sifre";

export default function KayitOlSayfasi() {
  const [form, setForm] = useState({ ad: "", soyad: "", email: "", telefon: "", password: "" });
  const [onay, setOnay] = useState(false);
  const [yukleniyor, setYukleniyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [kayitEposta, setKayitEposta] = useState<string | null>(null);
  const { register } = useAuth();

  const kaydol = async (e: React.FormEvent) => {
    e.preventDefault();
    setHata(null);
    const kural = sifreHatasi(form.password);
    if (kural) return setHata(kural);
    if (!onay) return setHata("Devam etmek için Kullanım Koşulları ve KVKK Aydınlatma Metni'ni onaylayın.");
    setYukleniyor(true);
    try {
      await register(form.email, form.password, `${form.ad} ${form.soyad}`.trim(), form.telefon || undefined, onay);
      setKayitEposta(form.email);
    } catch (err) {
      setHata(err instanceof Error ? err.message : "Kayıt başarısız");
    } finally {
      setYukleniyor(false);
    }
  };

  if (kayitEposta) {
    return (
      <div className="min-h-[70vh] flex items-center justify-center px-4">
        <div className="w-full max-w-md text-center">
          <h1 className="text-2xl font-bold text-metin-birincil">Hesabınız oluşturuldu</h1>
          <p className="mt-4 text-metin-ikincil">
            <strong>{kayitEposta}</strong> adresine doğrulama bağlantısı gönderdik. E-postanızı doğruladığınızda{" "}
            <span className="font-semibold text-birincil">3 ücretsiz analiz</span> krediniz hesabınıza yüklenir.
          </p>
          <Link href="/panel" className="mt-6 inline-block rounded-lg bg-birincil px-5 py-3 font-medium text-white">Panelime git</Link>
        </div>
      </div>
    );
  }

  const g = (key: string, val: string) => setForm((p) => ({ ...p, [key]: val }));

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-metin-birincil">Üye Ol</h1>
          <p className="text-metin-ikincil mt-1">
            E-postanızı doğrulayın, <span className="text-birincil font-semibold">3 ücretsiz analiz</span> hediye
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
            <input required type="password" value={form.password} onChange={(e) => g("password", e.target.value)} className="w-full px-3 py-2.5 border border-kenarlik-acik rounded-lg text-sm" placeholder="En az 8 karakter" minLength={8} autoComplete="new-password" />
            <p className="mt-1 text-xs text-metin-ikincil">{SIFRE_KURALI}</p>
          </div>
          <label className="flex items-start gap-2 text-sm text-metin-ikincil">
            <input type="checkbox" checked={onay} onChange={(e) => setOnay(e.target.checked)} className="mt-1" />
            <span>
              <Link href="/kullanim-kosullari" target="_blank" className="text-birincil underline">Kullanım Koşulları</Link>&apos;nı okudum ve kabul ediyorum;{" "}
              <Link href="/kvkk" target="_blank" className="text-birincil underline">KVKK Aydınlatma Metni</Link>&apos;ni okudum.
            </span>
          </label>
          {hata && <p className="text-sm text-tehlike">{hata}</p>}
          <button type="submit" disabled={yukleniyor} className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
            {yukleniyor ? "Kayıt Yapılıyor..." : "Kayıt Ol"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-metin-ikincil">
          Hesabınız var mı? <a href="/giris" className="text-birincil font-medium hover:underline">Giriş Yap</a>
        </p>
      </div>
    </div>
  );
}
