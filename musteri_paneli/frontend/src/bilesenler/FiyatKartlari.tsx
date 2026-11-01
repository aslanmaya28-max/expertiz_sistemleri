"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { getCreditPackages, type CreditPackage } from "@/lib/api";

type PaketSatiri = CreditPackage & { key: string };

function tl(value: number) {
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

const ozellikler = [
  "Güncel piyasa ortalaması (emsal ilanlar)",
  "Boya / değişen / tramer değer kaybı",
  "Tavsiye alım fiyatı ve AL / PAZARLIK / ALMA kararı",
  "Araç enflasyonuna göre 6 aylık ve yıllık getiri",
];

export default function FiyatKartlari() {
  const [paketler, setPaketler] = useState<PaketSatiri[]>([]);
  const [hata, setHata] = useState<string | null>(null);

  useEffect(() => {
    getCreditPackages()
      .then((res) =>
        setPaketler(
          Object.entries(res.packages)
            .map(([key, p]) => ({ key, ...p }))
            .sort((a, b) => a.price - b.price),
        ),
      )
      .catch((err) => setHata(err instanceof Error ? err.message : "Paketler yüklenemedi"));
  }, []);

  return (
    <section className="py-16 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-4">
          <h2 className="text-3xl font-bold text-metin-birincil">Araç Değerleme Paketleri</h2>
          <p className="mt-3 text-metin-ikincil">Her analiz 1 kredi. Tüm kullanıcılar için aynı kredi paketleri, KDV dahil fiyatlarla sunulur. Ödeme onaylanınca krediler hemen hesabınıza yüklenir.</p>
        </div>
        <div className="text-center mb-12">
          <span className="inline-flex items-center gap-2 px-4 py-2 bg-birincil/10 text-birincil rounded-full text-sm font-medium">
            Kayıt olana <strong>1 analiz ücretsiz</strong>
          </span>
        </div>

        {hata && <p className="text-center text-sm text-tehlike">{hata}</p>}

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {paketler.map((paket) => (
            <div
              key={paket.key}
              className={`relative rounded-2xl border p-6 flex flex-col ${
                paket.popular ? "border-birincil shadow-lg shadow-birincil/10" : "border-kenarlik-acik"
              }`}
            >
              {paket.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-birincil text-white text-xs font-medium rounded-full">
                  En Popüler
                </div>
              )}
              <h3 className="text-lg font-bold text-metin-birincil">{paket.name}</h3>
              <div className="mt-3">
                <span className="text-3xl font-bold text-metin-birincil">{tl(paket.price)}</span>
                <div className="text-sm text-metin-ikincil mt-1">
                  {paket.credits} analiz • {tl(paket.price / paket.credits)}/analiz
                </div>
              </div>
              <ul className="mt-5 space-y-2.5 flex-1">
                {ozellikler.map((oz) => (
                  <li key={oz} className="flex items-start gap-2 text-sm text-metin-ikincil">
                    <svg className="w-4 h-4 text-birincil flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    {oz}
                  </li>
                ))}
              </ul>
              <Link
                href={`/kredi-yukle?paket=${encodeURIComponent(paket.key)}`}
                className={`mt-6 block text-center py-2.5 rounded-lg font-medium text-sm transition-colors ${
                  paket.popular
                    ? "bg-birincil text-white hover:bg-birincil-koyu"
                    : "border border-kenarlik-acik text-metin-birincil hover:border-birincil hover:text-birincil"
                }`}
              >
                Satın Al
              </Link>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
