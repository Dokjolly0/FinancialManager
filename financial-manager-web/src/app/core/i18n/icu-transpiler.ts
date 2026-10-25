import { Injectable } from '@angular/core';
import { TranslocoTranspiler, TranspileParams } from '@jsverse/transloco';

/**
 * ICU MessageFormat for Transloco without `eval`: @messageformat/core
 * compiles messages with `new Function`, which the dashboard's CSP
 * (script-src 'self', no 'unsafe-eval') blocks. The app's ARB files use a
 * small subset, implemented here:
 *
 *   {name}                                   a parameter
 *   {count, plural, =1{one item} other{# items}}   plural; # is the number
 *   {kind, select, card{…} other{…}}         select
 *
 * Apostrophes are plain text, as in the ARB files (Flutter's gen-l10n with
 * use-escaping off). Parsed messages are cached.
 */

type Node =
  | string
  | { arg: string }
  | { arg: string; type: 'plural' | 'select'; cases: Record<string, Node[]> }
  | { pound: true };

/** Parses an ICU message into nodes; `inPlural` makes "#" special. */
export function parseIcu(message: string): Node[] {
  let pos = 0;

  function nodes(inPlural: boolean, untilBrace: boolean): Node[] {
    const out: Node[] = [];
    let text = '';
    const flush = () => {
      if (text) out.push(text);
      text = '';
    };
    while (pos < message.length) {
      const ch = message[pos];
      if (ch === '}' && untilBrace) break;
      if (ch === '{') {
        flush();
        out.push(argument());
      } else if (ch === '#' && inPlural) {
        flush();
        out.push({ pound: true });
        pos++;
      } else {
        text += ch;
        pos++;
      }
    }
    flush();
    return out;
  }

  function argument(): Node {
    pos++; // {
    const close = message.indexOf('}', pos);
    const comma = message.indexOf(',', pos);
    if (comma === -1 || (close !== -1 && close < comma)) {
      const name = message.slice(pos, close).trim();
      pos = close + 1;
      return { arg: name };
    }
    const name = message.slice(pos, comma).trim();
    pos = comma + 1;
    const typeEnd = message.indexOf(',', pos);
    const type = message.slice(pos, typeEnd).trim();
    pos = typeEnd + 1;
    const cases: Record<string, Node[]> = {};
    for (;;) {
      while (/\s/.test(message[pos] ?? '')) pos++;
      if (message[pos] === '}' || pos >= message.length) {
        pos++;
        break;
      }
      const open = message.indexOf('{', pos);
      const selector = message.slice(pos, open).trim();
      pos = open + 1;
      cases[selector] = nodes(type === 'plural', true);
      pos++; // }
    }
    return { arg: name, type: type === 'plural' ? 'plural' : 'select', cases };
  }

  return nodes(false, false);
}

export function formatIcu(
  parsed: Node[],
  params: Record<string, unknown>,
  plural: Intl.PluralRules,
  number: Intl.NumberFormat,
  pound?: number,
): string {
  let out = '';
  for (const node of parsed) {
    if (typeof node === 'string') {
      out += node;
    } else if ('pound' in node) {
      out += pound === undefined ? '#' : number.format(pound);
    } else if (!('type' in node)) {
      const value = params[node.arg];
      out += value === undefined || value === null ? '' : String(value);
    } else if (node.type === 'plural') {
      const n = Number(params[node.arg] ?? 0);
      const branch =
        node.cases[`=${n}`] ?? node.cases[plural.select(n)] ?? node.cases['other'] ?? [];
      out += formatIcu(branch, params, plural, number, n);
    } else {
      const branch = node.cases[String(params[node.arg])] ?? node.cases['other'] ?? [];
      out += formatIcu(branch, params, plural, number, pound);
    }
  }
  return out;
}

@Injectable()
export class IcuTranspiler implements TranslocoTranspiler {
  private readonly cache = new Map<string, Node[]>();
  private plural = new Intl.PluralRules('it');
  private number = new Intl.NumberFormat('it');

  onLangChanged(lang: string): void {
    this.plural = new Intl.PluralRules(lang);
    this.number = new Intl.NumberFormat(lang);
  }

  transpile({ value, params = {} }: TranspileParams): unknown {
    if (typeof value !== 'string' || !value.includes('{')) return value;
    let parsed = this.cache.get(value);
    if (!parsed) {
      parsed = parseIcu(value);
      this.cache.set(value, parsed);
    }
    return formatIcu(parsed, params, this.plural, this.number);
  }
}
