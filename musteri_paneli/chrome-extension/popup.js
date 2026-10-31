/**
 * YERİMEBAK AI Chrome Extension - Popup Controller
 * Handles login, platform detection, analysis trigger, and result rendering.
 */

// ─── DOM REFERENCES ──────────────────────────────────────────────
const $ = (id) => document.getElementById(id);

const DOM = {
  loginScreen: $('login-screen'),
  mainScreen: $('main-screen'),
  apiUrl: $('api-url'),
  apiKey: $('api-key'),
  loginBtn: $('login-btn'),
  loginError: $('login-error'),
  creditsDisplay: $('credits-display'),
  logoutBtn: $('logout-btn'),
  platformInfo: $('platform-info'),
  platformIcon: $('platform-icon'),
  platformName: $('platform-name'),
  analyzeBtn: $('analyze-btn'),
  loading: $('loading'),
  results: $('results'),
  verdictCard: $('verdict-card'),
  verdictIcon: $('verdict-icon'),
  verdictDecision: $('verdict-decision'),
  verdictNote: $('verdict-note'),
  gaugeScore: $('gauge-score'),
  gaugeFill: $('gauge-fill'),
  metricProfit: $('metric-profit'),
  metricMargin: $('metric-margin'),
  metricOpp: $('metric-opp'),
  metricRisk: $('metric-risk'),
  riskKm: $('risk-km'),
  riskPaint: $('risk-paint'),
  riskChange: $('risk-change'),
  riskKmVal: $('risk-km-val'),
  riskPaintVal: $('risk-paint-val'),
  riskChangeVal: $('risk-change-val'),
  detailOptimal: $('detail-optimal'),
  detailMax: $('detail-max'),
  detailExit: $('detail-exit'),
  detailDays: $('detail-days'),
  vehicleInfo: $('vehicle-info'),
  openDashboard: $('open-dashboard-btn'),
  errorDisplay: $('error-display'),
  errorMessage: $('error-message'),
  retryBtn: $('retry-btn'),
  ingestBox: $('ingest-box'),
  ingestHint: $('ingest-hint'),
  ingestSearchFields: $('ingest-search-fields'),
  ingestBrand: $('ingest-brand'),
  ingestModel: $('ingest-model'),
  ingestBtn: $('ingest-btn'),
  ingestResult: $('ingest-result'),
};

// ─── STATE ───────────────────────────────────────────────────────
let state = {
  apiUrl: '',
  apiKey: '',
  user: null,
  platform: null,
  lastResult: null,
};

// ─── STORAGE HELPERS ─────────────────────────────────────────────
// 🔒 DÜZELTİLDİ (Bug #20): XOR obfuscation kaldirildi.
// chrome.storage.local zaten Chrome'un kendi sandbox/Security modelinde calisir.
// XOR + Base64 sadece "security through obscurity"dir, guvenlik saglamaz.
// Sadece chrome.storage.local kullaniliyor — asil guvenlik HTTPS ve sunucu taraflidir.

async function _secureStore(apiUrl, apiKey, user) {
  await chrome.storage.local.set({
    apiUrl: apiUrl,
    apiKey: apiKey,
    user: user,
  });
}

async function _secureLoad() {
  const stored = await chrome.storage.local.get(['apiUrl', 'apiKey', 'user']);
  return {
    apiUrl: stored.apiUrl || '',
    apiKey: stored.apiKey || '',
    user: stored.user || null,
  };
}

async function _secureRemove() {
  await chrome.storage.local.remove(['apiKey', 'user']);
}

// ─── INIT ────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', async () => {
  const stored = await _secureLoad();
  if (stored.apiUrl) state.apiUrl = stored.apiUrl;
  if (stored.apiKey) state.apiKey = stored.apiKey;
  if (stored.user) state.user = stored.user;

  // 🔒 DÜZELTİLDİ (Bug #19): Production'da HTTPS kullan, development fallback
  DOM.apiUrl.value = state.apiUrl || 'https://api.yerimebak.com.tr';

  if (state.apiKey && state.user) {
    showMainScreen();
  }

  // Event listeners
  DOM.loginBtn.addEventListener('click', handleLogin);
  DOM.logoutBtn.addEventListener('click', handleLogout);
  DOM.analyzeBtn.addEventListener('click', handleAnalyze);
  DOM.retryBtn.addEventListener('click', handleAnalyze);
  DOM.openDashboard.addEventListener('click', openDashboard);
  DOM.ingestBtn.addEventListener('click', handleIngest);

  // Allow Enter key for login
  DOM.apiKey.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') handleLogin();
  });
});

