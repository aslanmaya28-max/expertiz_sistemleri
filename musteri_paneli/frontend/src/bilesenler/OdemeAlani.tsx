"use client";

import { useEffect, useRef, useState } from "react";
import { getCheckoutStatus, simulateCheckout, type CheckoutStart, type CheckoutStatus } from "@/lib/api";

/** PayTR'den donuste (/odeme/sonuc) hangi siparisin sorgulanacagi */
export const SON_SIPARIS_KEY = "yerimebak_son_siparis";

function tl(value: number) {
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 2 }).format(value) + " TL";
}

/**
 * PayTR odeme iframe'i + odeme sonucunu takip.
 * Odeme onaylaninca (PayTR bildirimi sunucuya ulasinca) onPaid cagrilir.
 */
export default function OdemeAlani({
  checkout,
  onPaid,
  onFailed,
}: {
  checkout: CheckoutStart;
  onPaid: (status: CheckoutStatus) => void;
  onFailed?: (status: CheckoutStatus) => void;
}) {
  const [status, setStatus] = useState<CheckoutStatus | null>(null);
  const [simBusy, setSimBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const done = useRef(false);

  useEffect(() => {
    try {
      sessionStorage.setItem(SON_SIPARIS_KEY, checkout.order_id);
    } catch {
      /* depolama kapali olabilir */
    }
  }, [checkout.order_id]);

  useEffect(() => {
    done.current = false;
    const tick = async () => {
      if (done.current) return;
      try {
        const next = await getCheckoutStatus(checkout.order_id);
        setStatus(next);
        if (next.status === "paid") {
          done.current = true;
          onPaid(next);
        } else if (next.status === "failed") {
          done.current = true;
          onFailed?.(next);
        }
      } catch {
        /* gecici ag hatasi: tekrar denenir */
      }
    };
    const timer = window.setInterval(tick, 3000);
    tick();
    return () => window.clearInterval(timer);
  }, [checkout.order_id, onPaid, onFailed]);

  async function simulate(success: boolean) {
    setSimBusy(true);
    setError(null);
    try {
      const next = await simulateCheckout(checkout.order_id, success);
      setStatus(next);
      if (next.status === "paid" && !done.current) {
        done.current = true;
        onPaid(next);
      } else if (next.status === "failed" && !done.current) {
        done.current = true;
        onFailed?.(next);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Simulasyon basarisiz");
    } finally {
      setSimBusy(false);
    }
  }

  if (status?.status === "failed") {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-tehlike">
        Ödeme tamamlanamadı{status.failed_reason ? `: ${status.failed_reason}` : ""}. Kartınızdan çekim yapılmadı; tekrar deneyebilirsiniz.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between rounded-lg bg-arkaplan-acik px-4 py-3 text-sm">
        <span className="text-metin-ikincil">Ödenecek tutar</span>
        <strong className="text-metin-birincil">{tl(checkout.amount_tl)}</strong>
      </div>

      {checkout.provider === "paytr" && checkout.iframe_url ? (
        <iframe
          src={checkout.iframe_url}
          title="PayTR güvenli ödeme"
          className="w-full rounded-lg border border-kenarlik-acik"
          style={{ minHeight: 640 }}
          allow="payment"
        />
      ) : (
        <div className="rounded-lg border border-dashed border-uyari bg-yellow-50 p-4 text-sm">
          <p className="font-semibold text-metin-birincil">Test ödeme modu</p>
          <p className="mt-1 text-metin-ikincil">
            Sunucu ödeme simülasyonu modunda; gerçek kart çekimi yapılmaz. Canlı ortamda bu alanın yerine PayTR ödeme formu görünür.
          </p>
          <div className="mt-3 flex gap-2">
            <button type="button" disabled={simBusy} onClick={() => simulate(true)} className="rounded-lg bg-birincil px-4 py-2 font-semibold text-white disabled:opacity-50">
              Ödemeyi Onayla (test)
            </button>
            <button type="button" disabled={simBusy} onClick={() => simulate(false)} className="rounded-lg border border-kenarlik-acik px-4 py-2 font-semibold text-metin-birincil disabled:opacity-50">
              Başarısız Ödeme (test)
            </button>
          </div>
        </div>
      )}

      <p className="text-xs text-metin-ikincil">
        {status?.status === "paid" ? "Ödeme onaylandı." : "Ödeme onayı bekleniyor; onaylanınca bu sayfa otomatik güncellenir."}
      </p>
      {error && <p className="text-sm text-tehlike">{error}</p>}
    </div>
  );
}
