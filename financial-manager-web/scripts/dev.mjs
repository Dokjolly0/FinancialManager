// npm start: the translation files rebuilt on every ARB or web string change
// (arb-to-json.mjs --watch) next to `ng serve` (port 5000, API proxy).
// Arguments after `npm start --` go to ng serve.

import { spawn } from 'node:child_process';

const children = [
  spawn(process.execPath, ['scripts/arb-to-json.mjs', '--watch'], { stdio: 'inherit' }),
  // One command string: npx needs a shell on Windows.
  spawn(['npx ng serve', ...process.argv.slice(2)].join(' '), { stdio: 'inherit', shell: true }),
];

const stop = (code) => {
  for (const child of children) child.kill();
  process.exit(code ?? 0);
};
for (const child of children) child.on('exit', (code) => stop(code));
process.on('SIGINT', () => stop(0));
process.on('SIGTERM', () => stop(0));
