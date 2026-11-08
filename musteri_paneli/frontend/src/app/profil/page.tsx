"use client";

import { useEffect } from "react";
import { useAuth, useCredits } from "@/kancalar/yetkiKullan";

export default function ProfilSayfasi() {
  const { user, loading, logout } = useAuth();
  const credits = useCredits();

  useEffect(() => {
    if (!loading && !user) {
      window.location.href = "/giris";
    }
  }, [user, loading]);

  if (loading) return <div className="max-w-3xl mx-auto px-4 py-12 text-center text-metin-ikincil">Yükleniyor...</div>;
  if (!user) return null;

  return (
    <div className="yb-profile yb-dashboard max-w-3xl mx-auto px-4 py-12">
      <div className="yb-band mb-8"><h1>Profilim</h1></div>

      <div className="yb-card space-y-4">
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">E-posta</span>
          <span className="font-medium">{user.email}</span>
        </div>
        <hr className="border-kenarlik-acik" />
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">Kredi Bakiyesi</span>
          <span className="yb-big-number">{credits}</span>
        </div>
        <hr className="border-kenarlik-acik" />
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">Kullanıcı ID</span>
          <span className="font-mono text-sm">#{user.id}</span>
        </div>
        {user.full_name && (
          <>
            <hr className="border-kenarlik-acik" />
            <div className="flex items-center justify-between">
              <span className="text-sm text-metin-ikincil">Ad Soyad</span>
              <span className="font-medium">{user.full_name}</span>
            </div>
          </>
        )}
      </div>

      <div className="yb-btn-row">
        <a href="/hesap-silme" className="yb-btn text-tehlike underline">Hesabımı sil</a>
        <a href="/fiyatlar" className="yb-btn yb-btn-green">Kredi Satın Al</a>
        <button
          onClick={() => { logout(); window.location.href = "/"; }}
          className="yb-btn yb-btn-outline"
        >
          Çıkış Yap
        </button>
      </div>
    </div>
  );
}