// ─── AUTH ────────────────────────────────────────────────────────
async function handleLogin() {
  const apiUrl = DOM.apiUrl.value.trim().replace(/\/$/, '');
  const apiKey = DOM.apiKey.value.trim();

  if (!apiUrl || !apiKey) {
    showLoginError('Sunucu adresi ve API anahtarı gereklidir.');
    return;
  }

  DOM.loginBtn.disabled = true;

  try {
    const resp = await fetch(`${apiUrl}/api/v1/auth/me`, {
      headers: { 'X-API-Key': apiKey },
    });

    if (!resp.ok) {
      const data = await resp.json().catch(() => ({}));
      throw new Error(data.detail || 'Giriş başarısız.');
    }

    const authData = await resp.json();
    const user = authData.user || authData;

    state.apiUrl = apiUrl;
    state.apiKey = apiKey;
    state.user = user;

    // 🔒 API anahtarini sifreleyerek sakla
    await _secureStore(apiUrl, apiKey, user);
    showMainScreen();

  } catch (err) {
    showLoginError(err.message || 'Sunucuya bağlanılamadı.');
  } finally {
    DOM.loginBtn.disabled = false;
  }
}

function handleLogout() {
  state.apiKey = '';
  state.user = null;
  _secureRemove();
  DOM.loginScreen.style.display = '';
  DOM.mainScreen.style.display = 'none';
  DOM.apiKey.value = '';
}

function showLoginError(msg) {
  DOM.loginError.textContent = msg;
  DOM.loginError.style.display = '';
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────
async function showMainScreen() {
  DOM.loginScreen.style.display = 'none';
  DOM.mainScreen.style.display = '';
  DOM.results.style.display = 'none';
  DOM.errorDisplay.style.display = 'none';
  DOM.loading.style.display = 'none';

  updateCredits();
  await detectPlatform();
}

async function updateCredits() {
  try {
    const resp = await fetch(`${state.apiUrl}/api/v1/auth/me`, {
      headers: { 'X-API-Key': state.apiKey },
    });
    if (resp.ok) {
      const authData = await resp.json();
      const user = authData.user || authData;
      state.user = user;
      DOM.creditsDisplay.textContent = `⭐ ${user.credits || 0} Kredi`;
    }
  } catch (e) {
    DOM.creditsDisplay.textContent = '⭐ ? Kredi';
  }
}

async function detectPlatform() {
  return new Promise((resolve) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const url = tabs[0]?.url || '';
      let platform = null;

      if (url.includes('sahibinden.com')) {
        platform = { id: 'sahibinden', name: 'Sahibinden', icon: '🏠', color: '#4ade80' };
      } else if (url.includes('arabam.com')) {
        platform = { id: 'arabam', name: 'Arabam.com', icon: '🚗', color: '#60a5fa' };
      } else if (url.includes('letgo.com')) {
        platform = { id: 'letgo', name: 'Letgo', icon: '📱', color: '#a78bfa' };
      }

      state.platform = platform;
      setupIngest(url);

      if (platform) {
        DOM.platformInfo.className = 'platform-info supported';
        DOM.platformIcon.textContent = platform.icon;
        DOM.platformName.textContent = `${platform.name} ilanı algılandı`;
        DOM.analyzeBtn.disabled = false;
      } else {
        DOM.platformInfo.className = 'platform-info unsupported';
        DOM.platformIcon.textContent = '⚠️';
        DOM.platformName.textContent = 'Desteklenmeyen sayfa. Lütfen bir ilan sayfası açın.';
        DOM.analyzeBtn.disabled = true;
      }

      resolve();
    });
  });
}

