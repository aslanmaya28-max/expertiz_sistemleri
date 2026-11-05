"use client";

import Link from "next/link";
import { tekrarliIstek } from "@/lib/tekrarliIstek";
import DegerlemeSonucu from "@/bilesenler/DegerlemeSonucu";
import EkspertizFotografi from "@/bilesenler/EkspertizFotografi";
import { fotoOnDolum } from "@/lib/ekspertizFotografi";
import { AnalizBekleme } from "@/bilesenler/AkilliAliciBolumleri";
import { AracSemasi, AramaliSecim, SayiAlani } from "@/bilesenler/AracFormAlanlari";
import { MARKALAR, degerlemeFormHatasi, modelleri } from "@/lib/aracFormu";
import { useEffect, useRef, useState } from "react";
import { notifyCreditsChanged, useAuth } from "@/kancalar/yetkiKullan";
import {
  ApiError,
  analyzeValuation,
  getCreditBalance,
  getValuationParts,
  getKasaBilgisi,
  type KasaBilgisi,
  prefillValuation,
  prefillValuationText,
  type PrefillField,
  type ValuationPrefill,
  type PartStatus,
  type ValuationPartsResponse,
  type ValuationResult,
  type InspectionPhotoResult,
} from "@/lib/api";

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
  package: string;
  location: string;
  hp: string;
}

const BOS_FORM: Form = { link: "", brand: "", model: "", year: "", km: "", price: "", fuel: "", gear: "", tramer: "", package: "", location: "", hp: "" };

