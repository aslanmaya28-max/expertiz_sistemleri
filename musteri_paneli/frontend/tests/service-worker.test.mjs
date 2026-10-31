import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

function fetchHandler() {
  const handlers = {};
  const self = {location: {origin: 'http://127.0.0.1:18802'}, addEventListener: (name, fn) => {handlers[name] = fn;}};
  vm.runInNewContext(readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8'), {
    self, URL, caches: {match: async () => 'stale-code'}, fetch: async () => ({ok: false}),
  });
  return handlers.fetch;
}

for (const path of ['/ekspertiz-talebi', '/_next/static/chunks/app.js', '/api/v1/expertiz/packages']) {
  test(`does not serve cached application state for ${path}`, () => {
    let intercepted = false;
    fetchHandler()({request: {method: 'GET', url: `http://127.0.0.1:18802${path}`},
      respondWith: () => {intercepted = true;}});
    assert.equal(intercepted, false);
  });
}
