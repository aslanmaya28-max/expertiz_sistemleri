import { getToken, removeToken } from "@/lib/yetki";

// API ayri sunucudaysa (Vercel + api.yerimebak.com.tr) tarayici dogrudan oraya gider;
// boylece PayTR ve hiz siniri gercek istemci IP'sini gorur. Tanimsizsa ayni alan adi.
export const API_BASE = (process.env.NEXT_PUBLIC_API_BASE_URL || "/api/v1").replace(/\/$/, "");

export class ApiError extends Error {
  constructor(message: string, public status: number, public code?: string) {
    super(message);
  }
}

async function fetchAPI<T>(endpoint: string, options?: RequestInit): Promise<T> {
  const token = getToken();
  const res = await fetch(`${API_BASE}${endpoint}`, {
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
    ...options,
  });

  // Oturum suresi dolmus / gecersiz: token silinir, kullanici girise yonlendirilir
  if (res.status === 401 && token && typeof window !== "undefined") {
    removeToken();
    window.dispatchEvent(new Event("yerimebak:auth"));
    if (!window.location.pathname.startsWith("/giris")) {
      window.location.href = `/giris?oturum=bitti&donus=${encodeURIComponent(window.location.pathname)}`;
    }
  }

  if (!res.ok) {
    const error = await res.json().catch(() => ({ detail: res.statusText }));
    const detail = error.detail;
    const message = typeof detail === "string" ? detail : detail?.message || `HTTP ${res.status}`;
    throw new ApiError(message, res.status, typeof detail === "object" ? detail?.code : undefined);
  }

  return res.json();
}

export interface VehicleCard {
  id: number;
  brand: string;
  model: string;
  year: number;
  price: number;
  km: number;
  fuel: string;
  transmission: string;
  source: string;
  url: string;
  image_url: string;
  location: string;
  title: string;
  color: string;
  paint_summary: { painted: number; local: number; changed: number };
  ai_score: number | null;
  market_avg_price: number | null;
  price_deviation_pct: number;
  risk_score: number | null;
  risk_level: string | null;
  decision: string | null;
  net_profit_tl: number | null;
  net_margin_pct: number | null;
  exit_price: number | null;
  days_to_sell: number | null;
  buy_price_min: number | null;
  buy_price_max: number | null;
  analyzed_at: string | null;
  status: string;
  is_favorite?: boolean;
}

export interface VehicleListResponse {
  total: number;
  limit: number;
  offset: number;
  vehicles: VehicleCard[];
}

export interface FavoriteVehicle extends VehicleCard {
  favorited_at?: string | null;
}

export interface FavoritesResponse {
  success: boolean;
  favorites: FavoriteVehicle[];
  total: number;
}

export interface ExpertizPackage {
  id: string;
  name: string;
  price: number;
  features: string[];
}

export interface ExpertizFirm {
  id: string;
  name: string;
  packages: ExpertizPackage[];
}

export interface ExpertizPackagesResponse {
  service_fee_tl: number;
  vat_rate: number;
  firms: ExpertizFirm[];
}

export interface ExpertizRequestSummary {
  id: string;
  report_id: string;
  status: string;
  payment_status?: string;
  plate?: string;
  city?: string;
  firm_name?: string;
  package_name?: string;
  total_tl: number;
  created_at?: string;
  updated_at?: string;
  vehicle?: Record<string, unknown>;
  district?: string;
  progress?: RequestProgress;
}

/** Talebin canli durumu: uzman atandi, harekete gecti, arac basinda, kurumsal ekspertizde... */
export interface ProgressStep {
  key: string;
  label: string;
  at?: string | null;
  done: boolean;
}

export interface RequestProgress {
  stage: string;
  label: string;
  next_label?: string | null;
  person_name?: string;
  steps: ProgressStep[];
}

export interface AppNotification {
  id: number;
  kind: string;
  title: string;
  body: string;
  report_id?: string | null;
  created_at: string;
  read: boolean;
}

export interface NotificationsResponse {
  success: boolean;
  unread: number;
  notifications: AppNotification[];
}

