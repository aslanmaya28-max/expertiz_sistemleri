import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import postcss from 'postcss';

const css = postcss.parse(readFileSync(new URL('../src/app/scroll-deneyimi.css', import.meta.url), 'utf8'));
const reduced = [];
css.walkAtRules('media', (media) => {
  if (/prefers-reduced-motion\s*:\s*reduce/.test(media.params)) reduced.push(media);
});

function declarations(selector) {
  const values = {};
  for (const media of reduced) media.walkRules((rule) => {
    if (!rule.selectors.includes(selector)) return;
    rule.walkDecls((d) => { values[d.prop] = d.value; });
  });
  return values;
}

test('azaltılmış harekette kart yığılması normal akışa döner', () => {
  assert.equal(declarations('.yb-home .yb-stack-card').position, 'relative');
  assert.equal(declarations('.yb-home .yb-stack-card').top, 'auto');
});

test('azaltılmış harekette süzülme ve bütün anlatı dönüşümleri kapalıdır', () => {
  for (const selector of ['.yb-home [data-sc-in]', '.yb-home [data-sc-reveal]', '.yb-home [data-page-motion] *']) {
    assert.equal(declarations(selector).transform, 'none');
    assert.equal(declarations(selector).opacity, '1');
    assert.equal(declarations(selector).transition, 'none');
  }
});

test('JavaScript olmadan kartlar görünür; gizleme yalnız hazır sahnede uygulanır', () => {
  css.walkDecls('opacity', (d) => {
    if (d.value === '0') assert.match(d.parent.selector, /\[data-motion="ready"\]/);
  });
  css.walkRules((rule) => {
    if (!rule.selector.includes('[data-sc-in]')) return;
    if (rule.nodes.some((d) => d.prop === 'transform' && d.value !== 'none')) {
      assert.match(rule.selector, /\[data-motion="ready"\]/);
    }
  });
});
