"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import { useAuth, useCredits } from "@/kancalar/yetkiKullan";
import BildirimZili from "./BildirimZili";
import Marka from "./Marka";
import Ikon from "./Ikon";

const links = [
  ["/yerinde-inceleme", "Yerinde inceleme"], ["/arac-degerleme", "Araç değerleme"],
  ["/ornek-rapor", "Örnek rapor"], ["/fiyatlar", "Fiyatlar"], ["/#nasil-calisir", "Nasıl çalışır?"],
];

export default function UstCubuk() {
  const [menuAcik, setMenuAcik] = useState(false);
  const header = useRef<HTMLElement>(null);
  const menuButton = useRef<HTMLButtonElement>(null);
  const { user, loading, logout } = useAuth();
  const credits = useCredits();
  const yol = usePathname();
  // Bulunduğunuz sayfa menüde vurgulanır (çapa bağlantısı hariç).
  const aktif = (href: string) => !href.includes("#") && (yol === href || yol.startsWith(href + "/"));
  const kapat = () => setMenuAcik(false);
  const escape = (event: KeyboardEvent) => {
    if (event.key !== "Escape") return;
    event.preventDefault();
    kapat();
    menuButton.current?.focus();
  };
  useEffect(() => {
    const sync = () => {
      if (header.current) header.current.dataset.floating = String(window.scrollY > 24);
    };
    sync();
    window.addEventListener("scroll", sync, { passive: true });
    return () => window.removeEventListener("scroll", sync);
  }, []);
  return (
    <header className="yb-header" ref={header} onKeyDown={escape}>
      <div className="yb-wrap yb-nav">
        <Link href="/" aria-label="YerimeBak ana sayfa" onClick={kapat}><Marka /></Link>
        <nav className="yb-desktop-nav" aria-label="Ana menü">{links.map(([href,label])=><Link key={href} href={href} aria-current={aktif(href) ? "page" : undefined}>{label}</Link>)}</nav>
        <div className="yb-header-account">{loading ? <span className="yb-nav-loading">Hesabınız yükleniyor…</span> : user ? <><Link href="/panel" className="yb-nav-login yb-nav-panel"><Ikon ad="kisi" />Panelim <span className="yb-credit">{credits} kredi</span></Link>{user.role === "admin" && <a href="https://admin.yerimebak.com.tr" className="yb-nav-login yb-nav-chip"><Ikon ad="anahtar" />Yönetim</a>}<button type="button" className="yb-nav-login yb-nav-exit" onClick={logout}>Çıkış <Ikon ad="ok" /></button></> : <><Link href="/giris" className="yb-nav-login yb-nav-chip"><Ikon ad="kisi" />Müşteri girişi</Link><Link href="/kayit-ol" className="yb-button yb-button-dark yb-button-small">Kayıt ol <Ikon ad="capraz-ok" /></Link></>}</div>
        <div className="yb-nav-tools">{!loading && user ? <BildirimZili /> : null}<button ref={menuButton} type="button" className="yb-menu-toggle" aria-label={menuAcik ? "Menüyü kapat" : "Menüyü aç"} aria-expanded={menuAcik} aria-controls="mobil-menu" onClick={()=>setMenuAcik(!menuAcik)}><span className={menuAcik ? "is-open" : ""} /><span className={menuAcik ? "is-open" : ""} /></button></div>
      </div>
      {menuAcik && <nav id="mobil-menu" className="yb-mobile-nav yb-wrap" aria-label="Mobil menü">{links.map(([href,label])=><Link href={href} key={href} onClick={kapat}>{label}<Ikon ad="capraz-ok" /></Link>)}<div className="yb-mobile-account">{user ? <><Link href="/panel" onClick={kapat}>Panelim ({credits} kredi)</Link><Link href="/profil" onClick={kapat}>Profilim</Link><button type="button" onClick={()=>{logout();kapat();}}>Çıkış</button></> : <><Link href="/giris" onClick={kapat}>Müşteri girişi</Link><Link href="/kayit-ol" className="yb-button yb-button-dark" onClick={kapat}>Kayıt ol <Ikon ad="capraz-ok" /></Link></>}</div></nav>}
    </header>
  );
}
