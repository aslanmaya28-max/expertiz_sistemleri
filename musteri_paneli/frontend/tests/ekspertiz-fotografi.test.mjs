import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
const require = createRequire(import.meta.url);
const ts = require('typescript');
function load(path, extras = {}) {
  const module = { exports: {} };
  const source = ts.transpileModule(readFileSync(new URL(path, import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  vm.runInNewContext(source, { module, exports: module.exports, ...extras });
  return module.exports;
}
test('fotoğraf sınırları ve belirsiz parçalar korunur', () => {
  const lib = load('../src/lib/ekspertizFotografi.ts');
  const image = { name: 'rapor.heic', size: 100, type: '' };
  assert.equal(lib.raporFotografiHatasi([image]), null);
  // WhatsApp/telefon ekran görüntüsü WEBP olabilir (08.11.2026).
  assert.equal(lib.raporFotografiHatasi([{ ...image, name: 'ekran.webp' }]), null);
  assert.match(lib.raporFotografiHatasi([]), /1–4/);
  assert.match(lib.raporFotografiHatasi(Array(5).fill(image)), /1–4/);
  assert.match(lib.raporFotografiHatasi([{ ...image, size: 8 * 1024 * 1024 + 1 }]), /8 MB/);
  assert.match(lib.raporFotografiHatasi([{ ...image, name: 'sahte.pdf', type: 'application/pdf' }]), /JPEG/);
  const result = lib.fotoOnDolum({ parts: { kaput: 'boyali' }, tramer_amount: null, bulgular: [] }, ['kaput', 'tavan']);
  assert.deepEqual(JSON.parse(JSON.stringify(result.parts)), { kaput: 'boyali' });
  assert.equal(result.tramer, '');
  assert.equal(result.belirsiz.join(','), 'tavan');
  assert.equal(result.origins['parts.kaput'].kaynak, 'ekspertiz_raporu');
});
test('yükleme kimliklidir, tarayıcı multipart sınırını kurar ve 401 oturumu temizler', async () => {
  const calls = []; let removed = false;
  const api = load('../src/lib/api.ts', {
    process: { env: {} }, FormData,
    require: () => ({ getToken: () => 'token', removeToken: () => { removed = true; } }),
    fetch: async (url, options) => { calls.push({ url, options }); return { ok: false, status: 401, json: async () => ({ detail: 'Oturum bitti' }) }; },
    window: { location: { pathname: '/arac-analiz', href: '' }, dispatchEvent() {} }, Event,
  });
  await assert.rejects(api.uploadInspectionPhoto([new File(['image'], 'rapor.png', { type: 'image/png' })]), /Oturum bitti/);
  assert.equal(calls[0].url, '/api/v1/valuation/inspection-photo');
  assert.equal(calls[0].options.headers.Authorization, 'Bearer token');
  assert.equal(calls[0].options.headers['Content-Type'], undefined);
  assert.equal(calls[0].options.body.getAll('files').length, 1);
  assert.equal(removed, true);
});

test('şemada okunmayan parça orijinal etiketi almaz', () => {
  const React = require('react');
  const { renderToStaticMarkup } = require('react-dom/server');
  const module = { exports: {} };
  const source = ts.transpileModule(readFileSync(new URL('../src/bilesenler/AracFormAlanlari.tsx', import.meta.url), 'utf8'), {
    compilerOptions: { jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  vm.runInNewContext(source, { module, exports: module.exports, require: (name) => name === '@/lib/aracFormu' ? {} : require(name) });
  const html = renderToStaticMarkup(React.createElement(module.exports.AracSemasi, {
    parcalar: {}, etiketler: { tavan: 'Tavan' }, belirsiz: ['tavan'], onDegistir() {},
  }));
  assert.ok(html.includes('aria-label="Tavan: Belirtilmedi"'));
  assert.ok(!html.includes('aria-label="Tavan: Orijinal"'));
  assert.ok(!html.includes('tüm parçalar orijinal sayılır'));
});
