import type { Metadata } from "next";
import Link from "next/link";
import DegerlemeSonucu from "@/bilesenler/DegerlemeSonucu";
import type { ValuationResult } from "@/lib/api";
import veri from "../../../public/ornek-rapor/degerleme.json";

export const metadata: Metadata = {
  title: "Örnek araç değerleme raporu | YerimeBak",
  description: "Gerçek bir araç için hazırlanan örnek değerleme raporunu ve PDF örneğini inceleyin. Kendi aracınız için değerleme 1 kredi (100 TL).",
};

// JSON tür çıkarımı birleşik alanlarda (ör. parça durumları) daralmıyor; alanlar node testinde denetlenir.
const sonuc = veri as unknown as ValuationResult;

export default function OrnekRaporSayfasi() {
  const tarih = new Date(sonuc.rapor!.created_at).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit", year: "numeric" });
  return (
    <div className="relative isolate mx-auto max-w-5xl px-4 py-12">
      <div aria-hidden="true" className="pointer-events-none absolute inset-0 z-10 flex flex-col justify-around overflow-hidden select-none">
        {Array.from({ length: 12 }, (_, i) => <span key={i} className="-rotate-30 text-center text-7xl font-bold text-birincil opacity-[0.06] sm:text-9xl">ÖRNEK</span>)}
      </div>
      <h1 className="text-3xl font-bold text-metin-birincil">Örnek araç değerleme raporu</h1>
      <p className="mt-3 text-metin-ikincil">Bu, gerçek bir araç için oluşturulmuş örnek değerleme raporudur. 1 kredi (100 TL) ile kendi aracınız için aynısını alırsınız.</p>
      <p className="mt-2 text-sm text-metin-ikincil">Örnek tarihi: <time dateTime={sonuc.rapor!.created_at}>{tarih}</time>. Örnek rapordur, doğrulanamaz.</p>
      <a href="/ornek-rapor/degerleme-ornek.pdf" download className="mt-4 inline-block font-semibold text-birincil underline">PDF örneğini indir</a>
      <DegerlemeSonucu sonuc={sonuc} ornek />
      <div className="mt-8 flex flex-wrap gap-3">
        <Link href="/arac-analiz" className="rounded-lg bg-birincil px-5 py-3 font-semibold text-white">Kendi aracım için değerleme al (1 kredi)</Link>
        <Link href="/fiyatlar" className="rounded-lg border border-kenarlik-acik px-5 py-3 font-semibold text-metin-birincil">Kredi paketleri</Link>
      </div>
    </div>
  );
}