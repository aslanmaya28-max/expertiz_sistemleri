import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
import { get } from 'node:http';

const require = createRequire(import.meta.url);
const ts = require('typescript');
const filename = new URL('../next.config.ts', import.meta.url);

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

test('PayTR dönüşü yalnız kendi sitesinin iframe içinde açılıp üst pencereye geçebilir', async () => {
  const rules = await kurallar();
  const headers = new Map();
  for (const rule of rules) {
    if (['/:path*', '/odeme/sonuc'].includes(rule.source)) {
      for (const { key, value } of rule.headers) headers.set(key.toLowerCase(), value);
    }
  }
  assert.equal(headers.get('x-frame-options'), 'SAMEORIGIN');
  assert.match(headers.get('content-security-policy-report-only'), /frame-src 'self' https:\/\/www.paytr.com/);
  assert.match(headers.get('content-security-policy-report-only'), /frame-ancestors 'self'/);
});

test('CSP yalnız rapor modunda, dar betik kaynakları ve mevcut ödeme/font izinleriyle gönderilir', async () => {
  const headers = await basliklar();
  assert.equal(headers.has('content-security-policy'), false, 'Satır içi Next/JSON-LD henüz nonce taşımıyor');
  const policy = headers.get('content-security-policy-report-only');
  assert.ok(policy);
  const directives = new Map(policy.split(';').map(part => part.trim().split(/\s+/)).filter(parts => parts[0]).map(([key, ...values]) => [key, values]));
  assert.deepEqual(directives.get('default-src'), ["'self'"]);
  assert.deepEqual(directives.get('script-src'), ["'self'"]);
  assert.deepEqual(directives.get('object-src'), ["'none'"]);
  assert.deepEqual(directives.get('base-uri'), ["'self'"]);
  assert.deepEqual(directives.get('frame-ancestors'), ["'none'"]);
  assert.ok(directives.get('frame-src').includes('https://www.paytr.com'));
  assert.ok(directives.get('form-action').includes('https://www.paytr.com'));
  assert.ok(directives.get('style-src').includes('https://fonts.googleapis.com'));
  assert.ok(directives.get('font-src').includes('https://fonts.gstatic.com'));
  assert.ok(directives.get('connect-src').includes('https://api.yerimebak.com.tr'));
  assert.ok(directives.get('img-src').includes('blob:'));
});

// Üretim derlemesi next start ile açıldığında çalıştırılır; canlıya istek atmaz.
test('yerel üretim HTTP yanıtları tek çerçeve başlığı taşır ve Next/JSON-LD betiklerini engellemez', {
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
    assert.equal(response.headers['content-security-policy'], undefined, path);
    assert.ok(response.headers['content-security-policy-report-only'], path);
    if (path === '/') {
      assert.match(response.body, /application\/ld\+json/);
      assert.match(response.body, /self\.__next_f/);
      const asset = response.body.match(/(?:src|href)="([^"?]*\/_next\/static\/[^"?]+\.js)/);
      assert.ok(asset);
      const script = await request(asset[1]);
      assert.equal(script.statusCode, 200);
      assert.equal(script.headers['x-content-type-options'], 'nosniff');
    }
    if (frame === 'SAMEORIGIN') assert.match(response.headers['content-security-policy-report-only'], /frame-ancestors 'self'/);
  }
});
