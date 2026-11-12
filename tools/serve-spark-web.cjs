'use strict';
// Optional local UI review. The app still calls the online backend/Firebase.
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web-spark');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
http.createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
    const bytes = await fs.readFile(file);
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }).end(bytes);
  } catch { response.writeHead(404).end('Not found'); }
}).listen(7358, '127.0.0.1', () => console.log('Firebase thật + backend Cloudflare: http://localhost:7358/'));
