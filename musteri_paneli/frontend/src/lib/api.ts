import { getToken } from "@/lib/yetki";

export const API_BASE = "/api/v1";

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

  if (!res.ok) {
    const error = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(error.detail || `HTTP ${res.status}`);
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
    market_value?: number | null;
    ai_comment?: string | null;
    damage_amount?: number | null;
    total_tl?: number | null;
  };
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
    ai?: Record<string, unknown> | null;
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
}

export interface CustomerProfileResponse {
  success: boolean;
  profile: CustomerProfile;
}

export interface CreateExpertizRequestPayload {
  firm_id: string;
  package_id: string;
  listing_id?: number;
  listing_url?: string;
  plate?: string;
  city?: string;
  note?: string;
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

export type ScraperSource = "arabam" | "borusan" | "all";

export interface ScraperSourceStatus {
  status: "running" | "idle" | "unknown" | string;
  pid?: number | null;
  last_activity?: string | null;
  source: "arabam" | "borusan" | string;
}

export interface ScraperStatusResponse {
  arabam: ScraperSourceStatus;
  borusan: ScraperSourceStatus;
  active_workers: number;
  total_workers: number;
}

export interface ScraperActionResponse {
  status: string;
  message: string;
  source?: string;
  sources?: string[];
}

export interface MarketCoverageBalance {
  status?: string;
  missing?: Record<string, number>;
  [key: string]: string | number | Record<string, number> | undefined;
}

export interface MarketCoverageRow {
  brand: string;
  model: string;
  segment: string;
  priority: number;
  year_bucket: string;
  year_min: number;
  year_max: number;
  active_count: number;
  target_count: number;
  missing_count: number;
  stale_count: number;
  fuel_balance: MarketCoverageBalance;
  transmission_balance: MarketCoverageBalance;
  coverage_status: "healthy" | "underfilled" | "filled_imbalanced" | "stale" | string;
}

export interface MarketCoverageSummaryResponse {
  success: boolean;
  total_rows: number;
  healthy: number;
  underfilled: number;
  filled_imbalanced: number;
  stale: number;
  coverage: MarketCoverageRow[];
}

export interface MarketBackfillTarget {
  brand: string;
  model: string;
  segment: string;
  year_min: number;
  year_max: number;
  year_bucket: string;
  missing_count: number;
  preferred_fuel?: string | null;
  preferred_transmission?: string | null;
  priority: number;
  reason: string;
}

export interface MarketBackfillTargetsResponse {
  success: boolean;
  total: number;
  targets: MarketBackfillTarget[];
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

export function getVehicleDetail(id: number): Promise<VehicleCard> {
  return fetchAPI<VehicleCard>(`/vitrin/vehicles/${id}`);
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

export function getScraperStatus(): Promise<ScraperStatusResponse> {
  return fetchAPI<ScraperStatusResponse>("/scrapers/status");
}

export function startScraper(source: ScraperSource): Promise<ScraperActionResponse> {
  return fetchAPI<ScraperActionResponse>(`/scrapers/start/${source}`, { method: "POST" });
}

export function stopScraper(source: ScraperSource): Promise<ScraperActionResponse> {
  return fetchAPI<ScraperActionResponse>(`/scrapers/stop/${source}`, { method: "POST" });
}

export function getMarketCoverageSummary(): Promise<MarketCoverageSummaryResponse> {
  return fetchAPI<MarketCoverageSummaryResponse>("/market-coverage/summary");
}

export function getMarketBackfillTargets(): Promise<MarketBackfillTargetsResponse> {
  return fetchAPI<MarketBackfillTargetsResponse>("/market-coverage/backfill-targets");
}

export function searchVehicles(q: string, limit = 20): Promise<{ query: string; total: number; vehicles: VehicleCard[] }> {
  return fetchAPI(`/vitrin/search?q=${encodeURIComponent(q)}&limit=${limit}`);
}

export function analyzeVehicle(id: number): Promise<Record<string, unknown>> {
  return fetchAPI(`/vitrin/${id}/analyze`, { method: "POST" });
}

export function getExpertizPackages(): Promise<ExpertizPackagesResponse> {
  return fetchAPI<ExpertizPackagesResponse>("/expertiz/packages");
}

export function createExpertizRequest(payload: CreateExpertizRequestPayload): Promise<Record<string, unknown>> {
  return fetchAPI<Record<string, unknown>>("/expertiz/requests", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getMyExpertizRequests(): Promise<ExpertizRequestsResponse> {
  return fetchAPI<ExpertizRequestsResponse>("/expertiz/requests");
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
