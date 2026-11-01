import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeVerificationCode, isVerificationCode } from '../src/lib/raporDogrulama.ts';

test('rapordaki kod boşluk ve küçük harflerle yapıştırılabilir', () => {
  const code = normalizeVerificationCode('  yb-a2b3-c4d5 \n');
  assert.equal(code, 'YB-A2B3-C4D5');
  assert.equal(isVerificationCode(code), true);
});

test('boş, eksik ve adres içeren kodlar sorgulanmaz', () => {
  for (const code of ['', 'YB-ABC-1234', 'YB-ABCD-12345', '../rapor', 'YB-ABCD-1234?x=1', 'YB-ABCD-1234\n']) {
    assert.equal(isVerificationCode(code), false, code);
  }
});