/** Ekspertiz fotografi veya kurumsal rapor dosyasi (sureli imzali baglanti) */
export interface ReportMedia {
  id: string;
  category: "inspection_photo" | "corporate_report" | string;
  section?: string | null;
  item_key?: string | null;
  item_label?: string | null;
  note?: string;
  content_type?: string;
  is_image?: boolean;
  original_name?: string | null;
  created_at?: string;
  url: string;
}

/** Saha raporundaki kontrol maddesi (Flutter rapor JSON'undaki kontrolListesi) */
export interface ReportChecklistItem {
  key: string;
  label: string;
  grup: string;
  durum?: string | null;
  durumEtiket?: string;
  eksiklik?: boolean;
  not?: string | null;
  mikron?: number | null;
}

export interface ExpertizReportSummary {
  id: string;
  status: string;
  plate?: string;
  firm_name?: string;
  published_at?: string;
  created_at?: string;
  vehicle?: Record<string, unknown>;
  summary?: {
    ai_analysis_ready?: boolean;
    /** Ekspertiz düzeltmeli AI değeri (piyasa değeri − bulguların değer kaybı) */
    market_value?: number | null;
    clean_market_value?: number | null;
    value_loss_pct?: number | null;
    fair_price_min?: number | null;
    fair_price_max?: number | null;
    overall_score?: number | null;
    recommendation?: string | null;
    ai_comment?: string | null;
    damage_amount?: number | null;
    total_tl?: number | null;
  };
  admin_note?: string | null;
  media?: ReportMedia[];
  photos?: ReportMedia[];
  corporate_reports?: ReportMedia[];
}

/** AI değerlemesinde tek bir değer kaybı kalemi (ör. "Sol Ön Kapı – Değişen") */
export interface ValuationLossItem {
  kategori: "kaporta" | "yapisal" | "dis" | "ic" | "mekanik" | "tramer" | "hasar_kaydi" | string;
  anahtar: string;
  baslik: string;
  durum: string;
  yuzde: number;
  hamYuzde: number;
  tutar: number;
  aciklama?: string;
}

export interface InspectionValuation {
  modelVersiyonu?: string;
  degerlemeYapildi: boolean;
  piyasaDegeri?: number | null;
  temizPiyasaDegeri?: number | null;
  piyasaYontemi?: string;
  piyasaDuzeltmeleri?: { baslik: string; yuzde: number; tutar: number; aciklama?: string }[];
  kalemler: ValuationLossItem[];
  toplamDegerKaybiYuzde: number;
  toplamDegerKaybiTutar?: number;
  aiDegeri?: number | null;
  adilFiyatAraligi?: { min: number; max: number };
  onerilenAlimFiyati?: number;
  ilanFiyati?: number | null;
  fiyatYorumu?: { karar: "AVANTAJLI" | "MAKUL" | "PAZARLIK" | "YUKSEK" | string; aciklama: string; farkYuzde: number; farkTutar: number };
  guvenSkoru?: number;
  eskiPiyasaVerisi?: boolean;
  hasarSeviyesi?: string;
  agirHasar?: boolean;
  boyaliParcaSayisi?: number;
  degisenParcaSayisi?: number;
  yapisalIslemSayisi?: number;
  ozet?: string;
}

export interface CustomerAiAnalysis {
  analizZamani?: string;
  skorlar?: {
    aracDurumuPuan: number;
    motorMekanikPuan: number;
    hasarPuan: number;
    genelPuan: number;
    puanDegerlendirmesi?: string;
    detayliPuanlar?: Record<string, number>;
  };
  raporOzeti?: {
    genelSonuc?: string;
    anahtarBulgular?: string[];
    ozetAciklama?: string;
    onayRedOnerisi?: string;
    tahminiDeger?: number;
    degerKaybiYuzde?: number;
  };
  oneriler?: { kategori: string; baslik: string; aciklama: string; onerilenEylem?: string | null; oncelik: number }[];
  kritikSorunlar?: string[];
  ekspertizDegerleme?: InspectionValuation;
  piyasaReferansi?: {
    bulundu: boolean;
    emsalSayisi: number;
    hasarsizEmsalSayisi: number;
    medyan: number;
    min: number;
    max: number;
    guncelGun?: number;
    emsaller: { price?: number; km?: number; year?: number; title?: string; condition?: string }[];
  };
  likidite?: { liquidity_score?: number; estimated_days_to_sell?: number };
}

