import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Örnek rapor | YerimeBak",
  description: "YerimeBak raporlarında neler olduğu: iç ekspertiz, dış ekspertiz, kurumsal ekspertiz ve yapay zekâ destekli araç değerleme.",
  robots: { index: false, follow: true },
};

const RAPORLAR = [
  { baslik: "İç ekspertiz", detay: "Koltuklar, döşeme, elektronik donanım ve kabin içi kontroller; fotoğraflarla belgelenir." },
  { baslik: "Dış ekspertiz", detay: "Boya, değişen, kaporta ve dış kozmetik kontrolleri; parça parça işaretlenir." },
  { baslik: "Kurumsal ekspertiz", detay: "Anlaşmalı ekspertiz merkezinin resmi raporu müşteri panelinize eklenir." },
  { baslik: "Yapay zekâ değerleme", detay: "Benzer ilanlar, hasar kalemleri ve pazarlık planıyla aracın adil fiyat aralığı." },
];

export default function OrnekRaporSayfasi() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-metin-birincil">Örnek rapor</h1>
      <p className="mt-3 text-metin-ikincil">
        Gerçek bir araç için hazırlanmış örnek raporumuz çok yakında bu sayfada yayında olacak.
        Bir YerimeBak incelemesinde müşteri panelinize şu raporlar gelir:
      </p>
      <ul className="mt-6 space-y-3">
        {RAPORLAR.map((r) => (
          <li key={r.baslik} className="rounded-xl border border-kenarlik-acik bg-white p-4">
            <div className="font-semibold text-metin-birincil">{r.baslik}</div>
            <div className="mt-1 text-sm text-metin-ikincil">{r.detay}</div>
          </li>
        ))}
      </ul>
      <div className="mt-8 flex flex-wrap gap-3">
        <Link href="/ekspertiz-talebi" className="rounded-lg bg-birincil px-5 py-3 font-semibold text-white">İnceleme talebi oluştur</Link>
        <Link href="/fiyatlar" className="rounded-lg border border-kenarlik-acik px-5 py-3 font-semibold text-metin-birincil">Fiyatlar</Link>
      </div>
    </div>
  );
}
