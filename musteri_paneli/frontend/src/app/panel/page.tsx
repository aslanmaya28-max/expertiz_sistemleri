"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import {
  getAnalysisHistory,
  getCreditBalance,
  getFavorites,
  getMyExpertizReports,
  getMyExpertizRequests,
  getProfile,
  removeFavorite,
  updateProfile,
  type AnalysisHistoryItem,
  type CreditBalanceResponse,
  type CustomerProfile,
  type ExpertizReportSummary,
  type ExpertizRequestSummary,
  type FavoriteVehicle,
} from "@/lib/api";
import { useAuth } from "@/kancalar/yetkiKullan";

type PanelTab = "ozet" | "analizler" | "ekspertiz" | "raporlar" | "favoriler" | "krediler" | "profil";

const tabs: { id: PanelTab; label: string }[] = [
  { id: "ozet", label: "Ozet" },
  { id: "analizler", label: "Analizlerim" },
  { id: "ekspertiz", label: "Ekspertiz Taleplerim" },
  { id: "raporlar", label: "Raporlarim" },
  { id: "favoriler", label: "Favoriler" },
  { id: "krediler", label: "Krediler" },
  { id: "profil", label: "Profil" },
];

function formatPrice(value?: number | null): string {
  if (!value) return "-";
  return new Intl.NumberFormat("tr-TR").format(Math.round(value)) + " TL";
}

