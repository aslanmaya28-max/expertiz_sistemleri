"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth, useCredits } from "@/kancalar/yetkiKullan";
import BildirimZili from "./BildirimZili";
import Marka from "./Marka";
import Ikon from "./Ikon";

const links = [
  ["/#hizmetimiz", "Hizmetimiz"], ["/#nasil-calisir", "Nasıl çalışır?"],
  ["/#raporlar", "Raporlarımız"], ["/#hakkimizda", "Hakkımızda"],
];

export default function UstCubuk() {
  const [menuAcik, setMenuAcik] = useState(false);
  const { user, loading, logout } = useAuth();
  const credits = useCredits();
  const kapat = () => setMenuAcik(false);
  return (
    <header className="yb-header">
      <div className="yb-wrap yb-nav">
        <Link href="/" aria-label="YerimeBak ana sayfa" onClick={kapat}><Marka /></Link>
        <nav className="yb-desktop-nav" aria-label="Ana menü">{links.map(([href,label])=><Link key={href} href={href}>{label}</Link>)}</nav>
        <div className="yb-header-account">{loading ? <span className="yb-nav-loading">Hesabınız yükleniyor…</span> : user ? <><Link href="/panel" className="yb-nav-login">Panelim <span className="yb-credit">{credits} kredi</span></Link>{user.role === "admin" && <a href="https://admin.yerimebak.com.tr" className="yb-nav-login">Yönetim</a>}<button type="button" className="yb-nav-login" onClick={logout}>Çıkış</button></> : <><Link href="/giris" className="yb-nav-login">Müşteri girişi</Link><Link href="/kayit-ol" className="yb-button yb-button-dark yb-button-small">Kayıt ol <Ikon ad="capraz-ok" /></Link></>}</div>
        <div className="yb-nav-tools">{!loading && user ? <BildirimZili /> : null}<button type="button" className="yb-menu-toggle" aria-label={menuAcik ? "Menüyü kapat" : "Menüyü aç"} aria-expanded={menuAcik} aria-controls="mobil-menu" onClick={()=>setMenuAcik(!menuAcik)} onKeyDown={(e)=>{if(e.key === "Escape")kapat();}}><span className={menuAcik ? "is-open" : ""} /><span className={menuAcik ? "is-open" : ""} /></button></div>
      </div>
      {menuAcik && <nav id="mobil-menu" className="yb-mobile-nav yb-wrap" aria-label="Mobil menü" onKeyDown={(e)=>{if(e.key === "Escape")kapat();}}>{links.map(([href,label])=><Link href={href} key={href} onClick={kapat}>{label}<Ikon ad="capraz-ok" /></Link>)}<div className="yb-mobile-account">{user ? <><Link href="/panel" onClick={kapat}>Panelim ({credits} kredi)</Link><Link href="/profil" onClick={kapat}>Profilim</Link><button type="button" onClick={()=>{logout();kapat();}}>Çıkış</button></> : <><Link href="/giris" onClick={kapat}>Müşteri girişi</Link><Link href="/kayit-ol" className="yb-button yb-button-dark" onClick={kapat}>Kayıt ol <Ikon ad="ok" /></Link></>}</div></nav>}
    </header>
  );
}
