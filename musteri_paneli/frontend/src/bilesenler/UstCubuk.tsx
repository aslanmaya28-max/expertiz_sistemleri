"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";

export default function UstCubuk() {
  const [menuAcik, setMenuAcik] = useState(false);
  const { user, loading, logout } = useAuth();

  return (
    <header className="sticky top-0 z-50 bg-white/95 backdrop-blur border-b border-kenarlik-acik">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 bg-birincil rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-sm">Y</span>
            </div>
            <span className="text-lg font-bold text-metin-birincil">yerimebak<span className="text-birincil">.ai</span></span>
          </Link>

          <nav className="hidden md:flex items-center gap-8">
            <Link href="/vitrin" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Vitrin</Link>
            <Link href="/arac-analiz" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Araç Analiz</Link>
            <Link href="/ornek-rapor" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Örnek Rapor</Link>
            <Link href="/fiyatlar" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Fiyatlar</Link>
          </nav>

          <div className="hidden md:flex items-center gap-3">
            {loading ? null : user ? (
              <>
                <span className="text-xs px-2.5 py-1 bg-birincil/10 text-birincil rounded-full font-medium">{user.credits} kredi</span>
                <Link href="/panel" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Panelim</Link>
                <Link href="/profil" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Profilim</Link>
                {user.role === "admin" && (
                  <Link href="/yonetim" className="text-sm font-medium px-3 py-1.5 bg-metin-birincil text-white rounded-lg hover:opacity-90">Yönetim</Link>
                )}
                <button onClick={logout} className="text-sm font-medium text-metin-ikincil hover:text-tehlike transition-colors">Çıkış</button>
              </>
            ) : (
              <>
                <Link href="/giris" className="text-sm font-medium text-metin-ikincil hover:text-birincil transition-colors">Giriş</Link>
                <Link href="/kayit-ol" className="text-sm font-medium px-4 py-2 bg-birincil text-white rounded-lg hover:bg-birincil-koyu transition-colors">Üye Ol</Link>
              </>
            )}
          </div>

          <button onClick={() => setMenuAcik(!menuAcik)} className="md:hidden p-2 text-metin-ikincil">
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              {menuAcik
                ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              }
            </svg>
          </button>
        </div>

        {menuAcik && (
          <div className="md:hidden border-t border-kenarlik-acik py-4 space-y-3">
            <Link href="/vitrin" className="block text-sm font-medium text-metin-ikincil hover:text-birincil" onClick={() => setMenuAcik(false)}>Vitrin</Link>
            <Link href="/arac-analiz" className="block text-sm font-medium text-metin-ikincil hover:text-birincil" onClick={() => setMenuAcik(false)}>Araç Analiz</Link>
            <Link href="/ornek-rapor" className="block text-sm font-medium text-metin-ikincil hover:text-birincil" onClick={() => setMenuAcik(false)}>Örnek Rapor</Link>
            <Link href="/fiyatlar" className="block text-sm font-medium text-metin-ikincil hover:text-birincil" onClick={() => setMenuAcik(false)}>Fiyatlar</Link>
            <div className="pt-3 border-t border-kenarlik-acik flex gap-3">
              {user ? (
                <>
                  <Link href="/profil" className="text-sm font-medium text-metin-ikincil" onClick={() => setMenuAcik(false)}>Profilim ({user.credits} kredi)</Link>
                  <Link href="/panel" className="text-sm font-medium text-metin-ikincil" onClick={() => setMenuAcik(false)}>Panelim</Link>
                  <button onClick={() => { logout(); setMenuAcik(false); }} className="text-sm font-medium text-tehlike">Çıkış</button>
                </>
              ) : (
                <>
                  <Link href="/giris" className="text-sm font-medium text-metin-ikincil" onClick={() => setMenuAcik(false)}>Giriş</Link>
                  <Link href="/kayit-ol" className="text-sm font-medium px-4 py-2 bg-birincil text-white rounded-lg" onClick={() => setMenuAcik(false)}>Üye Ol</Link>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
