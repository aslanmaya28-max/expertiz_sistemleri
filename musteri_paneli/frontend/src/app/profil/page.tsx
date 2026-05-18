"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";

export default function ProfilSayfasi() {
  const { user, loading, logout } = useAuth();
  const [token] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    return localStorage.getItem("yerimebak_token");
  });

  useEffect(() => {
    if (!loading && !user) {
      window.location.href = "/giris";
    }
  }, [user, loading]);

  if (loading) return <div className="max-w-3xl mx-auto px-4 py-12 text-center text-metin-ikincil">Yükleniyor...</div>;
  if (!user) return null;

  return (
    <div className="max-w-3xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-metin-birincil mb-8">Profilim</h1>

      <div className="bg-white rounded-xl border border-kenarlik-acik p-6 space-y-4">
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">E-posta</span>
          <span className="font-medium">{user.email}</span>
        </div>
        <hr className="border-kenarlik-acik" />
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">Kredi Bakiyesi</span>
          <span className="text-xl font-bold text-birincil">{user.credits}</span>
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
        <hr className="border-kenarlik-acik" />
        <div className="flex items-center justify-between">
          <span className="text-sm text-metin-ikincil">API Anahtarı</span>
          <code className="text-xs bg-gray-50 px-2 py-1 rounded select-all">{token ? "Bearer token aktif" : "-"}</code>
        </div>
      </div>

      <div className="mt-6 flex gap-4">
        <a href="/fiyatlar" className="px-4 py-2 bg-birincil text-white text-sm font-medium rounded-lg hover:bg-birincil-koyu transition-colors">Kredi Satın Al</a>
        <button
          onClick={() => { logout(); window.location.href = "/"; }}
          className="px-4 py-2 border border-kenarlik-acik text-sm font-medium rounded-lg hover:border-tehlike hover:text-tehlike transition-colors"
        >
          Çıkış Yap
        </button>
      </div>
    </div>
  );
}
