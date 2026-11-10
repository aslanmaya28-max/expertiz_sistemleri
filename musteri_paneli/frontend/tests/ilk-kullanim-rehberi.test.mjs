import test from 'node:test';
import assert from 'node:assert/strict';
import { REHBER_ADIMLARI, REHBER_ANAHTARI, rehberGorulmusMu, rehberiTamamla, baloncukKonumu, sonAdimMetni } from '../src/lib/ilkKullanimRehberi.ts';

test('rehber mevcut değerleme akışını beş kısa adımda açıklar', () => {
  assert.deepEqual(REHBER_ADIMLARI.map(a => a.hedef), ['ilan', 'bilgiler', 'kaporta', 'fotograf', 'degerle']);
  assert.equal(new Set(REHBER_ADIMLARI.map(a => a.baslik)).size, 5);
  assert.match(REHBER_ADIMLARI[3].metin, /isteğe bağlı/);
  assert.match(sonAdimMetni(0), /kredi hesabınıza tanımlandığında/i);
  assert.match(sonAdimMetni(5), /1 kredi/);
  assert.match(sonAdimMetni(null), /Raporlarım/);
  assert.doesNotMatch(sonAdimMetni(0), /satın|kredi-yukle/i);
});

for (const neden of ['atla', 'bitir']) {
  test(`${neden} sonrası yeni sayfa ziyareti otomatik turu açmaz`, () => {
    const data = new Map();
    const storage = { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value) };
    assert.equal(rehberGorulmusMu(() => storage), false);
    rehberiTamamla(() => storage, neden);
    assert.equal(data.get(REHBER_ANAHTARI), '1');
    assert.equal(rehberGorulmusMu(() => storage), true);
  });
}

test('localStorage nesnesi veya metotları erişilemese bile rehber çalışır', () => {
  const engelli = () => { throw new Error('SecurityError'); };
  assert.equal(rehberGorulmusMu(engelli), false);
  assert.doesNotThrow(() => rehberiTamamla(engelli, 'atla'));
  const dolu = () => ({ getItem() { throw new Error('denied'); }, setItem() { throw new Error('quota'); } });
  assert.equal(rehberGorulmusMu(dolu), false);
  assert.doesNotThrow(() => rehberiTamamla(dolu, 'bitir'));
});

test('bilgi baloncuğu 360 px ekranda kenarları aşmaz ve düğmeyi örtmez', () => {
  for (const left of [0, 170, 340]) {
    const box = baloncukKonumu({ left, right: left + 20, top: 100, bottom: 120 }, 360, 800, 320, 100);
    assert.ok(box.left >= 12);
    assert.ok(box.left + box.width <= 348);
    assert.ok(box.top >= 128);
  }
  const bottom = baloncukKonumu({ left: 330, right: 350, top: 740, bottom: 760 }, 360, 800, 320, 100);
  assert.ok(bottom.top + 100 <= 732);
});
