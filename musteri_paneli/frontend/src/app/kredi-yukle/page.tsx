"use client";

import Link from "next/link";
import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import OdemeAlani from "@/bilesenler/OdemeAlani";
import SozlesmeOnayi from "@/bilesenler/SozlesmeOnayi";
import { notifyCreditsChanged, useAuth } from "@/kancalar/yetkiKullan";
import {
  getCreditBalance,
  getCreditPackages,
  startCreditCheckout,
  type CheckoutStart,
  type CheckoutStatus,
  type CreditPackage,
} from "@/lib/api";

function tl(value: number) {
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

function KrediYukleIcerigi() {
  const params = useSearchParams();
  const { user, loading: authLoading } = useAuth();
  const [paketler, setPaketler] = useState<(CreditPackage & { key: string })[]>([]);
  const [secili, setSecili] = useState<string>(params.get("paket") || "");
  const [bakiye, setBakiye] = useState<number | null>(null);
  const [checkout, setCheckout] = useState<CheckoutStart | null>(null);
  const [tamam, setTamam] = useState<CheckoutStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [onay, setOnay] = useState(false);
  // Sunucu söylemezse (eski sürüm) açık kabul edilir; PayTR kurulana kadar false gelir.
  const [satisAcik, setSatisAcik] = useState(true);

  useEffect(() => {
    getCreditPackages()
      .then((res) => {
        const list = Object.entries(res.packages).map(([key, p]) => ({ key, ...p })).sort((a, b) => a.price - b.price);
        setPaketler(list);
        setSatisAcik(res.sales_open !== false);
        setSecili((prev) => prev || list.find((p) => p.popular)?.key || list[0]?.key || "");
      })
      .catch((err) => setHata(err instanceof Error ? err.message : "Paketler yüklenemedi"));
  }, []);

  useEffect(() => {
    if (!user) return;
    getCreditBalance().then((b) => setBakiye(b.credits)).catch(() => undefined);
  }, [user]);

  async function odemeyeGec() {
    setBusy(true);
    setHata(null);
    try {
      setCheckout(await startCreditCheckout(secili, onay));
    } catch (err) {
      setHata(err instanceof Error ? err.message : "Ödeme başlatılamadı");
    } finally {
      setBusy(false);
    }
  }

  const odendi = useCallback((status: CheckoutStatus) => {
    setTamam(status);
    if (status.credit_balance != null) setBakiye(status.credit_balance);
    notifyCreditsChanged();
  }, []);
  const basarisiz = useCallback(() => undefined, []);

  if (!authLoading && !user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <header className="yb-band yb-form-band"><h1>Kredi Yükle</h1></header>
        <p className="mt-3 text-metin-ikincil">Kredi satın almak için giriş yapın.</p>
        <Link href="/giris" className="mt-6 inline-block rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
          Giriş yap
        </Link>
      </div>
    );
  }

  const paket = paketler.find((p) => p.key === secili);

  return (
    <div className="yb-inner-page yb-credit-page max-w-4xl mx-auto px-4 py-10">
      <header className="yb-band yb-form-band"><h1>Kredi Yükle</h1></header>
      <p className="mt-1 text-metin-ikincil">
        Araç değerleme analizi başına 1 kredi.{bakiye != null && <> Mevcut bakiye: <strong>{bakiye} kredi</strong></>}
      </p>

      {tamam ? (
        <div className="mt-8 rounded-xl border border-green-200 bg-green-50 p-6">
          <h2 className="text-xl font-bold text-basarili">Ödeme başarılı</h2>
          <p className="mt-2 text-metin-birincil">
            {tamam.credits} kredi hesabınıza yüklendi. Güncel bakiye: <strong>{tamam.credit_balance} kredi</strong>
          </p>
          <Link href="/arac-analiz" className="mt-4 inline-block rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
            Araç değerlemesine başla
          </Link>
        </div>
      ) : checkout ? (
        <div className="mt-8">
          <h2 className="mb-3 text-lg font-semibold text-metin-birincil">{paket?.name} — güvenli ödeme</h2>
          <OdemeAlani checkout={checkout} onPaid={odendi} onFailed={basarisiz} />
          <button type="button" onClick={() => setCheckout(null)} className="mt-4 text-sm font-semibold text-birincil underline">
            Paketi değiştir / tekrar dene
          </button>
        </div>
      ) : !satisAcik ? (
        <div className="mt-8 space-y-3" data-odeme="yakinda">
          <div className="rounded-xl border border-kenarlik-acik bg-white p-5">
            <span className="inline-block rounded-full bg-orange-50 px-3 py-1 text-xs font-bold text-orange-700">Yakında</span>
            <h2 className="mt-3 text-lg font-bold text-metin-birincil">Kartla kredi satın alma çok yakında açılıyor</h2>
            <p className="mt-2 text-sm leading-relaxed text-metin-ikincil">
              Ödeme altyapımızın son hazırlıklarını yapıyoruz. Bu sırada hesabınızdaki mevcut ve hediye kredilerle
              değerleme yapmaya devam edebilirsiniz. Satış açıldığında fiyatlar aşağıdaki gibi olacak.
            </p>
            {bakiye != null && bakiye > 0 && (
              <Link href="/arac-analiz" className="yb-btn yb-btn-green mt-4 inline-flex">Kredimle değerleme yap</Link>
            )}
          </div>
          {paketler.map((p) => (
            <div key={p.key} className="yb-credit-option flex items-center justify-between rounded-lg border border-kenarlik-acik p-4 opacity-70">
              <span>
                <span className="font-semibold text-metin-birincil">{p.name}</span>
                <span className="block text-xs text-metin-ikincil">{tl(p.price / p.credits)} / analiz</span>
              </span>
              <strong className="text-metin-birincil">{tl(p.price)}</strong>
            </div>
          ))}
          <button type="button" disabled className="yb-btn yb-btn-green w-full disabled:opacity-50">Yakında</button>
        </div>
      ) : (
        <div className="mt-8 space-y-3">
          {paketler.map((p) => (
            <label
              key={p.key}
              className={`yb-credit-option flex cursor-pointer items-center justify-between rounded-lg border p-4 ${p.key === secili ? "border-birincil bg-blue-50" : "border-kenarlik-acik"}`}
            >
              <span className="flex items-center gap-3">
                <input type="radio" name="paket" checked={p.key === secili} onChange={() => setSecili(p.key)} />
                <span>
                  <span className="font-semibold text-metin-birincil">{p.name}</span>
                  <span className="block text-xs text-metin-ikincil">{tl(p.price / p.credits)} / analiz</span>
                </span>
              </span>
              <strong className="text-metin-birincil">{tl(p.price)}</strong>
            </label>
          ))}
          <SozlesmeOnayi checked={onay} onChange={setOnay} />
          <button
            type="button"
            onClick={odemeyeGec}
            disabled={!paket || busy || !onay}
            className="yb-btn yb-btn-green w-full disabled:opacity-50"
          >
            {busy ? "Ödeme hazırlanıyor..." : paket ? `${tl(paket.price)} Öde` : "Paket seçin"}
          </button>
        </div>
      )}
      {hata && <p className="mt-4 text-sm text-tehlike">{hata}</p>}
    </div>
  );
}

export default function KrediYuklePage() {
  return (
    <Suspense fallback={<div className="max-w-3xl mx-auto px-4 py-10 text-metin-ikincil">Yükleniyor...</div>}>
      <KrediYukleIcerigi />
    </Suspense>
  );
}
