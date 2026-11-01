"use client";

import Link from "next/link";
import type { ValuationResult } from "@/lib/api";
import { AkilliAliciBolumleri, SonrakiAdim } from "./AkilliAliciBolumleri";

function tl(value?: number | null) {
  if (value == null) return "-";
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

const KARAR_RENK: Record<string, string> = {
  AL: "bg-green-50 border-green-300 text-green-800",
  "PAZARLIK YAP": "bg-yellow-50 border-yellow-300 text-yellow-800",
  ALMA: "bg-red-50 border-red-300 text-red-800",
  "EK DOĞRULAMA GEREKLİ": "bg-slate-50 border-slate-300 text-slate-800",
};

const GUVEN_METNI: Record<string, string> = {
  yuksek: "Veri güveni yüksek",
  orta: "Veri güveni orta",
  dusuk: "Veri güveni düşük",
};

const KAYNAK_ROZET: Record<string, string> = {
  musteri_beyani: "Beyan",
  kayitli_ilan: "Kayıtlı ilan",
  internet_ilanlari: "İnternet ilanları",
  kayitli_ilanlar: "Kayıtlı ilanlar",
  hesaplama: "Hesaplama",
  tahmin: "Tahmin",
};

export default function DegerlemeSonucu({ sonuc, onYeni }: { sonuc: ValuationResult; onYeni?: () => void }) {
  const { arac, piyasa, degerleme, karar, getiri, ozet, bilgiKaynaklari } = sonuc;
  return (
    <div className="mt-8 space-y-6">
      {sonuc.rapor && <div className="rounded-lg border border-kenarlik-acik bg-white p-4 text-sm">
        <Link href={`/panel/degerlemeler/${encodeURIComponent(sonuc.rapor.id)}`} className="font-semibold text-birincil underline">Rapor kaydedildi — Raporlarım&apos;da</Link>
        <p className="mt-2">{sonuc.rapor.report_no} • {new Date(sonuc.rapor.created_at).toLocaleString("tr-TR")}</p>
        <Link href={`/dogrula/${sonuc.rapor.verification_code}`} className="text-birincil underline">Doğrulama kodu: {sonuc.rapor.verification_code}</Link>
        <p className="mt-2 text-metin-ikincil">Kredili değerleme raporu — uzman incelemesi içermez.</p>
      </div>}
      <div className={`rounded-xl border-2 p-6 ${KARAR_RENK[karar.sonuc] || "border-kenarlik-acik"}`}>
        <div className="text-sm font-medium opacity-80">{arac.marka} {arac.model} {arac.yil} • {new Intl.NumberFormat("tr-TR").format(arac.km)} km</div>
        <div className="mt-1 text-3xl font-extrabold">{karar.sonuc}</div>
        <p className="mt-2">{karar.aciklama}</p>
        {karar.guvenSeviyesi && (
          <p className="mt-2 text-sm font-medium opacity-80">
            {GUVEN_METNI[karar.guvenSeviyesi]}
            {karar.hesaplananEgilim ? ` • Hesaplanan eğilim: ${karar.hesaplananEgilim} (kesin karar değildir)` : ""}
          </p>
        )}
      </div>

      {ozet && (
        <section className="bg-white rounded-xl border border-kenarlik-acik p-6" aria-label="Özet">
          <h2 className="text-lg font-semibold text-metin-birincil">Özet</h2>
          <dl className="mt-3 divide-y divide-kenarlik-acik text-sm">
            <div className="grid gap-1 py-3 sm:grid-cols-[220px_1fr]">
              <dt className="font-medium text-metin-birincil">Piyasaya göre fiyatı</dt>
              <dd className="text-metin-ikincil">{ozet.piyasaKonumu.metin}</dd>
            </div>
            <div className="grid gap-1 py-3 sm:grid-cols-[220px_1fr]">
              <dt className="font-medium text-metin-birincil">Adil fiyat</dt>
              <dd className="text-metin-ikincil">{tl(ozet.adilFiyat.min)} – {tl(ozet.adilFiyat.max)}</dd>
            </div>
            <div className="grid gap-1 py-3 sm:grid-cols-[220px_1fr]">
              <dt className="font-medium text-metin-birincil">En önemli riskler</dt>
              <dd><ul className="list-disc space-y-1 pl-5 text-metin-ikincil">{ozet.riskler.map((r) => <li key={r}>{r}</li>)}</ul></dd>
            </div>
            {ozet.pazarlikGerekceleri.length > 0 && (
              <div className="grid gap-1 py-3 sm:grid-cols-[220px_1fr]">
                <dt className="font-medium text-metin-birincil">Pazarlık gerekçeleri</dt>
                <dd><ul className="list-disc space-y-1 pl-5 text-metin-ikincil">{ozet.pazarlikGerekceleri.map((g) => <li key={g}>{g}</li>)}</ul></dd>
              </div>
            )}
            <div className="grid gap-1 py-3 sm:grid-cols-[220px_1fr]">
              <dt className="font-medium text-metin-birincil">Şimdi ne yapmalı?</dt>
              <dd className="font-medium text-metin-birincil">{ozet.simdiNeYapmali}</dd>
            </div>
          </dl>
        </section>
      )}

      <AkilliAliciBolumleri sonuc={sonuc} />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Kutu baslik="İlan fiyatı" deger={tl(arac.ilanFiyati)} />
        <Kutu baslik="Tavsiye alım fiyatı" deger={tl(degerleme.tavsiyeFiyat)} vurgu />
        <Kutu baslik="Adil fiyat aralığı" deger={`${tl(degerleme.adilFiyatAraligi?.min)} – ${tl(degerleme.adilFiyatAraligi?.max)}`} />
        <Kutu baslik="Hasarsız piyasa değeri" deger={tl(degerleme.temizPiyasaDegeri)} />
      </div>

      <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
        <h2 className="text-lg font-semibold text-metin-birincil">Değer kaybı ({degerleme.toplamDegerKaybiYuzde}% • {tl(degerleme.toplamDegerKaybiTutar)})</h2>
        {degerleme.kalemler.length === 0 ? (
          <p className="mt-2 text-sm text-metin-ikincil">Bildirilen boya, değişen veya hasar kaydı yok.</p>
        ) : (
          <table className="mt-3 w-full text-sm">
            <tbody>
              {degerleme.kalemler.map((k) => (
                <tr key={`${k.kategori}-${k.anahtar}`} className="border-t border-kenarlik-acik">
                  <td className="py-2 text-metin-birincil">{k.baslik}</td>
                  <td className="py-2 text-metin-ikincil">{k.durum}</td>
                  <td className="py-2 text-right text-metin-ikincil">-%{k.yuzde.toFixed(1)}</td>
                  <td className="py-2 text-right font-semibold text-metin-birincil">-{tl(k.tutar)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {degerleme.ozet && <p className="mt-3 text-sm text-metin-ikincil">{degerleme.ozet}</p>}
      </section>

      <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
        <h2 className="text-lg font-semibold text-metin-birincil">Piyasa karşılaştırması</h2>
        <p className="mt-2 text-sm text-metin-ikincil">
          {piyasa.emsalSayisi} güncel emsal ilan ({piyasa.hasarsizEmsalSayisi ?? 0} hasarsız). Ortalama {tl(piyasa.ortalama)}, medyan {tl(piyasa.medyan)},
          aralık {tl(piyasa.min)} – {tl(piyasa.max)}. Güven skoru: %{piyasa.guvenSkoru}.
        </p>
        {piyasa.uyarilar?.length > 0 && (
          <div className="mt-3 rounded-lg border border-yellow-300 bg-yellow-50 p-4 text-sm text-yellow-900">
            <ul className="list-disc space-y-1 pl-5">
              {piyasa.uyarilar.map((uyari) => <li key={uyari}>{uyari}</li>)}
            </ul>
          </div>
        )}
        {(piyasa.kaynaklar || []).some((k) => k.url && /^https?:\/\//i.test(k.url)) && (
          <ul className="mt-3 space-y-2 text-sm">
            {piyasa.kaynaklar.filter((k) => k.url && /^https?:\/\//i.test(k.url)).map((k, i) => (
              <li key={`${k.url}-${i}`}>
                <a href={k.url!} target="_blank" rel="noopener noreferrer nofollow" className="text-birincil underline">
                  {k.site || "Kaynak ilan"} • {k.yil ?? "Yıl belirtilmemiş"} • {k.km == null ? "Km belirtilmemiş" : `${new Intl.NumberFormat("tr-TR").format(k.km)} km`} • {tl(k.fiyat)}
                </a>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
        <h2 className="text-lg font-semibold text-metin-birincil">Getiri tahmini (araç enflasyonu)</h2>
        {getiri ? (
          <>
            <p className="mt-1 text-sm text-metin-ikincil">
              Aylık %{getiri.aylikEnflasyonYuzde} (yıllık ≈ %{getiri.yillikEnflasyonYuzde}){getiri.kaynak ? ` • ${getiri.kaynak}` : ""}
              {getiri.gecerlilikTarihi ? ` • ${getiri.gecerlilikTarihi}` : ""}. Alış fiyatı: {tl(getiri.alisFiyati)}
            </p>
            <div className="mt-3 grid gap-4 sm:grid-cols-2">
              {[getiri.altiAy, getiri.birYil].map((h) => (
                <div key={h.ay} className="rounded-lg bg-arkaplan-acik p-4">
                  <div className="text-sm text-metin-ikincil">{h.ay === 6 ? "6 ay sonra" : "1 yıl sonra"}</div>
                  <div className="text-xl font-bold text-metin-birincil">{tl(h.tahminiDeger)}</div>
                  <div className={`text-sm font-semibold ${h.getiriTl >= 0 ? "text-basarili" : "text-tehlike"}`}>
                    {h.getiriTl >= 0 ? "+" : ""}{tl(h.getiriTl)} {h.getiriYuzde != null && `(%${h.getiriYuzde})`}
                  </div>
                </div>
              ))}
            </div>
            <p className="mt-3 text-xs text-metin-ikincil">{getiri.aciklama}</p>
          </>
        ) : (
          <p className="mt-2 text-sm text-metin-ikincil">Güncel araç enflasyonu oranı henüz girilmedi.</p>
        )}
      </section>

      {bilgiKaynaklari && bilgiKaynaklari.length > 0 && (
        <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
          <h2 className="text-lg font-semibold text-metin-birincil">Bu rapordaki bilgiler nereden geliyor?</h2>
          <ul className="mt-3 space-y-2 text-sm">
            {bilgiKaynaklari.map((k) => (
              <li key={k.alan} className="flex flex-wrap items-baseline gap-2">
                <span className="rounded-full bg-arkaplan-acik px-2 py-0.5 text-xs font-semibold text-metin-birincil">{KAYNAK_ROZET[k.kaynak] || k.kaynak}</span>
                <span className="font-medium text-metin-birincil">{k.alan}:</span>
                <span className="text-metin-ikincil">{k.aciklama}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <SonrakiAdim sonuc={sonuc} />

      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className="text-sm text-metin-ikincil">{sonuc.kredi.dusulen} kredi kullanıldı • Kalan: {sonuc.kredi.kalan}</span>
        <div className="flex gap-2">
          {onYeni && <button type="button" onClick={onYeni} className="rounded-lg bg-birincil px-4 py-2 text-sm font-semibold text-white">Yeni analiz</button>}
        </div>
      </div>
    </div>
  );
}

function Kutu({ baslik, deger, vurgu }: { baslik: string; deger: string; vurgu?: boolean }) {
  return (
    <div className={`rounded-xl border p-4 ${vurgu ? "border-birincil bg-birincil/5" : "border-kenarlik-acik bg-white"}`}>
      <div className="text-xs text-metin-ikincil">{baslik}</div>
      <div className={`mt-1 text-lg font-bold ${vurgu ? "text-birincil-koyu" : "text-metin-birincil"}`}>{deger}</div>
    </div>
  );
}
