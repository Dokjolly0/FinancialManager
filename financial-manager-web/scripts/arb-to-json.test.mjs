// npm run test:scripts
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { arbMessages, buildTranslations, placeholders } from './arb-to-json.mjs';

test('drops ARB metadata', () => {
  const arb = { '@@locale': 'it', hello: 'Ciao {name}', '@hello': { placeholders: {} } };
  assert.deepEqual(arbMessages(arb), { hello: 'Ciao {name}' });
});

test('finds placeholders, also inside plural branches', () => {
  assert.deepEqual(placeholders('Riprova tra {seconds} secondi.'), ['seconds']);
  assert.deepEqual(
    placeholders('{count, plural, =1{1 persona} other{{count} persone di {city}}}'),
    ['city', 'count'],
  );
  assert.deepEqual(placeholders("L'Analisi AI non è attiva."), []);
});

test('merges web strings over the ARB messages', () => {
  const out = buildTranslations(
    { it: { a: 'A {x}' }, en: { a: 'A {x}' } },
    { it: { webB: 'B' }, en: { webB: 'B en' } },
  );
  assert.deepEqual(out.en, { a: 'A {x}', webB: 'B en' });
});

test('rejects missing keys, different placeholders and shadowed keys', () => {
  assert.throws(
    () => buildTranslations({ it: { a: 'A', b: 'B' }, en: { a: 'A' } }, { it: {}, en: {} }),
    /en: missing ARB key "b"/,
  );
  assert.throws(
    () => buildTranslations({ it: { a: '{x}' }, en: { a: '{y}' } }, { it: {}, en: {} }),
    /placeholders of "a"/,
  );
  assert.throws(
    () => buildTranslations({ it: { a: 'A' }, en: { a: 'A' } }, { it: { a: 'X' }, en: { a: 'X' } }),
    /shadows an ARB key/,
  );
  assert.throws(
    () => buildTranslations({ it: { a: 'A' }, en: { a: 'A' } }, { it: { w: 'W' }, en: {} }),
    /en: missing web key "w"/,
  );
});
