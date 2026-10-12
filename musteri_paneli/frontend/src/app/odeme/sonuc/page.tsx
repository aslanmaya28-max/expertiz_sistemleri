"use client";

import Link from "next/link";
import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { SON_SIPARIS_KEY } from "@/bilesenler/OdemeAlani";
import { getCheckoutStatus, type CheckoutStatus } from "@/lib/api";
import { notifyCreditsChanged } from "@/kancalar/yetkiKullan";

/** PayTR, odeme sonrasi musteriyi bu sayfaya (iframe icinde) yonlendirir. */
function OdemeSonucIcerigi() {
  const params = useSearchParams();
  const [status, setStatus] = useState<CheckoutStatus | null>(null);
  const [orderId] = useState<string | null>(() => {
    try {
      return typeof window === "undefined" ? null : sessionStorage.getItem(SON_SIPARIS_KEY);
    } catch {
      return null;
    }
  });

  useEffect(() => {
    // Iframe icinde acildiysa ana pencereye tasi
    if (window.top && window.top !== window.self) {
      window.top.location.href = window.location.href;
    }
  }, []);

  useEffect(() => {
    if (!orderId) return;
    let stop = false;
    const tick = async () => {
      try {
        const next = await getCheckoutStatus(orderId);
        if (stop) return;
        setStatus(next);
        if (next.status === "pending") window.setTimeout(tick, 3000);
        else if (next.status === "paid" && next.kind === "credits") notifyCreditsChanged();
      } catch {
        if (!stop) window.setTimeout(tick, 5000);
      }
    };
    tick();
    return () => {
      stop = true;
    };
  }, [orderId]);

  const reported = params.get("durum");
  const paid = status?.status === "paid";
  const failed = status?.status === "failed" || (!status && reported === "basarisiz");

  return (
    <div className="max-w-xl mx-auto px-4 py-16 text-center">
      {paid ? (
        <>
          <h1 className="text-3xl font-bold text-basarili">Ödeme başarılı</h1>
          {status.kind === "credits" ? (
            <p className="mt-3 text-metin-birincil">
              {status.credits} kredi hesabınıza yüklendi. Bakiye: <strong>{status.credit_balance} kredi</strong>
            </p>
          ) : (
            <p className="mt-3 text-metin-birincil">
              Ekspertiz talebiniz alındı ({status.firm_name} — {status.package_name}). Süreci panelinizden takip edebilirsiniz.
            </p>
          )}
          <Link href={status.kind === "credits" ? "/arac-analiz" : "/panel"} className="mt-6 inline-block rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
            {status.kind === "credits" ? "Araç değerlemesine git" : "Panele git"}
          </Link>
        </>
      ) : failed ? (
        <>
          <h1 className="text-3xl font-bold text-tehlike">Ödeme tamamlanamadı</h1>
          <p className="mt-3 text-metin-ikincil">Kartınızdan çekim yapılmadı. Tekrar deneyebilirsiniz.</p>
          <Link href="/panel" className="mt-6 inline-block rounded-lg border border-kenarlik-acik px-5 py-2.5 text-sm font-semibold text-metin-birincil">
            Panele dön
          </Link>
        </>
      ) : (
        <>
          <h1 className="text-2xl font-bold text-metin-birincil">Ödeme onayı bekleniyor</h1>
          <p className="mt-3 text-metin-ikincil">
            {orderId ? "Bankadan onay gelince bu sayfa otomatik güncellenir." : "Sipariş bilgisi bulunamadı; ödemelerinizi panelden kontrol edebilirsiniz."}
          </p>
        </>
      )}
    </div>
  );
}

export default function OdemeSonucPage() {
  return (
    <Suspense fallback={<div className="max-w-xl mx-auto px-4 py-16 text-center text-metin-ikincil">Yükleniyor...</div>}>
      <OdemeSonucIcerigi />
    </Suspense>
  );
}