export interface ExpertizRequestsResponse {
  success: boolean;
  requests: ExpertizRequestSummary[];
}

export interface ExpertizReportsResponse {
  success: boolean;
  reports: ExpertizReportSummary[];
}

export interface ExpertizReportDetailResponse {
  success: boolean;
  report: ExpertizReportSummary & {
    ai?: CustomerAiAnalysis | null;
    report?: Record<string, unknown> | null;
  };
}

export interface CreditBalanceResponse {
  user_id: number;
  email: string;
  credits: number;
  tier: string;
  role: string;
}

export interface AnalysisHistoryItem {
  id: string;
  user_id?: number;
  vehicle_json?: Record<string, unknown> | string | null;
  valuation_json?: Record<string, unknown> | string | null;
  created_at?: string;
}

export interface AnalysisHistoryResponse {
  history: AnalysisHistoryItem[];
  total: number;
}

export interface CustomerProfile {
  id: number;
  email: string;
  full_name?: string | null;
  phone?: string | null;
  credits: number;
  tier: string;
  role: string;
  company_name?: string | null;
  city?: string | null;
  tax_number?: string | null;
  tax_office?: string | null;
  invoice_address?: string | null;
  email_verified?: boolean;
}

export interface CustomerProfileResponse {
  success: boolean;
  profile: CustomerProfile;
}

export interface VehicleInput {
  brand?: string;
  model?: string;
  year?: number;
  km?: number;
  price?: number;
  fuel?: string;
  transmission?: string;
}

export interface CreateExpertizRequestPayload {
  firm_id: string;
  package_id: string;
  listing_id?: number;
  listing_url?: string;
  plate?: string;
  city?: string;
  district?: string;
  note?: string;
  vehicle?: VehicleInput;
}

export interface ExpertizTotals {
  service_fee_tl: number;
  package_price_tl: number;
  vat_tl: number;
  total_tl: number;
}

/** Odeme baslatma cevabi: PayTR iframe adresi veya (gelistirmede) simulasyon */
export interface CheckoutStart {
  success: boolean;
  order_id: string;
  kind: "credits" | "expertiz";
  amount_tl: number;
  provider: "paytr" | "simulation";
  iframe_url: string | null;
  request_id?: string;
  credits?: number;
  totals?: ExpertizTotals;
}

export interface CheckoutStatus {
  success: boolean;
  order_id: string;
  kind: "credits" | "expertiz";
  status: "pending" | "paid" | "failed";
  amount_tl: number;
  credits?: number;
  credit_balance?: number | null;
  request_id?: string;
  firm_name?: string;
  package_name?: string;
  failed_reason?: string | null;
}

export interface CreditPackage {
  credits: number;
  price: number;
  name: string;
  popular?: boolean;
}

export type PartStatus = "orijinal" | "lokal_boyali" | "boyali" | "degisen";

export interface ValuationPartsResponse {
  parts: { key: string; label: string }[];
  statuses: { key: PartStatus; label: string }[];
  cost_credits: number;
}

export interface ValuationPrefill {
  success: boolean;
  found: boolean;
  listing_id?: number;
  /** Kisa link (shbd.io) cozulduyse asil ilan adresi */
  url?: string;
  source?: "arabam" | "sahibinden" | null;
  vehicle: VehicleInput & { title?: string; image_url?: string; location?: string };
  parts: Record<string, PartStatus>;
  message: string;
}

export interface ValuationRequestPayload {
  listing_url?: string;
  brand?: string;
  model?: string;
  year?: number;
  km?: number;
  listed_price?: number;
  fuel?: string;
  transmission?: string;
  parts?: Record<string, PartStatus>;
  tramer_amount?: number;
  tramer_count?: number;
}

export interface ValuationHorizon {
  ay: number;
  tahminiDeger: number;
  getiriTl: number;
  getiriYuzde: number | null;
}

