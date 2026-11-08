"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { getCreditPackages, type CreditPackage } from "@/lib/api";

type PaketSatiri = CreditPackage & { key: string };

function tl(value: number) {
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

const ozellikler = [
  "Adil fiyat aralığı ve tavsiye alım fiyatı",
  "Boya / değişen / tramer değer kaybı, kalem kalem",
  "Pazarlık planı ve satıcıya hazır mesaj",
  "Enflasyona göre 6 aylık ve yıllık kazanç",
  "Ekranda ve PDF, doğrulama kodlu",
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
    <section className="yb-inner-page yb-pricing-section">
      <div className="yb-pricing-content">
        <div className="yb-heading text-center mb-4">
          <h2 className="text-3xl font-bold text-metin-birincil">Araç Değerleme Paketleri</h2>
          <p className="mt-3 text-metin-ikincil">Her analiz 1 kredi. Tüm kullanıcılar için aynı kredi paketleri, KDV dahil fiyatlarla sunulur. Ödeme onaylanınca krediler hemen hesabınıza yüklenir.</p>
        </div>
        <div className="text-center mb-12">
          <Link href="/ornek-rapor" className="yb-btn yb-btn-outline">
            Satın almadan önce örnek raporu inceleyin
          </Link>
        </div>

        {hata && <p className="text-center text-sm text-tehlike">{hata}</p>}

        <div className="yb-grid-3 yb-package-grid">
          {paketler.map((paket) => (
            <div
              key={paket.key}
              className={`yb-card yb-package-card ${
                paket.popular ? "yb-card-dark" : "yb-card-mint"
              }`}
            >
              {paket.popular && (
                <div className="yb-badge yb-badge-on-dark yb-package-popular">
                  En Popüler
                </div>
              )}
              <h3>{paket.name}</h3>
              <div className="mt-3">
                <span className="yb-big-number">{tl(paket.price)}</span>
                <div className="yb-package-unit yb-badge mt-3">
                  {paket.credits} analiz • {tl(paket.price / paket.credits)}/analiz
                </div>
              </div>
              <ul className="yb-check-list mt-5 flex-1">
                {ozellikler.map((oz) => (
                  <li key={oz}>
                    {oz}
                  </li>
                ))}
              </ul>
              <Link
                href={`/kredi-yukle?paket=${encodeURIComponent(paket.key)}`}
                className={`yb-btn mt-6 ${
                  paket.popular
                    ? "yb-btn-mint"
                    : "yb-btn-green"
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
