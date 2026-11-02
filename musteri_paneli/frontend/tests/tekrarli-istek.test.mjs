import test from 'node:test';
import assert from 'node:assert/strict';
import { tekrarliIstek, yenidenDenenebilir, BAGLANTI_KOPTU_MESAJI } from '../src/lib/tekrarliIstek.ts';

const hata = (status, code) => Object.assign(new Error('x'), { status, code });
const hemen = { bekle: async () => {} };

test('vekil zaman aşımından sonra aynı istek yeniden sorulur ve hazır rapor döner', async () => {
  let n = 0;
  const sonuc = await tekrarliIstek(async () => { n += 1; if (n < 3) throw hata(500); return 'rapor'; }, hemen);
  assert.equal(sonuc, 'rapor');
  assert.equal(n, 3);
});

test('iş kuralı hataları (kodlu ya da 4xx) yeniden denenmez', async () => {
  for (const e of [hata(422, 'yetersiz_emsal'), hata(402), hata(500, 'ozel_kod')]) {
    let n = 0;
    await assert.rejects(tekrarliIstek(async () => { n += 1; throw e; }, hemen), e);
    assert.equal(n, 1);
  }
});

test('ağ hatası yeniden denenir; deneme biterse panele yönlendiren mesaj verilir', async () => {
  let n = 0;
  await assert.rejects(tekrarliIstek(async () => { n += 1; throw new TypeError('fetch failed'); }, { ...hemen, deneme: 4 }),
    { message: BAGLANTI_KOPTU_MESAJI });
  assert.equal(n, 4);
  assert.equal(yenidenDenenebilir(hata(504)), true);
  assert.equal(yenidenDenenebilir(hata(400)), false);
});
