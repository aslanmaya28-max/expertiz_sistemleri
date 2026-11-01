"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/kancalar/yetkiKullan";
import { SIFRE_KURALI, sifreHatasi } from "@/lib/sifre";
import HesapCercevesi from "@/bilesenler/HesapCercevesi";
import Ikon from "@/bilesenler/Ikon";
import { siteIciDonus, uyelikAdresi } from "@/lib/uyelikYonlendirme";

function KayitFormu() {
  const params = useSearchParams();
  const devam = siteIciDonus(params.get("donus"));
  const incelemeIcin = devam.split("?")[0] === "/ekspertiz-talebi";
  const [form, setForm] = useState({ ad: "", soyad: "", email: "", telefon: "", password: "" });
  const [onay, setOnay] = useState(false);
  const [yukleniyor, setYukleniyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [kayitEposta, setKayitEposta] = useState<string | null>(null);
  const { register, user } = useAuth();
  const g = (key: keyof typeof form, val: string) => setForm((p) => ({ ...p, [key]: val }));

  const kaydol = async (e: React.FormEvent) => {
    e.preventDefault();
    setHata(null);
    const kural = sifreHatasi(form.password);
    if (kural) return setHata(kural);
    const telefon = form.telefon.trim();
    const rakamlar = telefon.replace(/\D/g, "");
    if (rakamlar.length < 10 || rakamlar.length > 15) return setHata("Geçerli bir telefon numarası girin.");
    if (!onay) return setHata("Devam etmek için Kullanım Koşulları ve KVKK Aydınlatma Metni'ni onaylayın.");
    setYukleniyor(true);
    try {
      await register(form.email.trim(), form.password, `${form.ad} ${form.soyad}`.trim(), telefon, onay);
      setKayitEposta(form.email);
    } catch (err) {
      setHata(err instanceof Error ? err.message : "Kayıt başarısız");
    } finally { setYukleniyor(false); }
  };

  if (kayitEposta) return <HesapCercevesi><div className="yb-success" role="status"><span className="yb-success-icon"><Ikon ad="kontrol" /></span><span className="yb-eyebrow">YERİMEBAK’A HOŞ GELDİNİZ</span><h1>Hesabınız oluşturuldu</h1><p>İnceleme talebiniz, kayıt bilgilerinizle oluşturduğunuz bu hesaba bağlanacak. Talep durumunu ve onaylanan raporları müşteri panelinizden takip edebilirsiniz.</p><p><strong>{kayitEposta}</strong> adresiniz için doğrulama e-postanızı kontrol edin. E-postanızı doğruladığınızda 1 ücretsiz deneme krediniz hesabınıza yüklenir.</p>{incelemeIcin && <Link href={user ? devam : uyelikAdresi(devam,"giris")} className="yb-button yb-button-dark">{user ? "İnceleme talebi oluştur" : "Giriş yaparak devam et"} <Ikon ad="ok" /></Link>}<Link href={user ? "/panel" : uyelikAdresi("/panel","giris")} className={incelemeIcin ? "yb-text-link" : "yb-button yb-button-dark"}>Panelime git <Ikon ad="ok" /></Link></div></HesapCercevesi>;

  return <HesapCercevesi>
    <span className="yb-eyebrow">BİLİNÇLİ BİR KARARIN İLK ADIMI</span><h1>{incelemeIcin ? "Önce hesabınızı oluşturun." : "Kayıt olun."}</h1><p className="yb-account-intro">E-posta ve telefon bilgilerinizle kaydolun. {incelemeIcin ? "Kaydınızı tamamladıktan sonra inceleme talebinize devam edebilirsiniz. Talebiniz ve raporlarınız bu hesaba bağlı olacak." : "Ardından inceleme talebinizi iletin, sürecinizi ve onaylanan raporlarınızı kendi panelinizden takip edin."}</p>
    <form onSubmit={kaydol} className="yb-form" aria-busy={yukleniyor}>
      <fieldset disabled={yukleniyor}>
        <div className="yb-form-row"><div><label htmlFor="kayit-ad">Ad</label><input id="kayit-ad" required autoComplete="given-name" value={form.ad} onChange={(e)=>g("ad",e.target.value)} placeholder="Adınız" /></div><div><label htmlFor="kayit-soyad">Soyad</label><input id="kayit-soyad" required autoComplete="family-name" value={form.soyad} onChange={(e)=>g("soyad",e.target.value)} placeholder="Soyadınız" /></div></div>
        <div className="yb-form-field"><label htmlFor="kayit-email">E-posta</label><input id="kayit-email" type="email" required autoComplete="email" value={form.email} onChange={(e)=>g("email",e.target.value)} placeholder="ornek@eposta.com" /></div>
        <div className="yb-form-field"><label htmlFor="kayit-telefon">Telefon</label><input id="kayit-telefon" type="tel" required inputMode="tel" autoComplete="tel" pattern={String.raw`[+0-9 \(\)\-]{10,25}`} title="Telefon numaranızı alan koduyla birlikte girin. Örnek: 0555 000 00 00" value={form.telefon} onChange={(e)=>g("telefon",e.target.value)} placeholder="05XX XXX XX XX" /></div>
        <div className="yb-form-field"><label htmlFor="kayit-sifre">Şifre</label><input id="kayit-sifre" type="password" required autoComplete="new-password" minLength={8} value={form.password} onChange={(e)=>g("password",e.target.value)} placeholder="Şifrenizi belirleyin" aria-describedby="sifre-kurali" /><p id="sifre-kurali" className="yb-form-hint">{SIFRE_KURALI}</p></div>
        <label className="yb-consent"><input type="checkbox" required checked={onay} onChange={(e)=>setOnay(e.target.checked)} /><span><Link href="/kullanim-kosullari" target="_blank">Kullanım Koşulları</Link>&apos;nı okudum ve kabul ediyorum; <Link href="/kvkk" target="_blank">KVKK Aydınlatma Metni</Link>&apos;ni okudum.</span></label>
      </fieldset>
      {hata && <p role="alert" className="yb-form-error">{hata}</p>}
      <button type="submit" disabled={yukleniyor} className="yb-button yb-button-dark">{yukleniyor ? "Hesabınız oluşturuluyor…" : "Kayıt ol"}<Ikon ad="capraz-ok" /></button>
    </form>
    <p className="yb-account-switch">Zaten hesabınız var mı? <Link href={uyelikAdresi(devam,"giris")}>Giriş yapın</Link></p>
  </HesapCercevesi>;
}

export default function KayitOlSayfasi() {
  return <Suspense fallback={<p role="status" className="yb-wrap py-12">Kayıt ekranı yükleniyor…</p>}><KayitFormu /></Suspense>;
}
