"use client";

import Link from "next/link";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import OdemeAlani from "@/bilesenler/OdemeAlani";
import { useAuth } from "@/kancalar/yetkiKullan";
import { ILLER } from "@/lib/iller";
import {
  createExpertizRequest,
  getExpertizPackages,
  getVehicleDetail,
  prefillValuation,
  type CheckoutStart,
  type CheckoutStatus,
  type ExpertizFirm,
  type ExpertizPackage,
} from "@/lib/api";

function tl(value: number) {
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 2 }).format(value) + " TL";
}

const ADIMLAR = ["Araç", "Hizmet Bedeli", "Ekspertiz Paketi", "Ödeme"];

const trLower = (v: string) => v.toLocaleLowerCase("tr-TR").trim();

/** Ilan konumundan ("İstanbul Kadıköy", "Kadıköy, İstanbul") il ve ilce cikarir. */
function konumAyir(location?: string | null): { city: string; district: string } {
  const text = (location || "").trim();
  if (!text) return { city: "", district: "" };
  const parts = text.split(/[/,-]|\s+/).map((p) => p.trim()).filter(Boolean);
  const city = ILLER.find((il) => parts.some((p) => trLower(p) === trLower(il))) || "";
  const district = city ? parts.filter((p) => trLower(p) !== trLower(city)).join(" ") : "";
  return { city, district };
}

interface Arac {
  link: string;
  brand: string;
  model: string;
  year: string;
  km: string;
  price: string;
  fuel: string;
  gear: string;
  plate: string;
  city: string;
  district: string;
  note: string;
}

const BOS_ARAC: Arac = { link: "", brand: "", model: "", year: "", km: "", price: "", fuel: "", gear: "", plate: "", city: "", district: "", note: "" };