export interface ValuationResult {
  success: boolean;
  arac: { marka: string; model: string; yil: number; km: number; yakit?: string | null; vites?: string | null; ilanFiyati: number; ilanLinki?: string | null };
  piyasa: { ortalama: number; medyan: number; min: number; max: number; emsalSayisi: number; hasarsizEmsalSayisi?: number; guvenSkoru: number; guncelGun?: number };
  degerleme: {
    temizPiyasaDegeri: number;
    toplamDegerKaybiYuzde: number;
    toplamDegerKaybiTutar: number;
    kalemler: ValuationLossItem[];
    aiDegeri: number;
    adilFiyatAraligi: { min: number; max: number };
    tavsiyeFiyat: number;
    hasarSeviyesi?: string;
    agirHasar?: boolean;
    ozet?: string;
  };
  karar: { sonuc: "AL" | "PAZARLIK YAP" | "ALMA"; aciklama: string; ilanFarkiYuzde?: number; ilanFarkiTutar?: number };
  getiri: null | {
    aylikEnflasyonYuzde: number;
    yillikEnflasyonYuzde: number;
    kaynak?: string;
    gecerlilikTarihi?: string;
    alisFiyati: number;
    altiAy: ValuationHorizon;
    birYil: ValuationHorizon;
    aciklama: string;
  };
  kredi: { dusulen: number; kalan: number };
}

export interface VitrinStats {
  total_listings: number;
  analyzed_listings: number;
  avg_ai_score: number;
  buy_opportunities: number;
  avg_price: number;
  by_source: Record<string, number>;
  daily_new_listings: number;
}

export interface BrandInfo {
  brand: string;
  count: number;
}

export interface ModelInfo {
  model: string;
  count: number;
}

export function getVehicles(params: Record<string, string | number | undefined> = {}): Promise<VehicleListResponse> {
  const sp = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== "") sp.set(k, String(v));
  });
  return fetchAPI<VehicleListResponse>(`/vitrin/vehicles?${sp.toString()}`);
}

export function getVehicleDetail(id: number, options?: RequestInit): Promise<VehicleCard> {
  return fetchAPI<VehicleCard>(`/vitrin/vehicles/${id}`, options);
}

export function getBrands(): Promise<BrandInfo[]> {
  return fetchAPI<BrandInfo[]>("/vitrin/brands");
}

export function getModels(brand: string): Promise<ModelInfo[]> {
  return fetchAPI<ModelInfo[]>(`/vitrin/models?brand=${encodeURIComponent(brand)}`);
}

export function getStats(): Promise<VitrinStats> {
  return fetchAPI<VitrinStats>("/vitrin/stats");
}

export function searchVehicles(q: string, limit = 20): Promise<{ query: string; total: number; vehicles: VehicleCard[] }> {
  return fetchAPI(`/vitrin/search?q=${encodeURIComponent(q)}&limit=${limit}`);
}

export function getExpertizPackages(options?: RequestInit): Promise<ExpertizPackagesResponse> {
  return fetchAPI<ExpertizPackagesResponse>("/expertiz/packages", options);
}

export function getExpertizQuote(firmId: string, packageId: string): Promise<{ success: boolean; totals: ExpertizTotals }> {
  return fetchAPI(`/expertiz/quote?firm_id=${encodeURIComponent(firmId)}&package_id=${encodeURIComponent(packageId)}`);
}

