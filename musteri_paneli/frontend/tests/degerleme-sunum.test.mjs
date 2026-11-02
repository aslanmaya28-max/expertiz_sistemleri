import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const localRequire = createRequire(import.meta.url);
const dependency = (name) => localRequire(name);
const ts = dependency('typescript');
const React = dependency('react');
const { renderToStaticMarkup } = dependency('react-dom/server');

function load(relative) {
  const filename = resolve(here, '../src', relative);
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const module = { exports: {} };
  const require = (name) => {
    if (name === 'next/link') return { default: ({ children, ...props }) => React.createElement('a', props, children) };
    if (name === './AkilliAliciBolumleri') return load('bilesenler/AkilliAliciBolumleri.tsx');
    if (name === '@/lib/ekspertizOnDoldurma') return load('lib/ekspertizOnDoldurma.ts');
    return dependency(name);
  };
  vm.runInNewContext(source, { module, exports: module.exports, require, URL, URLSearchParams }, { filename });
  return module.exports;
}

const { default: DegerlemeSonucu } = load('bilesenler/DegerlemeSonucu.tsx');
const { AkilliAliciBolumleri } = load('bilesenler/AkilliAliciBolumleri.tsx');
const result = {
  arac: { marka: 'Hyundai', model: 'Tucson', yil: 2021, km: 66000, ilanFiyati: 2200000 },
  piyasa: { emsalSayisi: 5, kaynaklar: [], uyarilar: [], guvenSkoru: 35 },
  degerleme: { kalemler: [] },
  karar: { sonuc: 'EK DOĞRULAMA GEREKLİ', aciklama: 'YALNIZ ADMIN', hesaplananEgilim: 'ALMA', guvenSeviyesi: 'dusuk' },
  kredi: { dusulen: 1, kalan: 5 },
};
const render = (Component, sonuc) => renderToStaticMarkup(React.createElement(Component, { sonuc }));

test('karar verisi müşteriye gösterilmez; fiyatlar ve küçük emsal notu korunur', () => {
  for (const count of [2, 3, 4, 5, 8]) {
    const legacyWarning = `Yalnızca ${count} doğrulanmış emsal ilan bulundu (hedef 5)`;
    const sonuc = { ...result, piyasa: { ...result.piyasa, emsalSayisi: count, uyarilar: [legacyWarning, 'Fiyat aralığı geniş; ilanları karşılaştırın.'] } };
    sonuc.ozet = { piyasaKonumu: { metin: 'Piyasa üstünde' }, adilFiyat: {}, riskler: [`${legacyWarning}.`, 'Boya beyanını doğrulayın.'], pazarlikGerekceleri: [], simdiNeYapmali: 'Uzman incelemesi isteyin.' };
    const original = JSON.stringify(sonuc);
    const html = render(DegerlemeSonucu, sonuc);
    for (const hidden of ['EK DOĞRULAMA', 'YALNIZ ADMIN', 'Hesaplanan eğilim', 'Veri güveni']) assert.ok(!html.includes(hidden));
    assert.ok(html.includes('Tavsiye alım fiyatı'));
    assert.equal(html.includes("5&#x27;ten az olduğu için fiyatlar yön göstericidir."), [3, 4].includes(count));
    assert.equal(html.includes(legacyWarning), ![3, 4].includes(count));
    assert.ok(html.includes('Fiyat aralığı geniş; ilanları karşılaştırın.'));
    assert.ok(html.includes('Boya beyanını doğrulayın.'));
    assert.equal(JSON.stringify(sonuc), original);
  }
});

test('şikâyet bölümü eski kayıtta gizli, boş listede açıklamalı, dolu listede güvenli kaynaklıdır', () => {
  const title = 'Kullanıcıların en sık şikâyet ettiği konular';
  assert.ok(!render(AkilliAliciBolumleri, result).includes(title));
  const empty = render(AkilliAliciBolumleri, { ...result, kullaniciSikayetleri: [] });
  assert.ok(empty.includes(title));
  assert.ok(empty.includes('Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.'));
  assert.ok(empty.includes('Forum ve kullanıcı yorumlarından derlenmiştir; kullanıcı beyanıdır, arıza teşhisi değildir.'));
  const html = render(AkilliAliciBolumleri, { ...result, kullaniciSikayetleri: [{ baslik: 'Vites geçişi', aciklama: 'Kullanıcı beyanı', kaynakSayisi: 2, kaynaklar: ['https://forum.example/tucson', 'javascript:alert(1)'] }] });
  assert.ok(html.includes('Vites geçişi'));
  assert.ok(html.includes('2 farklı kaynakta geçiyor'));
  assert.ok(html.includes('href="https://forum.example/tucson"'));
  assert.ok(html.includes('rel="noopener noreferrer nofollow"'));
  assert.ok(!html.includes('javascript:'));
});
