import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';

const require = createRequire(import.meta.url);
const ts = require('typescript');
const source = ts.transpileModule(readFileSync(new URL('../src/lib/api.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;

test('kredi hareketleri kimlikli ve sayfali istenir; analiz gecmisi eski ucta kalir', async () => {
  const calls = [];
  const module = { exports: {} };
  const response = { movements: [{ id: 9, tur: 'yukleme', miktar: 5 }], total: 23, balance: 7 };
  vm.runInNewContext(source, {
    module, exports: module.exports, process: { env: {} },
    require: (name) => {
      assert.equal(name, '@/lib/yetki');
      return { getToken: () => 'test-session', removeToken: () => {} };
    },
    fetch: async (url, options) => {
      calls.push({ url, options });
      return { ok: true, status: 200, json: async () => response };
    },
  });
  assert.equal(await module.exports.getCreditMovements(20, 20), response);
  assert.equal(calls[0].url, '/api/v1/credits/movements?limit=20&offset=20');
  assert.equal(calls[0].options.headers.Authorization, 'Bearer test-session');
  await module.exports.getAnalysisHistory();
  assert.equal(calls[1].url, '/api/v1/credits/history');
});