function formatDate(value?: string): string {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function statusLabel(status?: string): { text: string; cls: string } {
  switch (status) {
    case "published":
      return { text: "Yayinlandi", cls: "bg-green-100 text-green-700" };
    case "pending_admin":
      return { text: "Admin onayinda", cls: "bg-orange-100 text-orange-700" };
    case "pending_ai":
      return { text: "AI analizinde", cls: "bg-blue-100 text-blue-700" };
    case "rejected":
      return { text: "Duzeltme gerekli", cls: "bg-red-100 text-red-700" };
    case "draft":
      return { text: "Islemde", cls: "bg-gray-100 text-gray-700" };
    case "payment_pending":
      return { text: "Odeme bekliyor", cls: "bg-yellow-100 text-yellow-800" };
    case "payment_failed":
      return { text: "Odeme basarisiz", cls: "bg-red-100 text-red-700" };
    default:
      return { text: status || "Bilinmiyor", cls: "bg-gray-100 text-gray-700" };
  }
}

function parseJsonField(value: AnalysisHistoryItem["vehicle_json"]): Record<string, unknown> {
  if (!value) return {};
  if (typeof value === "object") return value;
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function textValue(value: unknown, fallback = "-"): string {
  return typeof value === "string" && value.trim() ? value : fallback;
}

export default function MusteriPaneli() {
  const { user, loading } = useAuth();
  const [activeTab, setActiveTab] = useState<PanelTab>("ozet");
  const [requests, setRequests] = useState<ExpertizRequestSummary[]>([]);
  const [reports, setReports] = useState<ExpertizReportSummary[]>([]);
  const [history, setHistory] = useState<AnalysisHistoryItem[]>([]);
  const [favorites, setFavorites] = useState<FavoriteVehicle[]>([]);
  const [balance, setBalance] = useState<CreditBalanceResponse | null>(null);
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [dataLoading, setDataLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;

    async function loadPanel() {
      setDataLoading(true);
      setError(null);
      try {
        const [requestResult, reportResult, historyResult, balanceResult, favoritesResult, profileResult] = await Promise.all([
          getMyExpertizRequests(),
          getMyExpertizReports(),
          getAnalysisHistory(),
          getCreditBalance(),
          getFavorites(),
          getProfile(),
        ]);
        setRequests(requestResult.requests || []);
        setReports(reportResult.reports || []);
        setHistory(historyResult.history || []);
        setBalance(balanceResult);
        setFavorites(favoritesResult.favorites || []);
        setProfile(profileResult.profile);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Panel verileri yuklenemedi");
      } finally {
        setDataLoading(false);
      }
    }

    loadPanel();
  }, [user]);

  const activeRequests = useMemo(
    () => requests.filter((item) => item.status !== "published" && item.status !== "rejected"),
    [requests],
  );
  const latestRequests = requests.slice(0, 4);
  const latestReports = reports.slice(0, 4);
  const latestHistory = history.slice(0, 5);
  const latestFavorites = favorites.slice(0, 4);
  const creditCount = balance?.credits ?? user?.credits ?? 0;

  async function handleRemoveFavorite(listingId: number) {
    await removeFavorite(listingId);
    setFavorites((current) => current.filter((vehicle) => vehicle.id !== listingId));
  }

  if (loading) {
    return <div className="max-w-6xl mx-auto px-4 py-12 text-metin-ikincil">Panel yukleniyor...</div>;
  }

  if (!user) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Musteri Paneli</h1>
        <p className="mt-3 text-metin-ikincil">
          Analizlerinizi, ekspertiz taleplerinizi ve raporlarinizi takip etmek icin giris yapin.
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
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-metin-birincil">Musteri Paneli</h1>
          <p className="text-metin-ikincil mt-1">{user.email} hesabinizla arac analizlerinizi ve ekspertiz surecinizi yonetin.</p>
        </div>
        <div className="flex flex-col gap-2 sm:flex-row">
          <Link href="/arac-analiz" className="inline-flex justify-center rounded-lg border border-kenarlik-acik px-4 py-2 text-sm font-semibold text-metin-birincil">
            Arac analiz et
          </Link>
          <Link href="/ekspertiz-talebi" className="inline-flex justify-center rounded-lg bg-birincil px-4 py-2 text-sm font-semibold text-white">
            Yeni ekspertiz talebi
          </Link>
        </div>
      </div>

      {error && (
        <div className="mt-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <SummaryCard label="Aktif ekspertiz" value={activeRequests.length.toString()} hint="Sureci devam eden talepler" />
        <SummaryCard label="Yayinlanan rapor" value={reports.length.toString()} hint="Musteriye acik raporlar" />
        <SummaryCard label="Analiz gecmisi" value={history.length.toString()} hint="Krediyle yapilan analizler" />
        <SummaryCard label="Favori arac" value={favorites.length.toString()} hint="Takip edilen vitrin araclari" />
        <SummaryCard label="Kredi bakiyesi" value={String(creditCount)} hint={balance?.tier ? `${balance.tier} paket` : "Kullanilabilir bakiye"} />
      </div>

      <div className="mt-6 overflow-x-auto border-b border-kenarlik-acik">
        <div className="flex min-w-max gap-2">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`border-b-2 px-4 py-3 text-sm font-semibold transition ${
                activeTab === tab.id
                  ? "border-birincil text-birincil"
                  : "border-transparent text-metin-ikincil hover:text-metin-birincil"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {dataLoading ? (
        <div className="mt-10 text-center text-metin-ikincil">Veriler yukleniyor...</div>
      ) : (
        <div className="mt-6">
          {activeTab === "ozet" && (
            <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
              <PanelSection title="Son Analizler" count={latestHistory.length}>
                {latestHistory.length === 0 ? <EmptyState text="Henuz arac analizi yok." /> : latestHistory.map((item) => <AnalysisRow key={item.id} item={item} />)}
              </PanelSection>
              <PanelSection title="Aktif Ekspertiz Talepleri" count={latestRequests.length}>
                {latestRequests.length === 0 ? <EmptyState text="Aktif ekspertiz talebiniz yok." /> : latestRequests.map((request) => <RequestRow key={request.id} request={request} />)}
              </PanelSection>
              <PanelSection title="Yayinlanan Raporlar" count={latestReports.length}>
                {latestReports.length === 0 ? <EmptyState text="Onaylanmis raporunuz hazir oldugunda burada gorunur." /> : latestReports.map((report) => <ReportRow key={report.id} report={report} />)}
              </PanelSection>
              <PanelSection title="Favori Araclar" count={latestFavorites.length}>
                {latestFavorites.length === 0 ? <EmptyState text="Vitrinden kaydettiginiz araclar burada gorunur." /> : latestFavorites.map((vehicle) => <FavoriteRow key={vehicle.id} vehicle={vehicle} onRemove={handleRemoveFavorite} />)}
              </PanelSection>
              <QuickActions credits={creditCount} />
            </div>
          )}

          {activeTab === "analizler" && (
            <PanelSection title="Analizlerim" count={history.length}>
              {history.length === 0 ? <EmptyState text="Chrome uzantisi, link analizi veya panel analizleriniz burada listelenecek." /> : history.map((item) => <AnalysisRow key={item.id} item={item} />)}
            </PanelSection>
          )}

          {activeTab === "ekspertiz" && (
            <PanelSection title="Ekspertiz Taleplerim" count={requests.length}>
              {requests.length === 0 ? <EmptyState text="Henuz ekspertiz talebiniz yok." /> : requests.map((request) => <RequestRow key={request.id} request={request} />)}
            </PanelSection>
          )}

          {activeTab === "raporlar" && (
            <PanelSection title="Raporlarim" count={reports.length}>
              {reports.length === 0 ? <EmptyState text="Yayinlanan raporunuz hazir oldugunda burada gorunur." /> : reports.map((report) => <ReportRow key={report.id} report={report} />)}
            </PanelSection>
          )}

          {activeTab === "favoriler" && (
            <PanelSection title="Favori Araclarim" count={favorites.length}>
              {favorites.length === 0 ? <EmptyState text="Vitrindeki araclari favoriye eklediginizde burada takip edebilirsiniz." /> : favorites.map((vehicle) => <FavoriteRow key={vehicle.id} vehicle={vehicle} onRemove={handleRemoveFavorite} />)}
            </PanelSection>
          )}

          {activeTab === "krediler" && <CreditPanel balance={balance} historyCount={history.length} />}

          {activeTab === "profil" && <ProfilePanel profile={profile} email={user.email} credits={creditCount} tier={balance?.tier} role={balance?.role} onSaved={setProfile} />}
        </div>
      )}
    </div>
  );
}

function SummaryCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-lg border border-kenarlik-acik bg-white p-5">
      <div className="text-sm text-metin-ikincil">{label}</div>
      <div className="mt-2 text-3xl font-bold text-metin-birincil">{value}</div>
      <div className="mt-2 text-xs text-metin-ikincil">{hint}</div>
    </div>
  );
}

function PanelSection({ title, count, children }: { title: string; count?: number; children: React.ReactNode }) {
  return (
    <section className="rounded-lg border border-kenarlik-acik bg-white p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-lg font-semibold text-metin-birincil">{title}</h2>
        {typeof count === "number" && <span className="text-xs text-metin-ikincil">{count} kayit</span>}
      </div>
      <div className="mt-4 space-y-3">{children}</div>
    </section>
  );
}

function EmptyState({ text }: { text: string }) {
  return <div className="rounded-lg bg-gray-50 px-4 py-8 text-center text-sm text-metin-ikincil">{text}</div>;
}

function AnalysisRow({ item }: { item: AnalysisHistoryItem }) {
  const vehicle = parseJsonField(item.vehicle_json);
  const valuation = parseJsonField(item.valuation_json);
  const vehicleName = [vehicle.brand, vehicle.model, vehicle.year].filter(Boolean).join(" ");
  const description = textValue(vehicle.description, "");
  const title = vehicleName || description || textValue(vehicle.make_model, "Arac analizi");
  const credits = typeof valuation.credits_deducted === "number" ? valuation.credits_deducted : 1;
  const listedPrice = typeof vehicle.listed_price === "number" ? vehicle.listed_price : undefined;
  const marketPrice = typeof vehicle.market_price_avg === "number" ? vehicle.market_price_avg : undefined;
  const decision = textValue(valuation.decision, "Analiz");
  const score = typeof valuation.opportunity_score === "number" ? Math.round(valuation.opportunity_score) : null;

  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <div className="font-semibold text-metin-birincil">{title}</div>
          <div className="mt-1 text-sm text-metin-ikincil">{textValue(vehicle.source, "panel")} / {formatDate(item.created_at)}</div>
        </div>
        <span className="w-fit rounded-full bg-blue-100 px-2.5 py-1 text-xs font-semibold text-blue-700">{decision}{score !== null ? ` / ${score}` : ""}</span>
      </div>
      <div className="mt-3 grid gap-2 text-xs text-metin-ikincil sm:grid-cols-3">
        <span>Fiyat: {formatPrice(listedPrice)}</span>
        <span>Piyasa: {formatPrice(marketPrice)}</span>
        <span>Kredi: {credits}</span>
      </div>
    </div>
  );
}

function RequestRow({ request }: { request: ExpertizRequestSummary }) {
  const status = statusLabel(request.status);
  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-semibold text-metin-birincil">{request.plate || "Plaka bekleniyor"}</div>
          <div className="mt-1 text-sm text-metin-ikincil">{request.firm_name || "-"} / {request.package_name || "-"}</div>
        </div>
        <span className={`whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${status.cls}`}>{status.text}</span>
      </div>
      <div className="mt-3 grid gap-2 text-xs text-metin-ikincil sm:grid-cols-2">
        <span>Konum: {request.city || "-"}</span>
        <span>Tutar: {formatPrice(request.total_tl)}</span>
        <span>Odeme: {({ paid: "Odendi", paid_simulation: "Odendi (test)", pending: "Bekliyor", failed: "Basarisiz" } as Record<string, string>)[request.payment_status || ""] || request.payment_status || "-"}</span>
        <span>Tarih: {formatDate(request.created_at)}</span>
      </div>
    </div>
  );
}

function ReportRow({ report }: { report: ExpertizReportSummary }) {
  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-semibold text-metin-birincil">{report.plate || "Rapor"}</div>
          <div className="mt-1 text-sm text-metin-ikincil">{report.firm_name || "-"}</div>
        </div>
        <Link href={`/panel/raporlar/${report.id}`} className="whitespace-nowrap rounded-lg border border-kenarlik-acik px-3 py-1.5 text-xs font-semibold text-metin-birincil">
          Incele
        </Link>
      </div>
      <div className="mt-3 grid gap-2 text-xs text-metin-ikincil sm:grid-cols-2">
        <span>Yayin: {formatDate(report.published_at)}</span>
        <span>Tutar: {formatPrice(report.summary?.total_tl)}</span>
        <span>AI degeri: {formatPrice(report.summary?.market_value)}</span>
        <span>
          Deger kaybi:{" "}
          {typeof report.summary?.value_loss_pct === "number"
            ? `%${report.summary.value_loss_pct.toLocaleString("tr-TR", { maximumFractionDigits: 1 })}`
            : "-"}
        </span>
      </div>
    </div>
  );
}

function FavoriteRow({ vehicle, onRemove }: { vehicle: FavoriteVehicle; onRemove: (listingId: number) => Promise<void> }) {
  const title = vehicle.title || `${vehicle.brand} ${vehicle.model}`;
  const [removing, setRemoving] = useState(false);

  async function remove() {
    setRemoving(true);
    try {
      await onRemove(vehicle.id);
    } finally {
      setRemoving(false);
    }
  }

  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <div className="font-semibold text-metin-birincil">{title}</div>
          <div className="mt-1 text-sm text-metin-ikincil">
            {vehicle.year || "-"} / {vehicle.km ? new Intl.NumberFormat("tr-TR").format(vehicle.km) + " km" : "-"} / {vehicle.location || "-"}
          </div>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={remove}
            disabled={removing}
            className="whitespace-nowrap rounded-lg border border-kenarlik-acik px-3 py-1.5 text-xs font-semibold text-metin-ikincil disabled:opacity-60"
          >
            {removing ? "Kaldiriliyor" : "Kaldir"}
          </button>
          <Link href={`/arac-analiz/${vehicle.id}`} className="whitespace-nowrap rounded-lg border border-kenarlik-acik px-3 py-1.5 text-xs font-semibold text-metin-birincil">
            Incele
          </Link>
        </div>
      </div>
      <div className="mt-3 grid gap-2 text-xs text-metin-ikincil sm:grid-cols-3">
        <span>Fiyat: {formatPrice(vehicle.price)}</span>
        <span>Piyasa: {formatPrice(vehicle.market_avg_price)}</span>
        <span>Kayit: {formatDate(vehicle.favorited_at || undefined)}</span>
      </div>
    </div>
  );
}

function QuickActions({ credits }: { credits: number }) {
  return (
    <PanelSection title="Hizli Islemler">
      <div className="grid gap-3 sm:grid-cols-2">
        <Link href="/vitrin" className="rounded-lg border border-kenarlik-acik p-4 text-sm font-semibold text-metin-birincil hover:border-birincil">
          Vitrindeki araclari incele
        </Link>
        <Link href="/arac-analiz" className="rounded-lg border border-kenarlik-acik p-4 text-sm font-semibold text-metin-birincil hover:border-birincil">
          Link veya arac analizi yap
        </Link>
        <Link href="/ekspertiz-talebi" className="rounded-lg border border-kenarlik-acik p-4 text-sm font-semibold text-metin-birincil hover:border-birincil">
          Ekspertiz talebi olustur
        </Link>
        <Link href="/fiyatlar" className="rounded-lg border border-kenarlik-acik p-4 text-sm font-semibold text-metin-birincil hover:border-birincil">
          Kredi yukle ({credits} mevcut)
        </Link>
      </div>
    </PanelSection>
  );
}

function CreditPanel({ balance, historyCount }: { balance: CreditBalanceResponse | null; historyCount: number }) {
  return (
    <div className="grid gap-6 lg:grid-cols-[0.85fr_1.15fr]">
      <PanelSection title="Kredi Durumu">
        <div className="rounded-lg bg-gray-50 p-5">
          <div className="text-sm text-metin-ikincil">Kullanilabilir kredi</div>
          <div className="mt-2 text-4xl font-bold text-metin-birincil">{balance?.credits ?? 0}</div>
          <div className="mt-2 text-sm text-metin-ikincil">Paket: {balance?.tier || "-"}</div>
        </div>
        <Link href="/fiyatlar" className="inline-flex w-full justify-center rounded-lg bg-birincil px-4 py-2 text-sm font-semibold text-white">
          Kredi paketlerini gor
        </Link>
      </PanelSection>
      <PanelSection title="Kullanim Ozeti">
        <div className="grid gap-3 sm:grid-cols-2">
          <SummaryCard label="Toplam analiz" value={String(historyCount)} hint="Kredi gecmisinden gelen kayitlar" />
          <SummaryCard label="Hesap tipi" value={balance?.tier || "-"} hint={balance?.role || "musteri"} />
        </div>
      </PanelSection>
    </div>
  );
}

function ProfilePanel({
  profile,
  email,
  credits,
  tier,
  role,
  onSaved,
}: {
  profile: CustomerProfile | null;
  email: string;
  credits: number;
  tier?: string;
  role?: string;
  onSaved: (profile: CustomerProfile) => void;
}) {
  const [form, setForm] = useState({
    full_name: profile?.full_name || "",
    phone: profile?.phone || "",
    company_name: profile?.company_name || "",
    city: profile?.city || "",
    tax_number: profile?.tax_number || "",
    tax_office: profile?.tax_office || "",
    invoice_address: profile?.invoice_address || "",
  });
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function saveProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setMessage(null);
    try {
      const result = await updateProfile(form);
      onSaved(result.profile);
      setMessage("Profil bilgileri kaydedildi.");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Profil kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <PanelSection title="Profil ve Firma Bilgileri">
      <div className="grid gap-4 md:grid-cols-2">
        <InfoLine label="E-posta" value={email} />
        <InfoLine label="Kredi" value={String(credits)} />
        <InfoLine label="Paket" value={tier || "-"} />
        <InfoLine label="Rol" value={role || "musteri"} />
      </div>
      <form onSubmit={saveProfile} className="grid gap-4 md:grid-cols-2">
        <ProfileInput label="Ad Soyad" value={form.full_name} onChange={(value) => setForm((prev) => ({ ...prev, full_name: value }))} />
        <ProfileInput label="Telefon" value={form.phone} onChange={(value) => setForm((prev) => ({ ...prev, phone: value }))} />
        <ProfileInput label="Firma Adi" value={form.company_name} onChange={(value) => setForm((prev) => ({ ...prev, company_name: value }))} />
        <ProfileInput label="Sehir" value={form.city} onChange={(value) => setForm((prev) => ({ ...prev, city: value }))} />
        <ProfileInput label="Vergi No" value={form.tax_number} onChange={(value) => setForm((prev) => ({ ...prev, tax_number: value }))} />
        <ProfileInput label="Vergi Dairesi" value={form.tax_office} onChange={(value) => setForm((prev) => ({ ...prev, tax_office: value }))} />
        <label className="md:col-span-2">
          <span className="text-xs font-medium text-metin-ikincil">Fatura Adresi</span>
          <textarea
            value={form.invoice_address}
            onChange={(event) => setForm((prev) => ({ ...prev, invoice_address: event.target.value }))}
            rows={3}
            className="mt-1 w-full rounded-lg border border-kenarlik-acik px-3 py-2 text-sm text-metin-birincil outline-none focus:border-birincil"
          />
        </label>
        <div className="md:col-span-2 flex flex-col gap-3 sm:flex-row sm:items-center">
          <button type="submit" disabled={saving} className="rounded-lg bg-birincil px-4 py-2 text-sm font-semibold text-white disabled:opacity-60">
            {saving ? "Kaydediliyor..." : "Profil bilgilerini kaydet"}
          </button>
          {message && <span className="text-sm text-metin-ikincil">{message}</span>}
        </div>
      </form>
    </PanelSection>
  );
}

function ProfileInput({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  return (
    <label>
      <span className="text-xs font-medium text-metin-ikincil">{label}</span>
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="mt-1 w-full rounded-lg border border-kenarlik-acik px-3 py-2 text-sm text-metin-birincil outline-none focus:border-birincil"
      />
    </label>
  );
}

function InfoLine({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-kenarlik-acik p-4">
      <div className="text-xs text-metin-ikincil">{label}</div>
      <div className="mt-1 font-semibold text-metin-birincil">{value}</div>
    </div>
  );
}
