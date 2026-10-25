// Builds the dashboard's translation files from the app's ARB files, so the
// Flutter app and the web dashboard share one set of strings:
//
//   ../financial-manager-app/lib/l10n/app_<lang>.arb   (shared strings)
// + src/i18n/web.<lang>.json                           (web-only strings)
// = public/i18n/<lang>.json                            (served, gitignored)
//
// ARB messages are already ICU MessageFormat ({name}, plurals, select), which
// the dashboard's transpiler reads (src/app/core/i18n/icu-transpiler.ts), so
// they are copied unchanged;
// only the "@key"/"@@locale" metadata is dropped. Fails when a language
// misses a key of the template (it) or a placeholder differs, and when a
// web key shadows an ARB key.
//
// Usage: node scripts/arb-to-json.mjs [--arb-dir <dir>] [--watch]
//
// --watch rebuilds whenever an ARB or web file changes (npm start uses it
// through scripts/dev.mjs); an inconsistency is then reported, not fatal.

import { mkdirSync, readFileSync, watch, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const LANGUAGES = ['it', 'en'];
const TEMPLATE = 'it';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** Strips ARB metadata: keys starting with "@". */
export function arbMessages(arb) {
  return Object.fromEntries(Object.entries(arb).filter(([key]) => !key.startsWith('@')));
}

/**
 * Placeholder names of an ICU message: "{name}" and "{count, plural, ...}",
 * also nested in plural branches ("other{{count} items}"). Branch texts
 * ("=1{One item}") don't match: a word must be followed by "," or "}".
 */
export function placeholders(message) {
  const names = new Set();
  for (const match of message.matchAll(/\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*[,}]/g)) {
    names.add(match[1]);
  }
  return [...names].sort();
}

/** Merges and checks the messages of every language; returns {lang: messages}. */
export function buildTranslations(arbByLang, webByLang) {
  const errors = [];
  const template = arbByLang[TEMPLATE];
  const result = {};
  for (const lang of Object.keys(arbByLang)) {
    const arb = arbByLang[lang];
    for (const key of Object.keys(template)) {
      if (!(key in arb)) {
        errors.push(`${lang}: missing ARB key "${key}"`);
      } else if (placeholders(arb[key]).join() !== placeholders(template[key]).join()) {
        errors.push(`${lang}: placeholders of "${key}" differ from ${TEMPLATE}`);
      }
    }
    const web = webByLang[lang] ?? {};
    for (const key of Object.keys(web)) {
      if (key in arb) errors.push(`${lang}: web key "${key}" shadows an ARB key`);
    }
    for (const key of Object.keys(webByLang[TEMPLATE] ?? {})) {
      if (!(key in web)) errors.push(`${lang}: missing web key "${key}"`);
    }
    result[lang] = { ...arb, ...web };
  }
  if (errors.length > 0) {
    throw new Error(`Translations are inconsistent:\n  ${errors.join('\n  ')}`);
  }
  return result;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function arbDirectory() {
  const flag = process.argv.indexOf('--arb-dir');
  return flag > 0
    ? resolve(process.argv[flag + 1])
    : join(root, '..', 'financial-manager-app', 'lib', 'l10n');
}

function build(arbDir) {
  const arbByLang = {};
  const webByLang = {};
  for (const lang of LANGUAGES) {
    arbByLang[lang] = arbMessages(readJson(join(arbDir, `app_${lang}.arb`)));
    webByLang[lang] = readJson(join(root, 'src', 'i18n', `web.${lang}.json`));
  }
  const translations = buildTranslations(arbByLang, webByLang);
  const outDir = join(root, 'public', 'i18n');
  mkdirSync(outDir, { recursive: true });
  for (const [lang, messages] of Object.entries(translations)) {
    writeFileSync(join(outDir, `${lang}.json`), JSON.stringify(messages));
  }
  console.log(`i18n: wrote ${LANGUAGES.map((l) => `${l}.json`).join(', ')} to public/i18n`);
}

function main() {
  const arbDir = arbDirectory();
  if (!process.argv.includes('--watch')) {
    build(arbDir);
    return;
  }
  const rebuild = () => {
    try {
      build(arbDir);
    } catch (error) {
      console.error(`i18n: ${error.message}`);
    }
  };
  rebuild();
  let timer;
  const schedule = () => {
    clearTimeout(timer);
    timer = setTimeout(rebuild, 150);
  };
  watch(arbDir, schedule);
  watch(join(root, 'src', 'i18n'), schedule);
  console.log('i18n: watching the ARB and web string files');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
