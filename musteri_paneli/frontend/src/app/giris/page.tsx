"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/kancalar/yetkiKullan";
import HesapCercevesi from "@/bilesenler/HesapCercevesi";
import Ikon from "@/bilesenler/Ikon";
import { siteIciDonus, uyelikAdresi } from "@/lib/uyelikYonlendirme";

function GirisFormu() {
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [yukleniyor, setYukleniyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const { login } = useAuth();
  const oturumBitti = params.get("oturum") === "bitti";
  const gonder = async (e: React.FormEvent) => {
    e.preventDefault(); setYukleniyor(true); setHata(null);
    try {
      await login(email,password);
      const donus = params.get("donus");
      window.location.href = siteIciDonus(donus);
    } catch(err) { setHata(err instanceof Error ? err.message : "Giriş başarısız"); }
    finally { setYukleniyor(false); }
  };
  return <>
    {oturumBitti && <p role="status" className="yb-form-error">Oturumunuzun süresi doldu, lütfen tekrar giriş yapın.</p>}
    <form onSubmit={gonder} className="yb-form" aria-busy={yukleniyor}>
      <fieldset disabled={yukleniyor}><div className="yb-form-field"><label htmlFor="giris-email">E-posta</label><input id="giris-email" required type="email" autoComplete="email" value={email} onChange={(e)=>setEmail(e.target.value)} placeholder="ornek@eposta.com" /></div><div className="yb-form-field"><label htmlFor="giris-sifre">Şifre</label><input id="giris-sifre" required type="password" autoComplete="current-password" value={password} onChange={(e)=>setPassword(e.target.value)} placeholder="Şifreniz" /></div></fieldset>
      <div className="yb-forgot"><Link href="/sifremi-unuttum">Şifremi unuttum</Link></div>
      {hata && <p role="alert" className="yb-form-error">{hata}</p>}
      <button type="submit" disabled={yukleniyor} className="yb-button yb-button-dark">{yukleniyor ? "Giriş yapılıyor…" : "Giriş yap"}<Ikon ad="ok" /></button>
    </form>
    <p className="yb-account-switch">Henüz hesabınız yok mu? <Link href={uyelikAdresi(siteIciDonus(params.get("donus")))}>Kayıt olun</Link></p>
  </>;
}
export default function GirisSayfasi() {
  return <HesapCercevesi><span className="yb-eyebrow">YERİMEBAK MÜŞTERİ PANELİ</span><h1>Yeniden hoş geldiniz.</h1><p className="yb-account-intro">İnceleme süreciniz ve raporlarınız sizi bekliyor. Hesabınıza giriş yaparak kaldığınız yerden devam edin.</p><Suspense fallback={<p role="status">Giriş formu yükleniyor…</p>}><GirisFormu /></Suspense></HesapCercevesi>;
}
