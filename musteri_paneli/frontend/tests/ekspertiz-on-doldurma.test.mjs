import test from 'node:test';
import assert from 'node:assert/strict';
import { ekspertizTalepAdresi, ekspertizOnDoldurma, guvenliWebAdresi } from '../src/lib/ekspertizOnDoldurma.ts';

test('rapordaki araç ve beyanlar düzenlenebilir forma kayıpsız taşınır', () => {
  const url = ekspertizTalepAdresi({ marka: 'Škoda', model: 'Octavia', paket: '1.5 TSI', yil: 2020, km: 85000, ilanFiyati: 1250000, yakit: 'Benzin', vites: 'Otomatik', ilanLinki: 'https://ilan.example/a?x=1&y=2', beyanEdilenParcalar: { kaput: 'boyali', sol: 'lokal_boyali', sag: 'degisen', tavan: 'orijinal' }, tramerTutari: 25000 });
  assert.ok(url.startsWith('/ekspertiz-talebi?'));
  assert.deepEqual(ekspertizOnDoldurma(new URL(url, 'https://yerimebak.com.tr').searchParams), {
    brand: 'Škoda', model: 'Octavia', package: '1.5 TSI', year: '2020', km: '85000', price: '1250000', fuel: 'Benzin', gear: 'Otomatik', link: 'https://ilan.example/a?x=1&y=2', declaredPainted: '2', declaredChanged: '1', declaredTramer: '25000',
  });
});

test('geçersiz, sınırsız veya kesirli tam sayı değerleri forma alınmaz', () => {
  const invalid = new URLSearchParams({ brand: 'a'.repeat(121), model: 'A\nB', year: 'Infinity', km: '-1', price: 'NaN', declaredPainted: '1.5', declaredChanged: '999', declaredTramer: '1e999', link: 'javascript:alert(1)' });
  assert.deepEqual(ekspertizOnDoldurma(invalid), {});
  for (const year of ['0', '9999', '2020.5', '0x7e4']) assert.equal(ekspertizOnDoldurma(new URLSearchParams({year})).year, undefined);
});

test('yalnız http ve https kaynakları açılabilir; eski rapor beyanı uydurulmaz', () => {
  for (const url of ['javascript:alert(1)', 'data:text/html,x', '//example.com', 'https://', 'https://user:pass@example.com', 'https://example.com/\n']) assert.equal(guvenliWebAdresi(url), undefined);
  assert.equal(guvenliWebAdresi('https://example.com/a'), 'https://example.com/a');
  const params = new URL(ekspertizTalepAdresi({ marka: 'Ford', model: 'Focus', yil: 2018, km: 0, ilanFiyati: 1000000 }), 'https://yerimebak.com.tr').searchParams;
  assert.equal(params.has('declaredPainted'), false);
  assert.equal(params.get('km'), '0');
});
