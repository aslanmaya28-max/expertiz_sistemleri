import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dependency = createRequire(import.meta.url);
const ts = dependency('typescript');
const React = dependency('react');
const { renderToStaticMarkup } = dependency('react-dom/server');
const result = JSON.parse(readFileSync(resolve(root, 'public/ornek-rapor/degerleme.json'), 'utf8'));
function load(relative) {
  const filename = resolve(root, 'src', relative);
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, esModuleInterop: true },
  }).outputText;
  const module = { exports: {} };
  const require = (name) => {
    if (name === 'next/link') return ({ children, ...props }) => React.createElement('a', props, children);
    if (name.endsWith('.json')) return JSON.parse(readFileSync(resolve(dirname(filename), name), 'utf8'));
    if (name.startsWith('@/')) return load(`${name.slice(2)}.tsx`);
    if (name === './AkilliAliciBolumleri') return load('bilesenler/AkilliAliciBolumleri.tsx');
    if (['./Ikon', './Marka', './RaporBasligi', './FiyatOzeti'].includes(name)) return load(`bilesenler/${name.slice(2)}.tsx`);
    return dependency(name);
  };
  // The helper has no JSX and is shared by the real report components.
  const adaptedRequire = (name) => name === '@/lib/ekspertizOnDoldurma' ? load('lib/ekspertizOnDoldurma.ts') : require(name);
  vm.runInNewContext(source, { module, exports: module.exports, require: adaptedRequire, URL, URLSearchParams }, { filename });
  return module.exports;
}

test('örnek rapor gerçek alanları korur ve canlı rapor kimliği taşımaz', () => {
  for (const key of ['success', 'arac', 'piyasa', 'degerleme', 'karar', 'kredi', 'getiri']) assert.ok(key in result, key);
  assert.equal(result.arac.marka, 'Fiat');
  assert.equal(result.arac.ilanLinki, '');
  assert.deepEqual(result.kredi, { dusulen: 1, kalan: 0 });
  assert.equal(result.rapor.id, 'ornek');
  assert.equal(result.rapor.report_no, 'ÖRNEK');
  assert.equal(result.rapor.verification_url, '');
  assert.equal(result.rapor.verification_code, 'YD-ORNEK-0000');
  assert.deepEqual(JSON.stringify(result).match(/YD-[A-Z0-9]+-[A-Z0-9]+/g), ['YD-ORNEK-0000']);
});

test('örnek modunda hesap işlemleri gizlenir; varsayılan canlı mod korunur', () => {
  const Component = load('bilesenler/DegerlemeSonucu.tsx').default;
  const before = JSON.stringify(result);
  const render = (props) => renderToStaticMarkup(React.createElement(Component, { sonuc: result, onYeni: () => {}, ...props }));
  const sample = render({ ornek: true });
  const live = render({});
  for (const text of ['Rapor kaydedildi', '/panel/degerlemeler/', '/dogrula/', 'Yeni analiz', '/valuation/reports/', 'kredi kullanıldı']) assert.ok(!sample.includes(text), text);
  for (const text of ['Rapor kaydedildi', '/panel/degerlemeler/', '/dogrula/', 'Yeni analiz']) assert.ok(live.includes(text), text);
  assert.ok(sample.includes('Bu aracı yerinde inceletelim'));
  assert.ok(sample.includes('Pazarlık planı'));
  assert.equal(JSON.stringify(result), before);
});

test('örnek sayfa aynı raporu, tarihi, fiyatı ve gerçek hedeflere giden çağrıları sunar', () => {
  const { default: Page, metadata } = load('app/ornek-rapor/page.tsx');
  const html = renderToStaticMarkup(React.createElement(Page));
  assert.equal(metadata.title, 'Örnek araç değerleme raporu | YerimeBak');
  for (const text of ['Bu, gerçek bir araç için oluşturulmuş örnek değerleme raporudur. 1 kredi (100 TL) ile kendi aracınız için aynısını alırsınız.', 'Örnek tarihi:', '02.11.2026', 'Pazarlık planı', 'pointer-events-none', 'ÖRNEK', 'Kendi aracım için değerleme al (1 kredi)', 'Kredi paketleri', 'PDF örneğini indir']) assert.ok(html.includes(text), text);
  for (const href of ['/arac-analiz', '/fiyatlar', '/ornek-rapor/degerleme-ornek.pdf']) assert.ok(html.includes(`href="${href}"`), href);
  for (const text of ['AI Puanı', 'Tahmini Kâr', 'Likidite', '/dogrula/', 'Rapor kaydedildi', '/valuation/reports/']) assert.ok(!html.includes(text), text);
});

test('kayıt ve fiyat ekranları koşulsuz ücretsiz analiz sözü vermez', () => {
  for (const path of ['app/arac-analiz/page.tsx', 'app/kayit-ol/page.tsx', 'app/eposta-dogrula/page.tsx', 'bilesenler/EpostaDogrulamaUyarisi.tsx', 'bilesenler/FiyatKartlari.tsx', 'app/ornek-rapor/page.tsx']) {
    const source = readFileSync(resolve(root, 'src', path), 'utf8');
    assert.doesNotMatch(source, /ücretsiz|[Hh]ediye/, path);
  }
  for (const path of ['app/arac-analiz/page.tsx', 'bilesenler/FiyatKartlari.tsx']) assert.ok(readFileSync(resolve(root, 'src', path), 'utf8').includes('/ornek-rapor'), path);
  for (const path of ['app/iptal-iade/page.tsx', 'app/kullanim-kosullari/page.tsx', 'app/kvkk/page.tsx']) assert.doesNotMatch(readFileSync(resolve(root, 'src', path), 'utf8'), /hoş geldin kred|ücretsiz kredi/i, path);
});
