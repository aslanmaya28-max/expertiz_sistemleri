import test from 'node:test';
import assert from 'node:assert/strict';
import { siteIciDonus, uyelikAdresi } from '../src/lib/uyelikYonlendirme.ts';

test('login return cannot normalize into an external URL', () => {
  for (const target of ['/a/..//example.invalid', '/a/%2e%2e//example.invalid', '/a/.%2e//example.invalid']) {
    assert.equal(siteIciDonus(target), '/panel', target);
  }
});

test('registration retains the local request and selected listing', () => {
  assert.equal(siteIciDonus('/ekspertiz-talebi?aracId=123'), '/ekspertiz-talebi?aracId=123');
  assert.equal(uyelikAdresi('/ekspertiz-talebi?aracId=123'), '/kayit-ol?donus=%2Fekspertiz-talebi%3FaracId%3D123');
});

test('external and malformed returns fall back to the customer panel', () => {
  for (const target of [null, '', 'https://example.invalid', '//example.invalid', '/\\example.invalid', '/\n/example.invalid']) {
    assert.equal(siteIciDonus(target), '/panel');
  }
});
