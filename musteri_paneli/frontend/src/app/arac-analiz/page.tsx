"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { notifyCreditsChanged, useAuth } from "@/kancalar/yetkiKullan";
import {
  ApiError,
  analyzeValuation,
  getCreditBalance,
  getValuationParts,
  prefillValuation,
  type PartStatus,
  type ValuationPartsResponse,
  type ValuationResult,
} from "@/lib/api";

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

const DURUM_RENK: Record<PartStatus, string> = {
  orijinal: "bg-white text-metin-ikincil border-kenarlik-acik",
  lokal_boyali: "bg-yellow-50 text-yellow-800 border-yellow-300",
  boyali: "bg-orange-50 text-orange-800 border-orange-300",
  degisen: "bg-red-50 text-red-800 border-red-300",
};

interface Form {
  link: string;
  brand: string;
  model: string;
  year: string;
  km: string;
  price: string;
  fuel: string;
  gear: string;
  tramer: string;
}

const BOS_FORM: Form = { link: "", brand: "", model: "", year: "", km: "", price: "", fuel: "", gear: "", tramer: "" };

export default function AracAnalizSayfasi() {
  const { user, loading: authLoading } = useAuth();
  const [form, setForm] = useState<Form>(BOS_FORM);
  const [meta, setMeta] = useState<ValuationPartsResponse | null>(null);
  const [parts, setParts] = useState<Record<string, PartStatus>>({});
  const [bakiye, setBakiye] = useState<number | null>(null);
  const [prefillMsg, setPrefillMsg] = useState<string | null>(null);
  const [sonuc, setSonuc] = useState<ValuationResult | null>(null);
  const [hata, setHata] = useState<{ message: string; code?: string } | null>(null);
  const [busy, setBusy] = useState<"prefill" | "analyze" | null>(null);

  useEffect(() => {
    getValuationParts().then(setMeta).catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!user) return;
    getCreditBalance().then((b) => setBakiye(b.credits)).catch(() => undefined);
  }, [user]);

  const set = (key: keyof Form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  async function linktenDoldur() {
    if (!form.link.trim()) return;
    setBusy("prefill");
    setHata(null);
    setPrefillMsg(null);
    try {
      const res = await prefillValuation(form.link.trim());
      const v = res.vehicle || {};
      setForm((f) => ({
        ...f,
        link: res.url || f.link,
        brand: v.brand ?? f.brand,
        model: v.model ?? f.model,
        year: v.year != null ? String(v.year) : f.year,
        km: v.km != null ? String(v.km) : f.km,
        price: v.price != null ? String(v.price) : f.price,
        fuel: v.fuel ?? f.fuel,
        gear: v.transmission ?? f.gear,
      }));
      if (res.parts && Object.keys(res.parts).length) setParts(res.parts);
      setPrefillMsg(res.message);
    } catch (err) {
      setHata({ message: err instanceof Error ? err.message : "Link okunamadı" });
    } finally {
      setBusy(null);
    }
  }

  async function analizEt(e: React.FormEvent) {
    e.preventDefault();
    setBusy("analyze");
    setHata(null);
    setSonuc(null);
    try {
      const res = await analyzeValuation({
        listing_url: form.link.trim() || undefined,
        brand: form.brand || undefined,
        model: form.model || undefined,
        year: form.year ? Number(form.year) : undefined,
        km: form.km ? Number(form.km) : undefined,
        listed_price: form.price ? Number(form.price) : undefined,
        fuel: form.fuel || undefined,
        transmission: form.gear || undefined,
        parts,
        tramer_amount: form.tramer ? Number(form.tramer) : 0,
      });
      setSonuc(res);
      setBakiye(res.kredi.kalan);
      notifyCreditsChanged();
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setHata({ message: err instanceof Error ? err.message : "Analiz başarısız", code: err instanceof ApiError ? err.code : undefined });
    } finally {
      setBusy(null);
    }
  }

  if (!authLoading && !user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Araç Değerleme</h1>
        <p className="mt-3 text-metin-ikincil">Beğendiğiniz aracın gerçek değerini öğrenmek için giriş yapın. Kayıt olana 1 analiz ücretsiz.</p>
        <div className="mt-6 flex justify-center gap-3">
          <Link href="/giris" className="rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">Giriş yap</Link>
          <Link href="/kayit-ol" className="rounded-lg border border-kenarlik-acik px-5 py-2.5 text-sm font-semibold text-metin-birincil">Üye ol</Link>
        </div>
      </div>
    );
  }

  const input = "w-full px-3 py-2 border border-kenarlik-acik rounded-lg text-sm";
  const label = "block text-sm font-medium text-metin-birincil mb-1";

  return (
    <div className="max-w-4xl mx-auto px-4 py-10">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-3xl font-bold text-metin-birincil">Araç Değerleme</h1>
          <p className="text-metin-ikincil mt-1">
            Piyasa ortalaması, boya/değişen/hasar değer kaybı, tavsiye fiyat ve enflasyona göre getiri.
          </p>
        </div>
        <div className="text-sm text-metin-ikincil">
          Bakiye: <strong className="text-metin-birincil">{bakiye ?? "-"} kredi</strong>{" "}
          <Link href="/kredi-yukle" className="ml-2 font-semibold text-birincil underline">Kredi yükle</Link>
        </div>
      </div>

      {sonuc && <SonucKarti sonuc={sonuc} onYeni={() => setSonuc(null)} />}

      {hata && (
        <div className="mt-6 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-tehlike">
          {hata.message}
          {hata.code === "insufficient_credits" && (
            <Link href="/kredi-yukle" className="ml-2 font-semibold underline">Kredi yükle</Link>
          )}
        </div>
      )}

      {!sonuc && (
        <form onSubmit={analizEt} className="mt-8 space-y-6">
          <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
            <h2 className="text-lg font-semibold text-metin-birincil">1. İlan linki (isteğe bağlı)</h2>
            <p className="text-sm text-metin-ikincil mt-1">Linki yapıştırın, bilgileri otomatik dolduralım; ya da aşağıya elle girin.</p>
            <div className="mt-3 flex gap-2">
              <input value={form.link} onChange={set("link")} className={input} placeholder="https://www.arabam.com/ilan/..." />
              <button type="button" onClick={linktenDoldur} disabled={!form.link.trim() || busy !== null}
                className="whitespace-nowrap rounded-lg border border-birincil px-4 py-2 text-sm font-semibold text-birincil disabled:opacity-50">
                {busy === "prefill" ? "Okunuyor..." : "Linkten Doldur"}
              </button>
            </div>
            {prefillMsg && <p className="mt-2 text-sm text-metin-ikincil">{prefillMsg}</p>}
          </section>

          <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
            <h2 className="text-lg font-semibold text-metin-birincil">2. Araç bilgileri</h2>
            <div className="mt-4 grid grid-cols-2 gap-4">
              <div><label className={label}>Marka</label><input required value={form.brand} onChange={set("brand")} className={input} placeholder="Volkswagen" /></div>
              <div><label className={label}>Model</label><input required value={form.model} onChange={set("model")} className={input} placeholder="Passat" /></div>
              <div><label className={label}>Model yılı</label><input required type="number" min={1980} value={form.year} onChange={set("year")} className={input} placeholder="2020" /></div>
              <div><label className={label}>Kilometre</label><input required type="number" min={0} value={form.km} onChange={set("km")} className={input} placeholder="85000" /></div>
              <div>
                <label className={label}>Yakıt</label>
                <select value={form.fuel} onChange={set("fuel")} className={input}>
                  <option value="">Seçiniz</option><option>Benzin</option><option>Dizel</option><option>Hibrit</option><option>Elektrik</option><option>LPG</option>
                </select>
              </div>
              <div>
                <label className={label}>Vites</label>
                <select value={form.gear} onChange={set("gear")} className={input}>
                  <option value="">Seçiniz</option><option>Otomatik</option><option>Manuel</option><option>Yarı Otomatik</option>
                </select>
              </div>
              <div className="col-span-2"><label className={label}>İlan fiyatı (₺)</label><input required type="number" min={10000} value={form.price} onChange={set("price")} className={input} placeholder="1250000" /></div>
            </div>
          </section>

          <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
            <h2 className="text-lg font-semibold text-metin-birincil">3. Boya / değişen ve hasar kaydı</h2>
            <p className="text-sm text-metin-ikincil mt-1">İlandaki ekspertiz bilgisine göre parçaları işaretleyin. Boş bıraktıklarınız orijinal sayılır.</p>
            <div className="mt-4 grid gap-2 sm:grid-cols-2">
              {(meta?.parts || []).map((part) => {
                const value = parts[part.key] || "orijinal";
                return (
                  <div key={part.key} className="flex items-center justify-between gap-2 rounded-lg border border-kenarlik-acik px-3 py-2">
                    <span className="text-sm text-metin-birincil">{part.label}</span>
                    <select
                      aria-label={part.label}
                      value={value}
                      onChange={(e) => {
                        const next = e.target.value as PartStatus;
                        setParts((p) => {
                          const copy = { ...p };
                          if (next === "orijinal") delete copy[part.key];
                          else copy[part.key] = next;
                          return copy;
                        });
                      }}
                      className={`rounded-md border px-2 py-1 text-xs font-medium ${DURUM_RENK[value]}`}
                    >
                      {(meta?.statuses || []).map((s) => <option key={s.key} value={s.key}>{s.label}</option>)}
                    </select>
                  </div>
                );
              })}
            </div>
            <div className="mt-4 max-w-xs">
              <label className={label}>Tramer / hasar kaydı tutarı (₺)</label>
              <input type="number" min={0} value={form.tramer} onChange={set("tramer")} className={input} placeholder="0" />
            </div>
          </section>

          <button type="submit" disabled={busy !== null}
            className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
            {busy === "analyze" ? "Analiz ediliyor..." : `Analiz Et (${meta?.cost_credits ?? 1} kredi)`}
          </button>
        </form>
      )}
      <p className="mt-6 text-center text-xs text-metin-ikincil">Piyasa değeri internetteki güncel ilanlardan bulunur; yeterli ilan bulunamazsa analiz yapılmaz ve kredi düşülmez.</p>
    </div>
  );
}

function SonucKarti({ sonuc, onYeni }: { sonuc: ValuationResult; onYeni: () => void }) {
  const { arac, piyasa, degerleme, karar, getiri, ozet, bilgiKaynaklari } = sonuc;
  return (
    <div className="mt-8 space-y-6">
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

      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className="text-sm text-metin-ikincil">{sonuc.kredi.dusulen} kredi kullanıldı • Kalan: {sonuc.kredi.kalan}</span>
        <div className="flex gap-2">
          <Link href="/ekspertiz-talebi" className="rounded-lg border border-kenarlik-acik px-4 py-2 text-sm font-semibold text-metin-birincil">
            Bu araca ekspertiz yaptır
          </Link>
          <button type="button" onClick={onYeni} className="rounded-lg bg-birincil px-4 py-2 text-sm font-semibold text-white">Yeni analiz</button>
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
