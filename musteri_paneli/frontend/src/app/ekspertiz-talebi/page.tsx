"use client";

import Link from "next/link";
import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  createExpertizRequest,
  getExpertizPackages,
  getVehicleDetail,
  type ExpertizFirm,
  type ExpertizPackage,
  type VehicleCard,
} from "@/lib/api";
import { useAuth } from "@/kancalar/yetkiKullan";

function formatPrice(value: number): string {
  return new Intl.NumberFormat("tr-TR").format(Math.round(value)) + " TL";
}

function EkspertizTalebiIcerigi() {
  const params = useSearchParams();
  const { user, loading: authLoading } = useAuth();
  const listingId = Number(params.get("aracId") || 0);
  const [vehicle, setVehicle] = useState<VehicleCard | null>(null);
  const [firms, setFirms] = useState<ExpertizFirm[]>([]);
  const [serviceFee, setServiceFee] = useState(6500);
  const [vatRate, setVatRate] = useState(0.2);
  const [firmId, setFirmId] = useState("");
  const [packageId, setPackageId] = useState("");
  const [plate, setPlate] = useState("");
  const [city, setCity] = useState("");
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<string | null>(null);
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
        setVehicle(detail);
        setCity(detail?.location || "");
        if (packages.firms.length > 0) {
          setFirmId(packages.firms[0].id);
          setPackageId(packages.firms[0].packages[0]?.id || "");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "Veriler yuklenemedi");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [listingId]);

  const selectedFirm = useMemo(
    () => firms.find((firm) => firm.id === firmId) || null,
    [firms, firmId],
  );

  const selectedPackage = useMemo<ExpertizPackage | null>(
    () => selectedFirm?.packages.find((pkg) => pkg.id === packageId) || null,
    [selectedFirm, packageId],
  );

  const subtotal = serviceFee + (selectedPackage?.price || 0);
  const vat = subtotal * vatRate;
  const total = subtotal + vat;

  async function submit() {
    if (!user) {
      setError("Talep olusturmak icin giris yapmalisiniz.");
      return;
    }
    if (!selectedFirm || !selectedPackage) {
      setError("Lutfen kurumsal ekspertiz firmasi ve paket secin.");
      return;
    }
    setSubmitting(true);
    setError(null);
    setResult(null);
    try {
      const response = await createExpertizRequest({
        firm_id: selectedFirm.id,
        package_id: selectedPackage.id,
        listing_id: listingId || undefined,
        listing_url: vehicle?.url,
        plate,
        city,
        note,
      });
      setResult(`Talep olusturuldu: ${String(response.request_id || "")}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Talep olusturulamadi");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return <div className="max-w-5xl mx-auto px-6 py-12 text-metin-ikincil">Ekspertiz paketleri yukleniyor...</div>;
  }

  if (!authLoading && !user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Ekspertiz Talebi</h1>
        <p className="mt-3 text-metin-ikincil">
          Talep olusturmak ve rapor surecinizi panelden takip etmek icin giris yapin.
        </p>
        <div className="mt-6 flex flex-col justify-center gap-3 sm:flex-row">
          <Link href="/giris" className="rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
            Giris yap
          </Link>
          <Link href="/kayit-ol" className="rounded-lg border border-kenarlik-acik px-5 py-2.5 text-sm font-semibold text-metin-birincil">
            Uye ol
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-metin-birincil">Ekspertiz ve Raporlama Talebi</h1>
        <p className="text-metin-ikincil mt-1">YerimeBak hizmet bedeli + sectiginiz kurumsal ekspertiz paketi birlikte hesaplanir.</p>
      </div>

      {vehicle && (
        <div className="mb-6 bg-white border border-kenarlik-acik rounded-lg p-4">
          <div className="text-sm text-metin-ikincil">Secilen arac</div>
          <div className="mt-1 font-semibold text-metin-birincil">{vehicle.title || `${vehicle.brand} ${vehicle.model} ${vehicle.year}`}</div>
          <div className="mt-1 text-sm text-metin-ikincil">{formatPrice(vehicle.price)} • {vehicle.location || "Konum belirtilmedi"}</div>
        </div>
      )}

      <div className="grid lg:grid-cols-[1fr_360px] gap-6">
        <div className="space-y-6">
          <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
            <h2 className="text-lg font-semibold text-metin-birincil">Kurumsal firma secimi</h2>
            <div className="mt-4 grid sm:grid-cols-2 gap-3">
              {firms.map((firm) => (
                <button
                  key={firm.id}
                  type="button"
                  onClick={() => {
                    setFirmId(firm.id);
                    setPackageId(firm.packages[0]?.id || "");
                  }}
                  className={`text-left border rounded-lg p-4 transition-colors ${firm.id === firmId ? "border-birincil bg-blue-50" : "border-kenarlik-acik hover:border-birincil/40"}`}
                >
                  <div className="font-semibold text-metin-birincil">{firm.name}</div>
                  <div className="text-xs text-metin-ikincil mt-1">{firm.packages.length} paket</div>
                </button>
              ))}
            </div>
          </section>

          {selectedFirm && (
            <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
              <h2 className="text-lg font-semibold text-metin-birincil">Paket secimi</h2>
              <div className="mt-4 space-y-3">
                {selectedFirm.packages.map((pkg) => (
                  <button
                    key={pkg.id}
                    type="button"
                    onClick={() => setPackageId(pkg.id)}
                    className={`w-full text-left border rounded-lg p-4 transition-colors ${pkg.id === packageId ? "border-birincil bg-blue-50" : "border-kenarlik-acik hover:border-birincil/40"}`}
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="font-semibold text-metin-birincil">{pkg.name}</div>
                        <div className="mt-2 flex flex-wrap gap-2">
                          {pkg.features.map((feature) => (
                            <span key={feature} className="text-xs px-2 py-1 rounded bg-gray-100 text-metin-ikincil">{feature}</span>
                          ))}
                        </div>
                      </div>
                      <div className="font-bold text-metin-birincil whitespace-nowrap">{formatPrice(pkg.price)}</div>
                    </div>
                  </button>
                ))}
              </div>
            </section>
          )}

          <section className="bg-white border border-kenarlik-acik rounded-lg p-5">
            <h2 className="text-lg font-semibold text-metin-birincil">Talep bilgileri</h2>
            <div className="mt-4 grid sm:grid-cols-2 gap-4">
              <label className="block">
                <span className="text-sm text-metin-ikincil">Plaka</span>
                <input value={plate} onChange={(e) => setPlate(e.target.value)} className="mt-1 w-full border border-kenarlik-acik rounded-lg px-3 py-2" placeholder="34 ABC 123" />
              </label>
              <label className="block">
                <span className="text-sm text-metin-ikincil">Sehir / ilce</span>
                <input value={city} onChange={(e) => setCity(e.target.value)} className="mt-1 w-full border border-kenarlik-acik rounded-lg px-3 py-2" placeholder="Istanbul / Kadikoy" />
              </label>
            </div>
            <label className="block mt-4">
              <span className="text-sm text-metin-ikincil">Not</span>
              <textarea value={note} onChange={(e) => setNote(e.target.value)} className="mt-1 w-full border border-kenarlik-acik rounded-lg px-3 py-2" rows={3} placeholder="Satici ile randevu notu, arac linki veya ozel talep" />
            </label>
          </section>
        </div>

        <aside className="bg-white border border-kenarlik-acik rounded-lg p-5 h-fit sticky top-6">
          <h2 className="text-lg font-semibold text-metin-birincil">Odeme ozeti</h2>
          <div className="mt-4 space-y-3 text-sm">
            <div className="flex justify-between"><span>YerimeBak hizmet bedeli</span><strong>{formatPrice(serviceFee)}</strong></div>
            <div className="flex justify-between"><span>Kurumsal ekspertiz paketi</span><strong>{formatPrice(selectedPackage?.price || 0)}</strong></div>
            <div className="flex justify-between"><span>KDV</span><strong>{formatPrice(vat)}</strong></div>
            <div className="pt-3 border-t border-kenarlik-acik flex justify-between text-base">
              <span>Toplam</span>
              <strong>{formatPrice(total)}</strong>
            </div>
          </div>
          <button
            type="button"
            onClick={submit}
            disabled={submitting || !selectedPackage}
            className="mt-5 w-full bg-birincil text-white rounded-lg py-3 font-semibold disabled:opacity-50"
          >
            {submitting ? "Talep olusturuluyor..." : "Odeme Simulasyonu ile Talep Olustur"}
          </button>
          {result && (
            <div className="mt-4 rounded-lg bg-green-50 px-3 py-2 text-sm text-basarili">
              <div>{result}</div>
              <Link href="/panel" className="mt-2 inline-block font-semibold underline">
                Panelde takip et
              </Link>
            </div>
          )}
          {error && <div className="mt-4 text-sm text-tehlike">{error}</div>}
        </aside>
      </div>
    </div>
  );
}

export default function EkspertizTalebiSayfasi() {
  return (
    <Suspense fallback={<div className="max-w-5xl mx-auto px-6 py-12 text-metin-ikincil">Ekspertiz talebi hazirlaniyor...</div>}>
      <EkspertizTalebiIcerigi />
    </Suspense>
  );
}
