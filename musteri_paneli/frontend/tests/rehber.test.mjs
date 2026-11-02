import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dependency = createRequire(import.meta.url);
const ts = dependency('typescript');
const React = dependency('react');
const { renderToStaticMarkup } = dependency('react-dom/server');
const slugs = ['ikinci-el-arac-alirken-kontrol-listesi', 'tramer-kaydi-nedir',
  'boyali-degisen-parca-fiyat-etkisi', 'ilan-fiyati-dogru-mu-nasil-anlasilir'];
const paths = ['/rehber', ...slugs.map((slug) => `/rehber/${slug}`)];

function load(relative) {
  const filename = resolve(root, 'src', relative);
  const compiled = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2020, esModuleInterop: true },
  }).outputText;
  const module = { exports: {} };
  const require = (name) => {
    if (name === 'next/link') return ({ children, ...props }) => React.createElement('a', props, children);
    if (name.startsWith('@/')) {
      const target = name.slice(2);
      return load([`${target}.ts`, `${target}.tsx`].find((path) => existsSync(resolve(root, 'src', path))));
    }
    return dependency(name);
  };
  vm.runInNewContext(compiled, { module, exports: module.exports, require }, { filename });
  return module.exports;
}

const { SITE_URL, ISLETME } = load('lib/hizmetBilgisi.ts');
const render = (Component, props = {}) => renderToStaticMarkup(React.createElement(Component, props));
const schemas = (html) => [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)]
  .map((match) => JSON.parse(match[1]));
const escaped = (value) => renderToStaticMarkup(React.createElement('span', null, value)).slice(6, -7);

test('ortak rehber iskeleti kimlik, SSS ve güvenli JSON-LD üretir', () => {
  const Component = load('bilesenler/RehberSayfasi.tsx').default;
  const question = 'Kapsam nedir?';
  const answer = 'Yerinde inceleme ile değerleme ayrı hizmetlerdir.';
  const title = 'Başlık </script><script>alert(1)</script>';
  const html = render(Component, { slug:'test', baslik:title, ozet:'Özgün açıklama',
    guncellemeTarihi:'2026-11-02', kisaca:['Bir','İki','Üç'],
    bolumler:[{id:'kapsam',baslik:'Kapsam',icerik:'Bilgi'}],
    sorular:[{soru:question,yanit:answer}],
    cta:{href:'/arac-degerleme',etiket:'Değerleme',aciklama:'Araç görülmez.'},
  });
  const data = schemas(html);
  const article = data.find((s) => s['@type'] === 'Article');
  assert.equal(article.headline, title);
  assert.equal(article.dateModified, '2026-11-02');
  assert.equal(article.publisher['@id'], ISLETME['@id']);
  assert.equal(article.author['@id'], ISLETME['@id']);
  assert.equal(article.mainEntityOfPage['@id'] ?? article.mainEntityOfPage, `${SITE_URL}/rehber/test`);
  assert.ok(!html.includes('</script><script>alert(1)</script>'));
  assert.ok(html.includes(escaped(question)) && html.includes(escaped(answer)));
});

