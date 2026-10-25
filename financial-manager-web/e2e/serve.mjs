// Static server for the e2e tests: the production build with the SPA
// fallback (like docker/Caddyfile.web) and the production CSP, so a
// violation fails the tests. The API is mocked in the browser.
// Usage: node e2e/serve.mjs <dist/browser dir> <port>
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(process.argv[2]);
const port = Number(process.argv[3] ?? 4300);
const caddy = join(
  dirname(fileURLToPath(import.meta.url)),
  '../../financial-manager-backend/deploy/Caddyfile.example',
);
const csp = existsSync(caddy)
  ? /Content-Security-Policy "([^"]+)"/.exec(readFileSync(caddy, 'utf8'))?.[1]
  : undefined;
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.woff2': 'font/woff2',
  '.svg': 'image/svg+xml',
};

createServer((req, res) => {
  const path = normalize(join(root, decodeURIComponent(req.url.split('?')[0])));
  const isFile = path.startsWith(root) && existsSync(path) && statSync(path).isFile();
  const file = isFile ? path : join(root, 'index.html');
  res.writeHead(200, {
    'Content-Type': types[extname(file)] ?? 'application/octet-stream',
    ...(csp ? { 'Content-Security-Policy': csp } : {}),
  });
  createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1');
