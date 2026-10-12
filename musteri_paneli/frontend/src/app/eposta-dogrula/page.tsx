"use client";

import Link from "next/link";
import { Suspense, useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { verifyEmail } from "@/lib/api";
import { notifyCreditsChanged } from "@/kancalar/yetkiKullan";

function DogrulaIcerigi() {
  const token = useSearchParams().get("token") || "";
  const [durum, setDurum] = useState<{ ok: boolean; mesaj: string } | null>(null);
  const basladi = useRef(false);

  useEffect(() => {
    if (basladi.current) return;
    basladi.current = true;
    if (!token) {
      window.setTimeout(() => setDurum({ ok: false, mesaj: "Doğrulama bağlantısı eksik." }), 0);
      return;
    }
    verifyEmail(token)
      .then((res) => {
        notifyCreditsChanged();
        setDurum({
          ok: true,
          mesaj: res.credits_granted
            ? `E-posta adresiniz doğrulandı. ${res.credits_granted} ücretsiz analiz krediniz hesabınıza yüklendi.`
            : "E-posta adresiniz doğrulandı.",
        });
      })
      .catch((err) => setDurum({ ok: false, mesaj: err instanceof Error ? err.message : "Doğrulama başarısız" }));
  }, [token]);

  if (!durum) return <p className="text-center text-metin-ikincil">Doğrulanıyor...</p>;
  return (
    <div className={`rounded-lg border p-4 text-sm ${durum.ok ? "border-green-200 bg-green-50 text-green-800" : "border-red-200 bg-red-50 text-red-700"}`}>
      {durum.mesaj}{" "}
      {durum.ok ? (
        <Link href="/arac-analiz" className="font-semibold underline">Araç analizine başla</Link>
      ) : (
        <span>Panelinizden yeni doğrulama e-postası isteyebilirsiniz: <Link href="/panel" className="font-semibold underline">Panelim</Link></span>
      )}
    </div>
  );
}

export default function EpostaDogrulaSayfasi() {
  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <h1 className="mb-8 text-2xl font-bold text-metin-birincil text-center">E-posta Doğrulama</h1>
        <Suspense fallback={null}><DogrulaIcerigi /></Suspense>
      </div>
    </div>
  );
}
