import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { IcuTranspiler } from './icu-transpiler';

describe('IcuTranspiler', () => {
  const t = new IcuTranspiler();
  const run = (value: string, params?: Record<string, unknown>) =>
    t.transpile({ value, params, translation: {}, key: 'k' });

  it('fills parameters and keeps apostrophes', () => {
    expect(run("L'Analisi di {name} è pronta.", { name: 'Mario' })).toBe(
      "L'Analisi di Mario è pronta.",
    );
    expect(run('Riprova tra {seconds} secondi.', { seconds: 30 })).toBe('Riprova tra 30 secondi.');
    expect(run('Nessun parametro')).toBe('Nessun parametro');
  });

  it('chooses plural branches, exact matches first', () => {
    const message = '{count, plural, =1{1 persona} other{{count} persone}}';
    expect(run(message, { count: 1 })).toBe('1 persona');
    expect(run(message, { count: 4 })).toBe('4 persone');
    expect(run('{n, plural, =0{none} one{# item} other{# items}}', { n: 0 })).toBe('none');
    t.onLangChanged('en');
    expect(run('{n, plural, one{# item} other{# items}}', { n: 1 })).toBe('1 item');
    expect(run('{n, plural, one{# item} other{# items}}', { n: 1500 })).toBe('1,500 items');
    t.onLangChanged('it');
  });

  it('handles select and nested arguments', () => {
    expect(
      run('{kind, select, card{Carta di {who}} other{Altro}}', { kind: 'card', who: 'Ana' }),
    ).toBe('Carta di Ana');
    expect(run('{kind, select, card{Carta} other{Altro}}', { kind: 'x' })).toBe('Altro');
  });

  it('formats every ARB message without throwing', () => {
    for (const lang of ['it', 'en']) {
      const arb = JSON.parse(
        readFileSync(
          resolve(process.cwd(), `../financial-manager-app/lib/l10n/app_${lang}.arb`),
          'utf8',
        ),
      ) as Record<string, unknown>;
      for (const [key, value] of Object.entries(arb)) {
        if (key.startsWith('@') || typeof value !== 'string') continue;
        const out = run(value, { count: 2, name: 'x', amount: '1 €', date: 'oggi' }) as string;
        expect(out, key).not.toMatch(/\{\s*\w+\s*,\s*(plural|select)/);
      }
    }
  });
});