function EkspertizTalebiIcerigi() {
  const params = useSearchParams();
  const { user, loading: authLoading } = useAuth();
  const listingId = Number(params.get("aracId") || 0);

  const [adim, setAdim] = useState(0);
  const [arac, setArac] = useState<Arac>(BOS_ARAC);
  const [firms, setFirms] = useState<ExpertizFirm[]>([]);
  const [serviceFee, setServiceFee] = useState(0);
  const [vatRate, setVatRate] = useState(0.2);
  const [firmId, setFirmId] = useState("");
  const [packageId, setPackageId] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [prefillMsg, setPrefillMsg] = useState<string | null>(null);
  const [checkout, setCheckout] = useState<CheckoutStart | null>(null);
  const [odendi, setOdendi] = useState<CheckoutStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const [packages, detail] = await Promise.all([
          getExpertizPackages(),
          listingId ? getVehicleDetail(listingId) : Promise.resolve(null),
        ]);
        setFirms(packages.firms);
        setServiceFee(packages.service_fee_tl);
        setVatRate(packages.vat_rate);
        if (detail) {
          setArac((a) => ({
            ...a,
            link: detail.url || "",
            brand: detail.brand || "",
            model: detail.model || "",
            year: detail.year ? String(detail.year) : "",
            km: detail.km ? String(detail.km) : "",
            price: detail.price ? String(detail.price) : "",
            fuel: detail.fuel || "",
            gear: detail.transmission || "",
            ...konumAyir(detail.location),
          }));
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "Veriler yüklenemedi");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [listingId]);

  const selectedFirm = useMemo(() => firms.find((f) => f.id === firmId) || null, [firms, firmId]);
  const selectedPackage = useMemo<ExpertizPackage | null>(
    () => selectedFirm?.packages.find((p) => p.id === packageId) || null,
    [selectedFirm, packageId],
  );
  const subtotal = serviceFee + (selectedPackage?.price || 0);
  const vat = Math.round(subtotal * vatRate * 100) / 100;
  const total = subtotal + vat;

  const set = (key: keyof Arac) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setArac((a) => ({ ...a, [key]: e.target.value }));

  async function linktenDoldur() {
    if (!arac.link.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const res = await prefillValuation(arac.link.trim());
      const v = res.vehicle || {};
      setArac((a) => ({
        ...a,
        brand: v.brand ?? a.brand,
        model: v.model ?? a.model,
        year: v.year != null ? String(v.year) : a.year,
        km: v.km != null ? String(v.km) : a.km,
        price: v.price != null ? String(v.price) : a.price,
        fuel: v.fuel ?? a.fuel,
        gear: v.transmission ?? a.gear,
        ...(a.city ? {} : konumAyir(v.location)),
      }));
      setPrefillMsg(res.message);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Link okunamadı");
    } finally {
      setBusy(false);
    }
  }

  function ilerle() {
    setError(null);
    if (adim === 0) {
      if (!arac.link.trim() && !(arac.brand.trim() && arac.model.trim())) {
        setError("İlan linkini paylaşın veya en az marka ve model girin.");
        return;
      }
      if (!arac.city.trim() || !arac.district.trim()) {
        setError("Aracın bulunduğu il ve ilçeyi girin; talebiniz bölgedeki uzmana yönlendirilir.");
        return;
      }
    }
    if (adim === 2 && !selectedPackage) {
      setError("Bir kurumsal ekspertiz paketi seçin.");
      return;
    }
    setAdim((a) => Math.min(a + 1, ADIMLAR.length - 1));
  }

  async function odemeyeGec() {
    if (!selectedFirm || !selectedPackage) return;
    setBusy(true);
    setError(null);
    try {
      const num = (v: string) => (v ? Number(v) : undefined);
      setCheckout(
        await createExpertizRequest({
          firm_id: selectedFirm.id,
          package_id: selectedPackage.id,
          listing_id: listingId || undefined,
          listing_url: arac.link.trim() || undefined,
          plate: arac.plate,
          city: arac.city,
          district: arac.district.trim(),
          note: arac.note,
          vehicle: {
            brand: arac.brand || undefined,
            model: arac.model || undefined,
            year: num(arac.year),
            km: num(arac.km),
            price: num(arac.price),
            fuel: arac.fuel || undefined,
            transmission: arac.gear || undefined,
          },
        }),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Ödeme başlatılamadı");
    } finally {
      setBusy(false);
    }
  }

  const odemeTamam = useCallback((s: CheckoutStatus) => setOdendi(s), []);
  const odemeBasarisiz = useCallback(() => setCheckout(null), []);

  if (loading) {
    return <div className="max-w-5xl mx-auto px-6 py-12 text-metin-ikincil">Ekspertiz paketleri yükleniyor...</div>;
  }

  if (!authLoading && !user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Ekspertiz Talebi</h1>
        <p className="mt-3 text-metin-ikincil">Talep oluşturmak ve rapor sürecinizi panelden takip etmek için giriş yapın.</p>
        <div className="mt-6 flex flex-col justify-center gap-3 sm:flex-row">
          <Link href="/giris" className="rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">Giriş yap</Link>
          <Link href="/kayit-ol" className="rounded-lg border border-kenarlik-acik px-5 py-2.5 text-sm font-semibold text-metin-birincil">Üye ol</Link>
        </div>
      </div>
    );
  }

  if (odendi) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-basarili">Ekspertiz talebiniz alındı</h1>
        <p className="mt-3 text-metin-birincil">
          Ödemeniz onaylandı ({tl(odendi.amount_tl)}). {odendi.firm_name} — {odendi.package_name} için ekspertiz personelimiz atanacak;
          süreci ve raporu panelinizden takip edebilirsiniz.
        </p>
        <Link href="/panel" className="mt-6 inline-block rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">Panelde takip et</Link>
      </div>
    );
  }

  const input = "mt-1 w-full border border-kenarlik-acik rounded-lg px-3 py-2";
  const lbl = "text-sm text-metin-ikincil";

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <h1 className="text-3xl font-bold text-metin-birincil">Ekspertiz ve Raporlama Talebi</h1>

      <ol className="mt-6 grid grid-cols-4 gap-2">
        {ADIMLAR.map((ad, i) => (
          <li key={ad} className={`rounded-lg border px-3 py-2 text-center text-xs font-semibold sm:text-sm ${
            i === adim ? "border-birincil bg-birincil/10 text-birincil-koyu" : i < adim ? "border-green-200 bg-green-50 text-basarili" : "border-kenarlik-acik text-metin-ikincil"
          }`}>
            {i + 1}. {ad}
          </li>
        ))}
      </ol>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_340px]">
        <div className="space-y-6">
          {adim === 0 && (
            <section className="bg-white border border-kenarlik-acik rounded-lg p-5 space-y-4">
              <div>
                <h2 className="text-lg font-semibold text-metin-birincil">Araç ilan linki</h2>
                <p className="text-sm text-metin-ikincil">Linki paylaşın, bilgileri dolduralım ya da aşağıya elle girin.</p>
                <div className="mt-2 flex gap-2">
                  <input value={arac.link} onChange={set("link")} className="w-full border border-kenarlik-acik rounded-lg px-3 py-2" placeholder="https://www.arabam.com/ilan/..." />
                  <button type="button" onClick={linktenDoldur} disabled={!arac.link.trim() || busy}
                    className="whitespace-nowrap rounded-lg border border-birincil px-4 py-2 text-sm font-semibold text-birincil disabled:opacity-50">
                    Linkten Doldur
                  </button>
                </div>
                {prefillMsg && <p className="mt-2 text-sm text-metin-ikincil">{prefillMsg}</p>}
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="block"><span className={lbl}>Marka</span><input value={arac.brand} onChange={set("brand")} className={input} placeholder="Renault" /></label>
                <label className="block"><span className={lbl}>Model</span><input value={arac.model} onChange={set("model")} className={input} placeholder="Clio" /></label>
                <label className="block"><span className={lbl}>Model yılı</span><input type="number" value={arac.year} onChange={set("year")} className={input} placeholder="2021" /></label>
                <label className="block"><span className={lbl}>Kilometre</span><input type="number" value={arac.km} onChange={set("km")} className={input} placeholder="65000" /></label>
                <label className="block"><span className={lbl}>İlan fiyatı (₺)</span><input type="number" value={arac.price} onChange={set("price")} className={input} placeholder="950000" /></label>
                <label className="block"><span className={lbl}>Plaka</span><input value={arac.plate} onChange={set("plate")} className={input} placeholder="34 ABC 123" /></label>
                <label className="block"><span className={lbl}>Yakıt</span>
                  <select value={arac.fuel} onChange={set("fuel")} className={input}>
                    <option value="">Seçiniz</option><option>Benzin</option><option>Dizel</option><option>Hibrit</option><option>Elektrik</option><option>LPG</option>
                  </select>
                </label>
                <label className="block"><span className={lbl}>Vites</span>
                  <select value={arac.gear} onChange={set("gear")} className={input}>
                    <option value="">Seçiniz</option><option>Otomatik</option><option>Manuel</option><option>Yarı Otomatik</option>
                  </select>
                </label>
                <label className="block"><span className={lbl}>Aracın bulunduğu il</span>
                  <select value={arac.city} onChange={set("city")} className={input}>
                    <option value="">İl seçiniz</option>
                    {ILLER.map((il) => <option key={il}>{il}</option>)}
                  </select>
                </label>
                <label className="block"><span className={lbl}>İlçe</span><input value={arac.district} onChange={set("district")} className={input} placeholder="Kadıköy" /></label>
              </div>
              <label className="block"><span className={lbl}>Not (satıcı randevusu, özel talep)</span>
                <textarea value={arac.note} onChange={set("note")} className={input} rows={3} />
              </label>
            </section>
          )}

          {adim === 1 && (
            <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
              <h2 className="text-lg font-semibold text-metin-birincil">YerimeBak hizmet bedeli</h2>
              <div className="mt-3 text-3xl font-bold text-metin-birincil">{tl(serviceFee)} <span className="text-sm font-normal text-metin-ikincil">+ KDV</span></div>
              <ul className="mt-4 space-y-2 text-sm text-metin-ikincil">
                <li>• Aracınıza bölgenizdeki YerimeBak ekspertiz personelinin atanması</li>
                <li>• Kurumsal ekspertiz firmasında randevu ve süreç takibi</li>
                <li>• Saha raporu, hasar fotoğrafları ve kurumsal rapor tek panelde</li>
                <li>• Ekspertiz bulgularına göre yapay zekâ değerlemesi ve tavsiye fiyat</li>
              </ul>
            </section>
          )}

          {adim === 2 && (
            <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
              <h2 className="text-lg font-semibold text-metin-birincil">Kurumsal ekspertiz firması ve paketi</h2>
              {firms.length === 0 && <p className="mt-3 text-sm text-metin-ikincil">Şu an seçilebilir firma yok.</p>}
              <div className="mt-4 space-y-4">
                {firms.map((firm) => (
                  <div key={firm.id} className="rounded-lg border border-kenarlik-acik p-4">
                    <div className="font-semibold text-metin-birincil">{firm.name}</div>
                    <div className="mt-3 grid gap-2 sm:grid-cols-2">
                      {firm.packages.map((pkg) => {
                        const active = firm.id === firmId && pkg.id === packageId;
                        return (
                          <button key={pkg.id} type="button"
                            onClick={() => { setFirmId(firm.id); setPackageId(pkg.id); }}
                            className={`text-left rounded-lg border p-3 transition-colors ${active ? "border-birincil bg-blue-50" : "border-kenarlik-acik hover:border-birincil/40"}`}>
                            <div className="flex items-start justify-between gap-2">
                              <span className="font-medium text-metin-birincil">{pkg.name}</span>
                              <span className="font-bold text-metin-birincil whitespace-nowrap">{tl(pkg.price)}</span>
                            </div>
                            {pkg.features.length > 0 && (
                              <div className="mt-2 flex flex-wrap gap-1">
                                {pkg.features.map((f) => <span key={f} className="rounded bg-gray-100 px-2 py-0.5 text-xs text-metin-ikincil">{f}</span>)}
                              </div>
                            )}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {adim === 3 && (
            <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
              <h2 className="text-lg font-semibold text-metin-birincil">Ödeme</h2>
              {checkout ? (
                <div className="mt-4"><OdemeAlani checkout={checkout} onPaid={odemeTamam} onFailed={odemeBasarisiz} /></div>
              ) : (
                <>
                  <p className="mt-1 text-sm text-metin-ikincil">
                    {arac.brand || arac.model ? `${arac.brand} ${arac.model} ${arac.year}`.trim() : arac.link} • {arac.city} / {arac.district}
                  </p>
                  <button type="button" onClick={odemeyeGec} disabled={busy || !selectedPackage}
                    className="mt-4 w-full rounded-lg bg-birincil py-3 font-semibold text-white disabled:opacity-50">
                    {busy ? "Ödeme hazırlanıyor..." : `${tl(total)} Öde`}
                  </button>
                  <p className="mt-2 text-xs text-metin-ikincil">Talebiniz ödeme onaylandığında işleme alınır.</p>
                </>
              )}
            </section>
          )}

          {error && <div className="text-sm text-tehlike">{error}</div>}

          {!checkout && (
            <div className="flex justify-between">
              <button type="button" onClick={() => { setError(null); setAdim((a) => Math.max(0, a - 1)); }} disabled={adim === 0}
                className="rounded-lg border border-kenarlik-acik px-5 py-2.5 text-sm font-semibold text-metin-birincil disabled:opacity-40">
                Geri
              </button>
              {adim < ADIMLAR.length - 1 && (
                <button type="button" onClick={ilerle} className="rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
                  Devam
                </button>
              )}
            </div>
          )}
        </div>

        <aside className="bg-white border border-kenarlik-acik rounded-lg p-5 h-fit lg:sticky lg:top-6">
          <h2 className="text-lg font-semibold text-metin-birincil">Ödeme özeti</h2>
          <div className="mt-4 space-y-3 text-sm">
            <div className="flex justify-between"><span>YerimeBak hizmet bedeli</span><strong>{tl(serviceFee)}</strong></div>
            <div className="flex justify-between gap-2">
              <span>{selectedPackage ? `${selectedFirm?.name} — ${selectedPackage.name}` : "Kurumsal ekspertiz paketi"}</span>
              <strong className="whitespace-nowrap">{tl(selectedPackage?.price || 0)}</strong>
            </div>
            <div className="flex justify-between"><span>KDV (%{Math.round(vatRate * 100)})</span><strong>{tl(vat)}</strong></div>
            <div className="pt-3 border-t border-kenarlik-acik flex justify-between text-base"><span>Toplam</span><strong>{tl(total)}</strong></div>
          </div>
        </aside>
      </div>
    </div>
  );
}

export default function EkspertizTalebiSayfasi() {
  return (
    <Suspense fallback={<div className="max-w-5xl mx-auto px-6 py-12 text-metin-ikincil">Ekspertiz talebi hazırlanıyor...</div>}>
      <EkspertizTalebiIcerigi />
    </Suspense>
  );
}