export default function AracAnalizSayfasi() {
  const { user, loading: authLoading } = useAuth();
  const [form, setForm] = useState<Form>(BOS_FORM);
  const [meta, setMeta] = useState<ValuationPartsResponse | null>(null);
  const [parts, setParts] = useState<Record<string, PartStatus>>({});
  const [bakiye, setBakiye] = useState<number | null>(null);
  const [prefillMsg, setPrefillMsg] = useState<string | null>(null);
  const [origins, setOrigins] = useState<Record<string, PrefillField>>({});
  const [listingText, setListingText] = useState("");
  const [textOpen, setTextOpen] = useState(false);
  const [yapistirUyarisi, setYapistirUyarisi] = useState(false);
  const metinKutusu = useRef<HTMLTextAreaElement>(null);
  const [panoVar, setPanoVar] = useState(false);
  useEffect(() => {
    setPanoVar(typeof navigator !== "undefined" && !!navigator.clipboard?.readText);
  }, []);

  function metinKutusunaGit() {
    setTextOpen(true);
    // details açıldıktan sonra odaklan (telefonda klavye ve "Yapıştır" balonu açılır)
    window.setTimeout(() => {
      metinKutusu.current?.scrollIntoView({ behavior: "smooth", block: "center" });
      metinKutusu.current?.focus();
    }, 50);
  }

  async function panodanYapistir() {
    try {
      const metin = await navigator.clipboard.readText();
      if (metin.trim()) setListingText(metin.slice(0, 8000));
    } catch {
      metinKutusu.current?.focus();
    }
  }
  const [sonuc, setSonuc] = useState<ValuationResult | null>(null);
  const [hata, setHata] = useState<{ message: string; code?: string } | null>(null);
  const [busy, setBusy] = useState<"prefill" | "photo" | "analyze" | null>(null);
  const [photo, setPhoto] = useState<InspectionPhotoResult | null>(null);
  const [belirsiz, setBelirsiz] = useState<string[]>([]);
  const [photoChecked, setPhotoChecked] = useState(false);

  function resetPhoto() {
    setPhoto(null); setBelirsiz([]); setPhotoChecked(false);
    setParts({}); setForm((previous) => ({ ...previous, tramer: "" }));
    setOrigins((previous) => Object.fromEntries(Object.entries(previous).filter(([key]) => !key.startsWith("parts.") && key !== "tramer_amount")));
  }
  function applyPhoto(result: InspectionPhotoResult) {
    const values = fotoOnDolum(result, (meta?.parts || []).map((part) => part.key));
    setPhoto(result); setPhotoChecked(false); setBelirsiz(values.belirsiz);
    setParts(values.parts); setForm((previous) => ({ ...previous, tramer: values.tramer }));
    setOrigins((previous) => ({ ...Object.fromEntries(Object.entries(previous).filter(([key]) => !key.startsWith("parts.") && key !== "tramer_amount")), ...values.origins }));
  }
  // Kasa geçiş yılı: araç yılı iki kasaya denk geliyorsa müşteriye sorulur (ör. 2021 Tucson: TL / NX4)
  const [kasaBilgisi, setKasaBilgisi] = useState<KasaBilgisi | null>(null);
  const [kasa, setKasa] = useState<"" | "yeni" | "eski">("");
  const kasaOnbellek = useRef(new Map<string, KasaBilgisi | null>());
  useEffect(() => {
    const brand = form.brand.trim(), model = form.model.trim();
    const anahtar = `${brand}|${model}|${form.year}`.toLocaleLowerCase("tr");
    setKasa("");
    if (!user || !brand || !model || !/^\d{4}$/.test(form.year)) { setKasaBilgisi(null); return; }
    if (kasaOnbellek.current.has(anahtar)) { setKasaBilgisi(kasaOnbellek.current.get(anahtar) ?? null); return; }
    const t = window.setTimeout(() => {
      getKasaBilgisi(brand, model, Number(form.year))
        .then((b) => { kasaOnbellek.current.set(anahtar, b); setKasaBilgisi(b); })
        .catch(() => setKasaBilgisi(null));
    }, 800);
    return () => window.clearTimeout(t);
  }, [form.brand, form.model, form.year, user]);

  useEffect(() => {
    getValuationParts().then(setMeta).catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!user) return;
    getCreditBalance().then((b) => setBakiye(b.credits)).catch(() => undefined);
  }, [user]);

  const originKey = (key: string) => (({ gear: "transmission", tramer: "tramer_amount" } as Record<string, string>)[key] || key);
  const clearOrigin = (key: string) => setOrigins((o) => {
    const next = { ...o };
    delete next[originKey(key)];
    return next;
  });
  const set = (key: keyof Form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setValue(key)(e.target.value);
  const setValue = (key: keyof Form) => (value: string) => {
    if (key === "tramer") setPhotoChecked(false);
    clearOrigin(key);
    setForm((f) => ({ ...f, [key]: value }));
  };
  function parcaDegistir(parca: string, durum: PartStatus) {
    setBelirsiz((previous) => previous.filter((key) => key !== parca));
    setPhotoChecked(false);
    clearOrigin(`parts.${parca}`);
    setParts((p) => {
      const copy = { ...p };
      if (durum === "orijinal") delete copy[parca];
      else copy[parca] = durum;
      return copy;
    });
  }

  function badge(key: string) {
    const source = origins[originKey(key)];
    if (!source) return null;
    return <span className={`ml-2 inline-block rounded px-1.5 py-0.5 text-xs ${source.dogrulandi ? "bg-green-50 text-green-800" : "bg-yellow-50 text-yellow-800"}`}>
      {source.kaynak === "ekspertiz_raporu" ? "Ekspertiz raporundan — kontrol edin" : source.dogrulandi ? (source.kaynak === "ilan_metni" ? "İlan metninden alındı" : "İlandan alındı") : source.kaynak === "link_kelimeleri" ? "Linkten tahmin — kontrol edin" : "Kayıtlı bilgi — kontrol edin"}
    </span>;
  }

  function applyPrefill(res: ValuationPrefill) {
    if (res.paste_text) {
      // Sahibinden: alanlara dokunma (müşterinin girdikleri kalsın), metin kutusuna yönlendir
      setForm((f) => ({ ...f, link: res.url || f.link }));
      setPrefillMsg(res.message);
      setYapistirUyarisi(true);
      metinKutusunaGit();
      return;
    }
    setYapistirUyarisi(false);
    setPhoto(null); setBelirsiz([]); setPhotoChecked(false);
    const v = res.vehicle || {};
    // Her çıkarım yeni bir ilanı temsil eder: önceki ilandan eksik alan taşınmaz.
    setForm((f) => ({
      ...f, link: res.url || f.link,
      brand: v.brand ?? "", model: v.model ?? "",
      year: v.year != null ? String(v.year) : "", km: v.km != null ? String(v.km) : "",
      price: v.price != null ? String(v.price) : "", fuel: v.fuel ?? "", gear: v.transmission ?? "",
      tramer: v.tramer_amount != null ? String(v.tramer_amount) : "",
      package: v.package ?? "", location: v.location ?? "", hp: v.hp != null ? String(v.hp) : "",
    }));
    setParts(res.parts || {});
    setOrigins(res.fields || {});
    setPrefillMsg(res.message);
    setTextOpen(!res.verified_count);
  }

  async function linktenDoldur() {
    if (!form.link.trim()) return;
    setBusy("prefill");
    setHata(null);
    setPrefillMsg(null);
    try {
      applyPrefill(await prefillValuation(form.link.trim()));
    } catch (err) {
      setHata({ message: err instanceof Error ? err.message : "Link okunamadı" });
      setTextOpen(true);
    } finally {
      setBusy(null);
    }
  }

  async function metindenDoldur() {
    setBusy("prefill");
    setHata(null);
    try {
      applyPrefill(await prefillValuationText(listingText.trim()));
    } catch (err) {
      setHata({ message: err instanceof Error ? err.message : "Metin okunamadı" });
    } finally {
      setBusy(null);
    }
  }

  const analyzeInFlight = useRef(false);

  async function analizEt(e: React.FormEvent) {
    e.preventDefault();
    if (analyzeInFlight.current) return;
    analyzeInFlight.current = true;
    setBusy("analyze");
    setHata(null);
    setSonuc(null);
    try {
      const formHatasi = degerlemeFormHatasi(form);
      if (formHatasi) {
        setHata({ message: formHatasi });
        window.scrollTo({ top: 0, behavior: "smooth" });
        return;
      }
      if (photo && (belirsiz.length || !form.tramer || !photoChecked)) {
        setHata({ message: "Raporda okunmayan parçaların durumunu ve tramer tutarını kontrol edin; ardından bilgileri onaylayın." });
        return;
      }
      // Aynı istek numarasıyla yeniden sormak raporu yeniden üretmez, krediyi ikinci kez düşmez.
      const istek = {
        request_id: crypto.randomUUID(),
        listing_url: form.link.trim() || undefined,
        brand: form.brand || undefined,
        model: form.model || undefined,
        package: form.package || undefined,
        hp: form.hp ? Number(form.hp) : undefined,
        year: form.year ? Number(form.year) : undefined,
        km: form.km ? Number(form.km) : undefined,
        listed_price: form.price ? Number(form.price) : undefined,
        fuel: form.fuel || undefined,
        transmission: form.gear || undefined,
        parts,
        tramer_amount: form.tramer ? Number(form.tramer) : 0,
        kasa: kasaBilgisi?.gecisYili && kasa ? kasa : undefined,
        kaynak_turu: photo ? "ekspertiz_raporu" as const : "musteri" as const,
        bulgular: photo?.bulgular,
        tramer_count: photo?.tramer_count ?? undefined,
        ekspertiz_firma_adi: photo?.firma_adi ?? undefined,
        ekspertiz_rapor_tarihi: photo?.rapor_tarihi ?? undefined,
      };
      const res = await tekrarliIstek(() => analyzeValuation(istek));
      setSonuc(res);
      setBakiye(res.kredi.kalan);
      notifyCreditsChanged();
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setHata({ message: err instanceof Error ? err.message : "Analiz başarısız", code: err instanceof ApiError ? err.code : undefined });
      window.scrollTo({ top: 0, behavior: "smooth" });
    } finally {
      analyzeInFlight.current = false;
      setBusy(null);
    }
  }

  if (!authLoading && !user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Araç Değerleme</h1>
        <p className="mt-3 text-metin-ikincil">Beğendiğiniz aracın gerçek değerini öğrenmek için giriş yapın. Raporda neler olduğunu görmek için <Link href="/ornek-rapor" className="text-birincil underline">örnek raporu inceleyin</Link>.</p>
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
            Piyasa ortalaması, boya/değişen/hasar değer kaybı, tavsiye fiyat ve pazarlık planı.
          </p>
        </div>
        <div className="text-sm text-metin-ikincil">
          Bakiye: <strong className="text-metin-birincil">{bakiye ?? "-"} kredi</strong>{" "}
          <Link href="/kredi-yukle" className="ml-2 font-semibold text-birincil underline">Kredi yükle</Link>
        </div>
      </div>

      {sonuc && <DegerlemeSonucu sonuc={sonuc} onYeni={() => setSonuc(null)} />}

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
                {busy === "prefill" ? "Okunuyor..." : "Bilgileri getir"}
              </button>
            </div>
            {prefillMsg && (
              <p className={yapistirUyarisi ? "mt-3 rounded-lg bg-yellow-50 p-3 text-sm font-medium text-yellow-900" : "mt-2 text-sm text-metin-ikincil"}>
                {prefillMsg}
              </p>
            )}
            <details className="mt-3 text-sm" open={textOpen} onToggle={(e) => setTextOpen(e.currentTarget.open)}>
              <summary className="cursor-pointer font-medium text-birincil">İlan metnini yapıştırın</summary>
              {yapistirUyarisi && (
                <p className="mt-2 text-xs text-metin-ikincil">
                  Telefonda: ilanı tarayıcıda açın, fiyattan açıklamanın sonuna kadar metne uzun basıp seçin ve Kopyala&apos;ya dokunun; sonra buraya dönüp yapıştırın.
                </p>
              )}
              <textarea ref={metinKutusu} aria-label="İlan metni" maxLength={8000} rows={6} value={listingText}
                onChange={(e) => setListingText(e.target.value)} className={`${input} mt-3`} placeholder="İlandaki araç bilgilerini ve açıklamayı buraya yapıştırın." />
              <div className="mt-2 flex flex-wrap gap-2">
                {panoVar && (
                  <button type="button" onClick={panodanYapistir} disabled={busy !== null}
                    className="rounded-lg border border-kenarlik-acik px-4 py-2 font-semibold text-metin-birincil disabled:opacity-50">Kopyaladığımı yapıştır</button>
                )}
                <button type="button" disabled={busy !== null || !listingText.trim()} onClick={metindenDoldur}
                  className="rounded-lg border border-birincil px-4 py-2 font-semibold text-birincil disabled:opacity-50">Metinden doldur</button>
              </div>
            </details>
          </section>

          <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
            <h2 className="text-lg font-semibold text-metin-birincil">2. Araç bilgileri</h2>
            <div className="mt-4 grid grid-cols-2 gap-4">
              <div><label className={label}>Paket / motor{badge("package")}</label><input value={form.package} onChange={set("package")} className={input} /></div>
              <div><label className={label}>Motor gücü (hp, isteğe bağlı){badge("hp")}</label><SayiAlani ariaLabel="Motor gücü" binlik={false} enFazlaHane={3} value={form.hp} onChange={setValue("hp")} className={input} placeholder="ör. 170" /></div>
              <div><label className={label}>Şehir{badge("location")}</label><input value={form.location} onChange={set("location")} className={input} /></div>
              <div><label className={label}>Marka{badge("brand")}</label><AramaliSecim required ariaLabel="Marka" value={form.brand} onChange={setValue("brand")} secenekler={MARKALAR} className={input} placeholder="Marka yazın veya seçin" /></div>
              <div><label className={label}>Model{badge("model")}</label><AramaliSecim required ariaLabel="Model" value={form.model} onChange={setValue("model")} secenekler={modelleri(form.brand)} className={input} placeholder={form.brand ? "Model yazın veya seçin" : "Önce marka"} /></div>
              <div><label className={label}>Model yılı{badge("year")}</label><SayiAlani required ariaLabel="Model yılı" binlik={false} enFazlaHane={4} value={form.year} onChange={setValue("year")} className={input} placeholder="2020" /></div>
              <div><label className={label}>Kilometre{badge("km")}</label><SayiAlani required ariaLabel="Kilometre" enFazlaHane={7} value={form.km} onChange={setValue("km")} className={input} placeholder="85.000" /></div>
              {kasaBilgisi?.gecisYili && (
                <div className="col-span-2 rounded-lg border border-yellow-300 bg-yellow-50 p-4" role="group" aria-label="Kasa seçimi">
                  <p className="text-sm font-medium text-yellow-900">{form.year} yılı {form.model} için kasa geçiş yılıdır: o yıl iki farklı kasa satıldı. Aracınız hangi kasa?</p>
                  <div className="mt-2 flex flex-wrap gap-2">
                    {[...kasaBilgisi.secenekler.map((s) => ({ kod: s.kod as "" | "yeni" | "eski", ad: `${s.kasa || (s.kod === "yeni" ? "Yeni kasa" : "Önceki kasa")} (${s.baslangic ?? "?"}–${s.bitis && s.bitis < new Date().getFullYear() ? s.bitis : ""})` })),
                      { kod: "" as const, ad: "Bilmiyorum" }].map((o) => (
                      <button key={o.kod || "bilmiyorum"} type="button" onClick={() => setKasa(o.kod)} aria-pressed={kasa === o.kod}
                        className={`rounded-full border px-3 py-1.5 text-sm font-semibold ${kasa === o.kod ? "border-birincil bg-birincil text-white" : "border-kenarlik-acik bg-white text-metin-birincil"}`}>
                        {o.ad}
                      </button>
                    ))}
                  </div>
                  <p className="mt-2 text-xs text-yellow-900">Bilmiyorsanız sorun değil: raporda iki kasanın fiyatını da ayrı ayrı gösteririz.</p>
                </div>
              )}
              <div>
                <label className={label}>Yakıt{badge("fuel")}</label>
                <select value={form.fuel} onChange={set("fuel")} className={input}>
                  {form.fuel && !["Benzin", "Dizel", "Hibrit", "Elektrik", "LPG"].includes(form.fuel) && <option>{form.fuel}</option>}
                  <option value="">Seçiniz</option><option>Benzin</option><option>Dizel</option><option>Hibrit</option><option>Elektrik</option><option>LPG</option>
                </select>
              </div>
              <div>
                <label className={label}>Vites{badge("gear")}</label>
                <select value={form.gear} onChange={set("gear")} className={input}>
                  {form.gear && !["Otomatik", "Manuel", "Yarı Otomatik"].includes(form.gear) && <option>{form.gear}</option>}
                  <option value="">Seçiniz</option><option>Otomatik</option><option>Manuel</option><option>Yarı Otomatik</option>
                </select>
              </div>
              <div className="col-span-2"><label className={label}>İlan fiyatı (₺){badge("price")}</label><SayiAlani required ariaLabel="İlan fiyatı" enFazlaHane={10} value={form.price} onChange={setValue("price")} className={input} placeholder="1.250.000" /></div>
            </div>
          </section>

          <EkspertizFotografi key={user?.id} disabled={busy !== null || !meta} onBusy={(value) => setBusy(value ? "photo" : null)} onApply={applyPhoto} onReset={resetPhoto}
            labels={Object.fromEntries((meta?.parts || []).map((part) => [part.key, part.label]))} />
          <section className="bg-white rounded-xl border border-kenarlik-acik p-6">
            <h2 className="text-lg font-semibold text-metin-birincil">3. Boya / değişen ve hasar kaydı</h2>
            <p className="text-sm text-metin-ikincil mt-1">{photo ? "Okunmayan parçalar belirtilmedi olarak kalır. Her eksik parçanın durumunu kendiniz doğrulayın ve şemada işaretleyin." : "İlandaki ekspertiz bilgisine göre parçaları araç üzerinde işaretleyin. İşaretlemedikleriniz orijinal sayılır."}</p>
            {(["painted_count", "changed_count"] as const).map((key) => origins[key] && (
              <p className="mt-2 text-sm" key={key}>{key === "painted_count" ? "Boyalı" : "Değişen"} parça sayısı: {origins[key].deger}{badge(key)}. Hangi parçalar olduğunu aşağıdan kontrol edin.</p>
            ))}
            <div className="mt-4">
              <AracSemasi
                parcalar={parts}
                etiketler={Object.fromEntries((meta?.parts || []).map((p) => [p.key, p.label]))}
                onDegistir={parcaDegistir}
                belirsiz={belirsiz}
                rozet={(k) => badge(`parts.${k}`)}
              />
            </div>
            {photo && <div className="mt-4 space-y-2 text-sm">
              <p className="font-medium">Kaynak: ekspertiz raporundan — YerimeBak uzmanı tarafından doğrulanmadı.</p>
              {belirsiz.length > 0 && <p role="alert">Durumu kontrol edilmesi gereken parçalar: {belirsiz.map((key) => meta?.parts.find((part) => part.key === key)?.label || key).join(", ")}. Orijinal ise şemada Orijinal seçip parçaya dokunun.</p>}
              {photo.bulgular.filter((item) => item.ciddiyet === "ciddi").map((item, index) => <p key={index} className="rounded-lg bg-red-50 p-3 text-tehlike">Ciddi bulgu: {item.metin}. Satın almadan önce yerinde doğrulatın.</p>)}
              <p>Tramer okunmadıysa kendiniz doğrulayın; hasar kaydı yoksa açıkça 0 girin.</p>
              <label className="flex items-start gap-2"><input type="checkbox" checked={photoChecked} disabled={belirsiz.length > 0 || !form.tramer} onChange={(event) => setPhotoChecked(event.target.checked)} />
                <span>Parçaları, trameri ve rapordan okunan bulguları kontrol ettim. Düzelttiğim/eksik alanları kendi beyanımla tamamladım.</span></label>
              <button type="button" onClick={resetPhoto} className="text-birincil underline">Fotoğraf bilgilerini kaldır ve elle doldur</button>
            </div>}
            <div className="mt-4 max-w-xs">
              <label className={label}>Tramer / hasar kaydı tutarı (₺){badge("tramer")}</label>
              <SayiAlani ariaLabel="Tramer tutarı" enFazlaHane={9} value={form.tramer} onChange={setValue("tramer")} className={input} placeholder="0" />
            </div>
          </section>

          <button type="submit" disabled={busy !== null}
            className="w-full py-3 bg-birincil text-white font-medium rounded-lg hover:bg-birincil-koyu transition-colors disabled:opacity-50">
            {busy === "analyze" ? "Analiz ediliyor..." : `Analiz Et (${meta?.cost_credits ?? 1} kredi)`}
          </button>
          {busy === "analyze" && <AnalizBekleme />}
        </form>
      )}
      <p className="mt-6 text-center text-xs text-metin-ikincil">Piyasa değeri internetteki güncel ilanlardan bulunur; yeterli ilan bulunamazsa analiz yapılmaz ve kredi düşülmez.</p>
    </div>
  );
}
