import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
import { get } from 'node:http';

const require = createRequire(import.meta.url);
const ts = require('typescript');
const filename = new URL('../next.config.ts', import.meta.url);
const politikaDosyasi = new URL('../src/lib/guvenlikPolitikasi.ts', import.meta.url);
const proxyDosyasi = new URL('../src/proxy.ts', import.meta.url);

function politikaModulu() {
  const module = { exports: {} };
  const source = ts.transpileModule(readFileSync(politikaDosyasi, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  vm.runInNewContext(source, { module, exports: module.exports, crypto: globalThis.crypto, btoa, Uint8Array, String });
  return module.exports;
}

function yonergeler(policy) {
  return new Map(policy.split(';').map(part => part.trim().split(/\s+/)).filter(parts => parts[0]).map(([key, ...values]) => [key, values]));
}

async function kurallar(env = {}) {
  const module = { exports: {} };
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  vm.runInNewContext(source, { module, exports: module.exports, process: { env }, __dirname: filename.pathname, URL });
  const config = module.exports.default;
  assert.equal(typeof config.headers, 'function', 'Tüm site yanıtlarında güvenlik başlıkları gerekir');
  return config.headers();
}

async function basliklar(env = {}) {
  const rules = await kurallar(env);
  const rule = rules.find(rule => rule.source === '/:path*');
  assert.ok(rule, 'Ana sayfa, alt yollar ve dosyalar aynı korumayı almalı');
  return new Map(rule.headers.map(({ key, value }) => [key.toLowerCase(), value]));
}

test('site yanıtları çerçevelemeyi, MIME tahminini ve cihaz izinlerini kısıtlar', async () => {
  const headers = await basliklar();
  assert.equal(headers.get('x-frame-options'), 'DENY');
  assert.equal(headers.get('x-content-type-options'), 'nosniff');
  assert.equal(headers.get('referrer-policy'), 'strict-origin-when-cross-origin');
  assert.equal(headers.get('permissions-policy'), 'camera=(), microphone=(), geolocation=()');
});

test('PayTR dönüşü yalnız kendi sitesinin iframe içinde açılabilir', async () => {
  const rules = await kurallar();
  const headers = new Map();
  for (const rule of rules) {
    if (['/:path*', '/odeme/sonuc'].includes(rule.source)) {
      for (const { key, value } of rule.headers) headers.set(key.toLowerCase(), value);
    }
  }
  assert.equal(headers.get('x-frame-options'), 'SAMEORIGIN');
  const { guvenlikPolitikasi, nonceUret } = politikaModulu();
  const d = yonergeler(guvenlikPolitikasi({ nonce: nonceUret(), ayniKokenCerceve: true }));
  assert.deepEqual(d.get('frame-ancestors'), ["'self'"]);
  assert.ok(d.get('frame-src').includes('https://www.paytr.com'));
});

test('next.config artık rapor modu CSP göndermez; CSP proxy tarafından zorunlu gönderilir', async () => {
  const headers = await basliklar();
  assert.equal(headers.has('content-security-policy-report-only'), false);
  const proxy = readFileSync(proxyDosyasi, 'utf8');
  assert.match(proxy, /export function proxy/);
  assert.match(proxy, /x-nonce/);
  assert.match(proxy, /yanit\.headers\.set\("Content-Security-Policy"/);
  assert.match(proxy, /_next\/static/);
});

test('zorunlu CSP: betikler yalnız nonce ile, eval yalnız geliştirmede', () => {
  const { guvenlikPolitikasi, nonceUret } = politikaModulu();
  const n1 = nonceUret(); const n2 = nonceUret();
  assert.notEqual(n1, n2, 'her istekte yeni nonce');
  assert.ok(n1.length >= 22);
  const d = yonergeler(guvenlikPolitikasi({ nonce: n1 }));
  assert.deepEqual(d.get('default-src'), ["'self'"]);
  assert.deepEqual(d.get('script-src'), ["'self'", `'nonce-${n1}'`, "'strict-dynamic'"]);
  assert.ok(!d.get('script-src').includes("'unsafe-inline'"));
  assert.deepEqual(d.get('object-src'), ["'none'"]);
  assert.deepEqual(d.get('base-uri'), ["'self'"]);
  assert.deepEqual(d.get('frame-ancestors'), ["'none'"]);
  assert.ok(d.get('form-action').includes('https://www.paytr.com'));
  assert.ok(d.get('style-src').includes('https://fonts.googleapis.com'));
  assert.ok(d.get('font-src').includes('https://fonts.gstatic.com'));
  assert.ok(d.get('connect-src').includes('https://api.yerimebak.com.tr'));
  assert.ok(d.get('img-src').includes('blob:'));
  const gelistirme = yonergeler(guvenlikPolitikasi({ nonce: n1, gelistirme: true }));
  assert.ok(gelistirme.get('script-src').includes("'unsafe-eval'"));
  assert.throws(() => guvenlikPolitikasi({ nonce: "x'; script-src *" }));
});

// Üretim derlemesi next start ile açıldığında çalıştırılır; canlıya istek atmaz.
test('yerel üretim HTTP yanıtları zorunlu CSP taşır ve her betik isteğin nonce değerini taşır', {
  skip: !process.env.SITE_SECURITY_TEST_PORT,
}, async () => {
  const port = Number(process.env.SITE_SECURITY_TEST_PORT);
  assert.ok(Number.isInteger(port) && port > 0 && port < 65536);
  const request = (path) => new Promise((resolve, reject) => {
    get({ hostname: '127.0.0.1', port, path }, response => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', chunk => { body += chunk; });
      response.on('end', () => resolve({ statusCode: response.statusCode, headers: response.headers, rawHeaders: response.rawHeaders, body }));
    }).on('error', reject);
  });
  for (const [path, status, frame] of [
    ['/', 200, 'DENY'], ['/arac-analiz', 200, 'DENY'],
    ['/odeme/sonuc?durum=basarili', 200, 'SAMEORIGIN'], ['/olmayan-guvenlik-test-yolu', 404, 'DENY'],
  ]) {
    const response = await request(path);
    assert.equal(response.statusCode, status, path);
    const frameHeaders = response.rawHeaders.filter((_, i) => i % 2 === 0).filter(key => key.toLowerCase() === 'x-frame-options');
    assert.equal(frameHeaders.length, 1, path);
    assert.equal(response.headers['x-frame-options'], frame, path);
    assert.equal(response.headers['x-content-type-options'], 'nosniff', path);
    assert.equal(response.headers['referrer-policy'], 'strict-origin-when-cross-origin', path);
    assert.equal(response.headers['permissions-policy'], 'camera=(), microphone=(), geolocation=()', path);
    assert.equal(response.headers['content-security-policy-report-only'], undefined, path);
    const csp = response.headers['content-security-policy'];
    assert.ok(csp, path);
    const nonce = csp.match(/'nonce-([^']+)'/)?.[1];
    assert.ok(nonce, path);
    if (status === 200) {
      // Çalıştırılabilir her satır içi/dış betik bu isteğin nonce'unu taşımalı.
      for (const tag of response.body.match(/<script[^>]*>/g) ?? []) {
        if (/type="application\/(ld\+)?json"/.test(tag)) continue;
        assert.ok(tag.includes(`nonce="${nonce}"`), `${path}: ${tag.slice(0, 120)}`);
      }
    }
    if (path === '/') {
      assert.match(response.body, /application\/ld\+json/);
      assert.match(response.body, /self\.__next_f/);
      const asset = response.body.match(/(?:src|href)="([^"?]*\/_next\/static\/[^"?]+\.js)/);
      assert.ok(asset);
      const script = await request(asset[1]);
      assert.equal(script.statusCode, 200);
      assert.equal(script.headers['x-content-type-options'], 'nosniff');
    }
    if (frame === 'SAMEORIGIN') assert.match(csp, /frame-ancestors 'self'/);
  }
});