/** Tahsilat yapmadan talebi yonetici kuyruguna iletir. */
export function createExpertizRequest(payload: CreateExpertizRequestPayload): Promise<{ success: boolean; request_id: string; payment_status: string }> {
  return fetchAPI<{ success: boolean; request_id: string; payment_status: string }>("/expertiz/requests/unpaid", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getMyExpertizRequests(): Promise<ExpertizRequestsResponse> {
  return fetchAPI<ExpertizRequestsResponse>("/expertiz/requests");
}

export function getMyNotifications(limit = 30): Promise<NotificationsResponse> {
  return fetchAPI<NotificationsResponse>(`/expertiz/notifications?limit=${limit}`);
}

export function markNotificationsRead(ids?: number[]): Promise<{ success: boolean; updated: number }> {
  return fetchAPI("/expertiz/notifications/read", { method: "POST", body: JSON.stringify(ids ? { ids } : {}) });
}

export function getMyExpertizReports(): Promise<ExpertizReportsResponse> {
  return fetchAPI<ExpertizReportsResponse>("/expertiz/reports");
}

export function getMyExpertizReport(id: string): Promise<ExpertizReportDetailResponse> {
  return fetchAPI<ExpertizReportDetailResponse>(`/expertiz/reports/${encodeURIComponent(id)}`);
}

export function getCreditBalance(): Promise<CreditBalanceResponse> {
  return fetchAPI<CreditBalanceResponse>("/credits/balance");
}

export function getAnalysisHistory(): Promise<AnalysisHistoryResponse> {
  return fetchAPI<AnalysisHistoryResponse>("/credits/history");
}

export function getFavorites(): Promise<FavoritesResponse> {
  return fetchAPI<FavoritesResponse>("/favorites");
}

export function addFavorite(listingId: number): Promise<{ success: boolean; listing_id: number }> {
  return fetchAPI<{ success: boolean; listing_id: number }>("/favorites", {
    method: "POST",
    body: JSON.stringify({ listing_id: listingId }),
  });
}

export function removeFavorite(listingId: number): Promise<{ success: boolean; listing_id: number }> {
  return fetchAPI<{ success: boolean; listing_id: number }>(`/favorites/${listingId}`, { method: "DELETE" });
}

export function getProfile(): Promise<CustomerProfileResponse> {
  return fetchAPI<CustomerProfileResponse>("/auth/profile");
}

export function updateProfile(payload: Partial<CustomerProfile>): Promise<CustomerProfileResponse> {
  return fetchAPI<CustomerProfileResponse>("/auth/profile", {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

// ---------------------------------------------------------------------------
// Odeme (PayTR) ve kredi paketleri
// ---------------------------------------------------------------------------

export function getCreditPackages(): Promise<{ packages: Record<string, CreditPackage>; analysis_cost: number }> {
  return fetchAPI("/payments/packages");
}

export function startCreditCheckout(packageKey: string, contractAccepted: boolean): Promise<CheckoutStart> {
  return fetchAPI<CheckoutStart>("/payments/checkout/credits", {
    method: "POST",
    body: JSON.stringify({ package_key: packageKey, contract_accepted: contractAccepted }),
  });
}

// --- Hesap: sifre sifirlama, e-posta dogrulama ---------------------------

export function requestPasswordReset(email: string): Promise<{ success: boolean; message: string }> {
  return fetchAPI("/auth/forgot-password", { method: "POST", body: JSON.stringify({ email }) });
}

export function resetPassword(token: string, newPassword: string): Promise<{ success: boolean }> {
  return fetchAPI("/auth/reset-password", { method: "POST", body: JSON.stringify({ token, new_password: newPassword }) });
}

export function verifyEmail(token: string): Promise<{ success: boolean; credits_granted: number }> {
  return fetchAPI("/auth/verify-email", { method: "POST", body: JSON.stringify({ token }) });
}

export function resendVerification(): Promise<{ success: boolean; already_verified?: boolean }> {
  return fetchAPI("/auth/resend-verification", { method: "POST", body: JSON.stringify({}) });
}

export function getCheckoutStatus(orderId: string): Promise<CheckoutStatus> {
  return fetchAPI<CheckoutStatus>(`/payments/checkout/${encodeURIComponent(orderId)}`);
}

/** Sadece sunucuda PAYMENT_SIMULATION=true iken calisir (gelistirme). */
export function simulateCheckout(orderId: string, success: boolean): Promise<CheckoutStatus> {
  return fetchAPI<CheckoutStatus>(`/payments/checkout/${encodeURIComponent(orderId)}/simulate`, {
    method: "POST",
    body: JSON.stringify({ success }),
  });
}

// ---------------------------------------------------------------------------
// Arac degerleme (kredi ile)
// ---------------------------------------------------------------------------

export function getValuationParts(): Promise<ValuationPartsResponse> {
  return fetchAPI<ValuationPartsResponse>("/valuation/parts");
}

export function prefillValuation(url: string): Promise<ValuationPrefill> {
  return fetchAPI<ValuationPrefill>(`/valuation/prefill?url=${encodeURIComponent(url)}`);
}

export function analyzeValuation(payload: ValuationRequestPayload): Promise<ValuationResult> {
  return fetchAPI<ValuationResult>("/valuation/analyze", { method: "POST", body: JSON.stringify(payload) });
}