// ─── ANALYZE ─────────────────────────────────────────────────────
async function handleAnalyze() {
  DOM.errorDisplay.style.display = 'none';
  DOM.results.style.display = 'none';
  DOM.loading.style.display = '';
  DOM.analyzeBtn.disabled = true;

  try {
    // Step 1: Extract data from current tab
    const vehicleData = await extractVehicleData();

    if (!vehicleData || !vehicleData.brand) {
      throw new Error('Araç verisi çekilemedi. İlan sayfasında olduğunuzdan emin olun.');
    }

    // Step 2: Send to API for analysis
    const resp = await fetch(`${state.apiUrl}/api/v1/extension/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': state.apiKey,
      },
      body: JSON.stringify(vehicleData),
    });

    if (!resp.ok) {
      const err = await resp.json().catch(() => ({}));
      throw new Error(err.detail || `Sunucu hatası (${resp.status})`);
    }

    const result = await resp.json();
    state.lastResult = result;

    // Step 3: Render results
    renderResults(result);
    updateCredits();

  } catch (err) {
    DOM.loading.style.display = 'none';
    DOM.errorDisplay.style.display = '';
    DOM.errorMessage.textContent = err.message;
  } finally {
    DOM.analyzeBtn.disabled = !state.platform;
  }
}

async function extractVehicleData() {
  return new Promise((resolve) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const tabId = tabs[0]?.id;
      if (!tabId) return resolve(null);

      chrome.tabs.sendMessage(tabId, { action: 'EXTRACT_DATA' }, (response) => {
        if (chrome.runtime.lastError) {
          console.error('Content script error:', chrome.runtime.lastError);
          resolve(null);
          return;
        }
        resolve(response);
      });
    });
  });
}

// ─── RENDER RESULTS ──────────────────────────────────────────────
function renderResults(r) {
  DOM.loading.style.display = 'none';
  DOM.results.style.display = '';

  const verdict = r.dealer_verdict || {};
  const tech = r.technical_scoring || {};
  const comm = r.commercial_analysis || {};
  const liq = r.liquidity_metrics || {};
  const vehicle = r.vehicle || {};
  const risk = r.risk_v8 || {};

  // Verdict card
  const decision = verdict.decision || 'ANALİZ';
  const decisionLower = decision.toLowerCase();
  let cardClass = 'hold';
  let icon = '🎯';

  if (['al', 'alım', 'buy', 'strong buy', 'kesinlikle al'].includes(decisionLower)) {
    cardClass = 'buy'; icon = '✅';
  } else if (['sat', 'satış', 'sell', 'pass', 'kaçın'].includes(decisionLower)) {
    cardClass = 'pass'; icon = '❌';
  } else if (['bekle', 'hold', 'dikkat', 'wait'].includes(decisionLower)) {
    cardClass = 'hold'; icon = '⚠️';
  }

  DOM.verdictCard.className = `verdict-card ${cardClass}`;
  DOM.verdictIcon.textContent = icon;
  DOM.verdictDecision.textContent = decision;
  DOM.verdictNote.textContent = verdict.action_note || '';

  // Gauge
  const score = tech.opportunity_score || 0;
  const scoreColor = score > 70 ? '#4ade80' : score > 40 ? '#fbbf24' : '#f87171';
  DOM.gaugeScore.textContent = score;
  DOM.gaugeScore.style.color = scoreColor;
  DOM.gaugeFill.style.width = `${score}%`;
  DOM.gaugeFill.style.background = scoreColor;

  // Metrics
  DOM.metricProfit.textContent = fmtMoney(comm.net_profit_tl || 0);
  DOM.metricProfit.style.color = (comm.net_profit_tl || 0) > 0 ? '#4ade80' : '#f87171';
  DOM.metricMargin.textContent = `%${comm.net_margin_percent || 0}`;
  DOM.metricMargin.style.color = (comm.net_margin_percent || 0) > 0 ? '#4ade80' : '#f87171';
  DOM.metricOpp.textContent = score;
  DOM.metricOpp.style.color = scoreColor;
  const riskPct = tech.risk_percentage || 0;
  DOM.metricRisk.textContent = `%${riskPct}`;
  DOM.metricRisk.style.color = riskPct < 30 ? '#4ade80' : riskPct < 50 ? '#fbbf24' : '#f87171';

  // Risk bars
  setRiskBar(DOM.riskKm, DOM.riskKmVal, risk.km_risk || 0);
  setRiskBar(DOM.riskPaint, DOM.riskPaintVal, risk.paint_risk || 0);
  setRiskBar(DOM.riskChange, DOM.riskChangeVal, risk.change_risk || 0);

  // Commercial details
  DOM.detailOptimal.textContent = fmtMoney(comm.optimal_purchase_price || 0);
  DOM.detailMax.textContent = fmtMoney(comm.max_offer_price || comm.optimal_purchase_price || 0);
  DOM.detailExit.textContent = fmtMoney(risk.exit_price || 0);
  DOM.detailDays.textContent = `${risk.estimated_days_to_sell || liq.estimated_days_to_sell || '—'} Gün`;

  // Vehicle info tags
  const tags = [
    vehicle.brand, vehicle.model, vehicle.year, `${(vehicle.mileage_km || 0).toLocaleString('tr')} km`,
    vehicle.fuel_type, vehicle.gear_type,
  ].filter(Boolean);

  DOM.vehicleInfo.innerHTML = tags.map(t => `<span class="v-tag">${t}</span>`).join('');
}

function setRiskBar(barEl, valEl, pct) {
  barEl.style.width = `${Math.min(100, pct)}%`;
  barEl.style.background = pct < 15 ? '#4ade80' : pct < 30 ? '#fbbf24' : '#f87171';
  valEl.textContent = `%${pct}`;
}

function fmtMoney(n) {
  return `${Math.round(n).toLocaleString('tr-TR')} ₺`;
}

function openDashboard() {
  const url = state.apiUrl ? `${state.apiUrl.replace(/\/$/, '')}/dashboard` : 'http://localhost:8000/dashboard';
  chrome.tabs.create({ url });
}

// ─── SISTEME KAYDET (arabam.com) ─────────────────────────────────
// arabam.com sunucudan gelen otomatik istekleri engeller; ilan verisi
// personelin kendi tarayicisinda actigi sayfadan alinir. Ucretsizdir.
function setupIngest(url) {
  const role = String(state.user?.role || '').toLowerCase();
  const staff = ['admin', 'field_staff', 'personel', 'personnel', 'staff'].includes(role);
  let path = '';
  try { path = new URL(url).pathname; } catch (e) { /* gecersiz adres */ }
  if (!staff || !url.includes('arabam.com')) {
    DOM.ingestBox.style.display = 'none';
    return;
  }
  const isListing = path.includes('/ilan/');
  state.ingestType = isListing ? 'listing' : 'search';
  DOM.ingestBox.style.display = '';
  DOM.ingestResult.style.display = 'none';
  DOM.ingestSearchFields.style.display = isListing ? 'none' : '';
  DOM.ingestBtn.textContent = isListing ? 'İlanı sisteme kaydet' : 'Sayfadaki ilanları emsal kaydet';
  DOM.ingestHint.textContent = isListing
    ? 'Fiyat, km, paket, boya/değişen ve tramer beyanı kaydedilir. Sayfanın tamamen yüklendiğinden emin olun.'
    : 'Bu sayfada görünen ilanlar emsal olarak kaydedilir (arama sayfasında boya bilgisi yoktur).';
}

async function capturePage() {
  return new Promise((resolve) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const tabId = tabs[0]?.id;
      if (!tabId) return resolve(null);
      chrome.tabs.sendMessage(tabId, { action: 'CAPTURE_PAGE' }, (response) => {
        if (chrome.runtime.lastError) return resolve(null);
        resolve(response);
      });
    });
  });
}

function showIngestResult(ok, text) {
  DOM.ingestResult.className = `ingest-result ${ok ? 'ok' : 'err'}`;
  DOM.ingestResult.textContent = text;
  DOM.ingestResult.style.display = '';
}

async function handleIngest() {
  DOM.ingestBtn.disabled = true;
  try {
    const page = await capturePage();
    if (!page) throw new Error('Sayfa okunamadı. Sayfayı yenileyip tekrar deneyin.');

    let endpoint, body;
    if (page.pageType === 'listing') {
      endpoint = 'listing';
      body = page;
    } else {
      if (!page.cards?.length) throw new Error('Bu sayfada ilan bulunamadı.');
      endpoint = 'search';
      body = { url: page.url, cards: page.cards, brand: DOM.ingestBrand.value.trim(), model: DOM.ingestModel.value.trim() };
    }

    const resp = await fetch(`${state.apiUrl}/api/v1/extension/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-API-Key': state.apiKey },
      body: JSON.stringify(body),
    });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) throw new Error(data.detail || `Sunucu hatası (${resp.status})`);

    if (endpoint === 'listing') {
      const v = data.vehicle || {};
      const b = data.beyan || {};
      const tramer = b.tramerTl ? `${Number(b.tramerTl).toLocaleString('tr-TR')} TL` : (b.tramerYok ? 'yok' : 'belirtilmemiş');
      const boya = b.boyaBolumuVar ? `${b.boyali.length} boyalı, ${b.degisen.length} değişen` : 'beyan yok';
      showIngestResult(true, `✅ Kaydedildi: ${v.brand} ${v.model} ${v.year || ''} · ${fmtMoney(v.price || 0)} · Boya: ${boya} · Tramer: ${tramer}`);
    } else {
      showIngestResult(true, `✅ ${data.brand} ${data.model}: ${data.saved} / ${data.found} ilan emsal olarak kaydedildi.`);
    }
  } catch (err) {
    showIngestResult(false, err.message || 'Kaydedilemedi.');
  } finally {
    DOM.ingestBtn.disabled = false;
  }
}
