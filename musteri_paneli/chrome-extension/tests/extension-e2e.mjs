/**
 * Chrome eklentisi uctan uca testi: eklenti gercek Chromium'a yuklenir, arabam.com sayfalari
 * sahte HTML ile taklit edilir (internete cikilmaz), kayit gercek backend'e yapilir.
 *
 * Calistirma (backend http://localhost:8000'de calisiyor olmali; eklentinin izinli adresi):
 *   EXT_API_KEY=<admin veya personel API anahtari> [EXT_CUSTOMER_KEY=<musteri anahtari>] node tests/extension-e2e.mjs
 * EXT_API_KEY yoksa test atlanir. Playwright kurulu olmali (npm i -g playwright ya da proje icinde).
 */
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const API_URL = process.env.EXT_API_URL || 'http://localhost:8000';
const API_KEY = process.env.EXT_API_KEY;
if (!API_KEY) { console.log('EXT_API_KEY yok, test atlandi'); process.exit(0); }

const EXT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LISTING = 'https://www.arabam.com/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/temiz-clio/28123456';
const SEARCH = 'https://www.arabam.com/ikinci-el/otomobil/renault-clio';

const lines = (arr) => arr.map((l) => `<div>${l}</div>`).join('');
const listingHtml = `<!doctype html><html><head><title>Renault Clio 1.0 TCe Touch | arabam.com</title>
<meta property="og:image" content="https://img.example/clio.jpg"></head><body>
<h1>Renault Clio 1.0 TCe Touch</h1>
${lines(['1.050.000 TL', 'İlan No', '28123456', 'İlan Tarihi', '24 Ekim 2026', 'Marka', 'Renault', 'Seri', 'Clio', 'Model',
  '1.0 TCe Touch', 'Yıl', '2021', 'Kilometre', '48.500 km', 'Vites Tipi', 'Manuel', 'Yakıt Tipi', 'Benzin', 'Renk', 'Beyaz',
  'Boya, Değişen ve Tramer', 'Orijinal', 'Boyalı', 'Lokal boyalı', 'Değişmiş', 'Belirtilmemiş', 'Boyalı', 'Motor Kaputu',
  'Değişmiş', 'Ön Tampon', 'Tramer tutarı', '12.500 TL'])}
</body></html>`;
const row = (id, year, km, price) => `<tr><td><a href="/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/emsal/${id}">Clio 1.0 TCe Touch</a></td><td>${year}</td><td>${km}</td><td>${price} TL</td></tr>`;
const searchHtml = `<!doctype html><html><body><table>${row(28200001, 2020, '62.000', '985.000')}${row(28200002, 2021, '41.000', '1.040.000')}${row(28200003, 2022, '25.000', '1.130.000')}</table></body></html>`;

let failed = 0;
const check = (ok, msg) => { console.log(`${ok ? 'OK  ' : 'HATA'} ${msg}`); if (!ok) failed++; };

const userDir = fs.mkdtempSync(path.join(os.tmpdir(), 'yb-ext-'));
const ctx = await chromium.launchPersistentContext(userDir, {
  channel: 'chromium', // eklentiler hizli kabuk surumunde calismaz; tam Chromium (yeni headless)
  headless: true,
  args: [`--disable-extensions-except=${EXT}`, `--load-extension=${EXT}`],
});
await ctx.route('https://www.arabam.com/**', (route) => {
  const url = route.request().url();
  route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: url.includes('/ilan/') ? listingHtml : searchHtml });
});

let [sw] = ctx.serviceWorkers();
if (!sw) sw = await ctx.waitForEvent('serviceworker', { timeout: 15000 });
const extId = new URL(sw.url()).host;
check(!!extId, `eklenti yuklendi (${extId.slice(0, 8)}...)`);

async function openPopup(pageUrl) {
  const site = await ctx.newPage();
  await site.goto(pageUrl);
  await site.waitForTimeout(500);
  const popup = await ctx.newPage();
  // popup'in "aktif sekme" sorgusu arabam.com sekmesini dondursun
  await popup.addInitScript(() => {
    const orig = chrome.tabs.query.bind(chrome.tabs);
    chrome.tabs.query = (q, cb) => orig({ url: 'https://www.arabam.com/*' }, cb);
  });
  await popup.goto(`chrome-extension://${extId}/popup.html`);
  return { site, popup };
}

// --- 1) Giris + ilan sayfasi kaydi
let { site, popup } = await openPopup(LISTING);
await popup.fill('#api-url', API_URL);
await popup.fill('#api-key', API_KEY);
await popup.click('#login-btn');
await popup.waitForSelector('#main-screen', { state: 'visible', timeout: 15000 });
check(await popup.locator('#ingest-box').isVisible(), 'admin/personel icin "Sisteme Kaydet" bolumu gorunuyor');
check((await popup.textContent('#ingest-btn')).includes('İlanı sisteme kaydet'), 'ilan sayfasinda dogru dugme metni');
await popup.click('#ingest-btn');
await popup.waitForSelector('#ingest-result', { state: 'visible', timeout: 20000 });
const res1 = await popup.textContent('#ingest-result');
console.log('   ->', res1);
check(res1.includes('Kaydedildi') && res1.includes('Renault') && res1.includes('1.050.000'), 'ilan sunucuya kaydedildi');
check(res1.includes('1 boyalı') && res1.includes('1 değişen') && res1.includes('12.500'), 'boya/degisen ve tramer beyani okundu');
await site.close(); await popup.close();

// --- 2) Arama sayfasi: emsal kaydi (marka/model elle)
({ site, popup } = await openPopup(SEARCH));
await popup.waitForSelector('#main-screen', { state: 'visible', timeout: 15000 });
check(await popup.locator('#ingest-search-fields').isVisible(), 'arama sayfasinda marka/model alanlari gorunuyor');
await popup.fill('#ingest-brand', 'Renault');
await popup.fill('#ingest-model', 'Clio');
await popup.click('#ingest-btn');
await popup.waitForSelector('#ingest-result', { state: 'visible', timeout: 20000 });
const res2 = await popup.textContent('#ingest-result');
console.log('   ->', res2);
check(res2.includes('3 / 3'), 'arama sayfasindaki 3 ilanin 3\'u emsal kaydedildi');
await site.close(); await popup.close();

// --- 3) Musteri hesabi: "Sisteme Kaydet" bolumu gorunmez (EXT_CUSTOMER_KEY verilirse)
if (process.env.EXT_CUSTOMER_KEY) {
  ({ site, popup } = await openPopup(LISTING));
  await popup.waitForSelector('#main-screen', { state: 'visible' }); // onceki giris kayitli kalir
  await popup.click('#logout-btn');
  await popup.waitForSelector('#login-screen', { state: 'visible' });
  await popup.fill('#api-url', API_URL);
  await popup.fill('#api-key', process.env.EXT_CUSTOMER_KEY);
  await popup.click('#login-btn');
  await popup.waitForSelector('#main-screen', { state: 'visible', timeout: 15000 });
  await popup.waitForTimeout(500);
  check(!(await popup.locator('#ingest-box').isVisible()), 'musteri hesabinda "Sisteme Kaydet" bolumu gizli');
  await site.close(); await popup.close();
}

// --- 4) Anahtarsiz istek reddedilir
const bad = await fetch(`${API_URL}/api/v1/extension/listing`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
check(bad.status === 401 || bad.status === 422, `anahtarsiz istek reddedildi (${bad.status})`);

await ctx.close();
console.log(failed ? `\n${failed} kontrol BASARISIZ` : '\nTum kontroller gecti');
process.exit(failed ? 1 : 0);