for (const slug of slugs) test(`${slug}: metadata, görünür SSS ve üç şema tutarlı`, () => {
  const { default: Page, metadata } = load(`app/rehber/${slug}/page.tsx`);
  const html = render(Page);
  const data = schemas(html);
  const canonical = `${SITE_URL}/rehber/${slug}`;
  assert.equal(metadata.alternates.canonical, canonical);
  assert.ok(metadata.title && metadata.description);
  assert.ok(!metadata.title.includes('| YerimeBak'));
  const article = data.find((s) => s['@type'] === 'Article');
  const faq = data.find((s) => s['@type'] === 'FAQPage');
  const crumbs = data.find((s) => s['@type'] === 'BreadcrumbList');
  assert.ok(article && faq && crumbs);
  assert.equal(article.inLanguage, 'tr-TR');
  assert.equal(article.dateModified, '2026-11-02');
  assert.equal(article.mainEntityOfPage['@id'] ?? article.mainEntityOfPage, canonical);
  assert.equal(article.author['@id'], ISLETME['@id']);
  assert.equal(article.publisher['@id'], ISLETME['@id']);
  assert.equal(crumbs.itemListElement.length, 3);
  assert.equal(crumbs.itemListElement[1].item, `${SITE_URL}/rehber`);
  assert.equal(crumbs.itemListElement[2].item, canonical);
  assert.ok(faq.mainEntity.length >= 3 && faq.mainEntity.length <= 5);
  for (const question of faq.mainEntity) {
    assert.ok(html.includes(escaped(question.name)));
    assert.ok(html.includes(escaped(question.acceptedAnswer.text)));
  }
  const shortBox = html.match(/<section[^>]*aria-label="Kısaca"[^>]*>([\s\S]*?)<\/section>/)?.[1];
  assert.ok(shortBox);
  const count = [...shortBox.matchAll(/<li(?:\s|>)/g)].length;
  assert.ok(count >= 3 && count <= 5);
  assert.equal([...html.matchAll(/<h1(?:\s|>)/g)].length, 1);
  assert.match(html, /href="\/(?:yerinde-inceleme|arac-degerleme)"/);
});

test('rehber listesi ve hizmet bağlantıları tüm rehberleri keşfedilebilir kılar', () => {
  const { default: Page, metadata } = load('app/rehber/page.tsx');
  const html = render(Page);
  assert.equal(metadata.alternates.canonical, `${SITE_URL}/rehber`);
  for (const slug of slugs) assert.ok(html.includes(`href="/rehber/${slug}"`), slug);
  assert.ok(readFileSync(resolve(root, 'src/bilesenler/AltBilgi.tsx'), 'utf8').includes('href="/rehber"'));
  for (const service of ['yerinde-inceleme','arac-degerleme']) {
    const page = readFileSync(resolve(root, `src/app/${service}/page.tsx`), 'utf8');
    const links = [...page.matchAll(/href="\/rehber\/[^"]+"/g)];
    assert.ok(links.length >= 2 && links.length <= 3, service);
  }
});

test('sitemap tüm yolları gerçek sayfalara bağlar; rehberler llms ve sitemap içinde yer alır', () => {
  const xml = readFileSync(resolve(root, 'public/sitemap.xml'), 'utf8');
  const llms = readFileSync(resolve(root, 'public/llms.txt'), 'utf8');
  for (const [, loc] of xml.matchAll(/<loc>([^<]+)<\/loc>/g)) {
    const url = new URL(loc);
    assert.equal(url.origin, SITE_URL);
    assert.ok(existsSync(resolve(root, 'src/app', `.${url.pathname}`, 'page.tsx')), url.pathname);
  }
  assert.ok(llms.includes('## Rehber'));
  for (const path of paths) {
    assert.ok(xml.includes(`<loc>${SITE_URL}${path}</loc>`), path);
    assert.ok(llms.includes(`${SITE_URL}${path}`), path);
    const entry = xml.match(new RegExp(`<url>\\s*<loc>${SITE_URL.replaceAll('.', '\\.')}\\${path}</loc>([\\s\\S]*?)</url>`));
    assert.ok(entry && entry[1].includes('<lastmod>2026-11-02</lastmod>'), path);
  }
});

test('rehberler gerçek dışı üstünlük veya kesin sonuç vaadi içermez', () => {
  for (const slug of slugs) {
    const source = readFileSync(resolve(root, `src/app/rehber/${slug}/page.tsx`), 'utf8');
    assert.doesNotMatch(source, /garanti ederiz|%100|en ucuz|en iyi/iu, slug);
    assert.doesNotMatch(source, /\d+(?:[.,]\d+)?\s*%|%\s*\d+/u, slug);
  }
});
