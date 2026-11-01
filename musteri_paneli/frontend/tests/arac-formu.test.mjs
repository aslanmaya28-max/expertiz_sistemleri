import test from 'node:test';
import assert from 'node:assert/strict';
import { ARAC_KATALOGU, MARKALAR, binlikNokta, degerlemeFormHatasi, katalogAra, modelleri, sadeceRakam, sadelestir } from '../src/lib/aracFormu.ts';

test('Türkçe ve aksanlı harflerle arama', () => {
  assert.equal(sadelestir('ŞKODA Çığ İzmir'), 'skoda cig izmir');
  assert.deepEqual(katalogAra(MARKALAR, 'mercedes'), ['Mercedes-Benz']);
  assert.deepEqual(katalogAra(MARKALAR, 'citroën'), ['Citroen']);
  assert.ok(katalogAra(MARKALAR, 'land')[0] === 'Land Rover');
  // Başı eşleşenler önce gelir, kelime başı da sayılır
  assert.deepEqual(katalogAra(modelleri('BYD'), 'seal').slice(0, 3), ['Seal', 'Seal U', 'Seal U DM-i']);
  assert.ok(katalogAra(modelleri('Toyota'), 'cross').includes('Corolla Cross'));
  assert.deepEqual(katalogAra(MARKALAR, 'zzzz'), []);
});

test('marka yazımı farklı olsa da modeller bulunur', () => {
  assert.deepEqual(modelleri('mercedes-benz'), ARAC_KATALOGU['Mercedes-Benz']);
  assert.deepEqual(modelleri('Škoda'), ARAC_KATALOGU.Skoda);
  assert.deepEqual(modelleri('LAND ROVER'), ARAC_KATALOGU['Land Rover']);
  assert.deepEqual(modelleri('Bilinmeyen'), []);
  assert.deepEqual(modelleri(''), []);
});

test('katalog tekrar içermez ve markalar sıralı', () => {
  for (const [marka, liste] of Object.entries(ARAC_KATALOGU)) assert.equal(new Set(liste).size, liste.length, marka);
  assert.equal(MARKALAR.length, Object.keys(ARAC_KATALOGU).length);
});

test('sayı alanı: rakam ayıklama ve binlik nokta', () => {
  assert.equal(sadeceRakam('24.000 km'), '24000');
  assert.equal(sadeceRakam('1.976.000 TL'), '1976000');
  assert.equal(sadeceRakam('007'), '7');
  assert.equal(sadeceRakam('0'), '0');
  assert.equal(sadeceRakam('12345678', 4), '1234');
  assert.equal(binlikNokta('24000'), '24.000');
  assert.equal(binlikNokta('1976000'), '1.976.000');
  assert.equal(binlikNokta('999'), '999');
  assert.equal(binlikNokta(''), '');
});

test('gönderim öncesi kontrol sunucu sınırlarıyla aynı', () => {
  const tamam = { year: '2024', km: '24000', price: '1976000' };
  assert.equal(degerlemeFormHatasi(tamam, 2026), null);
  assert.match(degerlemeFormHatasi({ ...tamam, year: '1975' }, 2026), /Model yılı/);
  assert.match(degerlemeFormHatasi({ ...tamam, year: '2028' }, 2026), /Model yılı/);
  assert.equal(degerlemeFormHatasi({ ...tamam, year: '2027' }, 2026), null);
  assert.match(degerlemeFormHatasi({ ...tamam, km: '2000001' }, 2026), /Kilometre/);
  assert.match(degerlemeFormHatasi({ ...tamam, price: '9999' }, 2026), /fiyatı/);
});
