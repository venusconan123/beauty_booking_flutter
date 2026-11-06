'use strict';
// Local fault injection: only forwards to the demo Functions Emulator.
// No tokens, user profiles or request bodies are logged.
const http = require('node:http');
let delayed = false;
http.createServer((req, res) => {
  if (!req.url.startsWith('/demo-men-hair-booking/asia-southeast1/')) {
    res.writeHead(404).end(); return;
  }
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    const body = Buffer.concat(chunks);
    let requestId = 'preflight';
    try { requestId = JSON.parse(body).data?.requestId ?? 'read'; } catch {}
    const started = Date.now();
    console.log(JSON.stringify({ stage: 'network.request', method: req.method, path: req.url, requestId }));
    const upstream = http.request({ hostname: '127.0.0.1', port: 5001, path: req.url,
      method: req.method, headers: { ...req.headers, host: '127.0.0.1:5001' } }, (response) => {
      const output = [];
      response.on('data', (chunk) => output.push(chunk));
      response.on('end', () => {
        const shouldDelay = !delayed && req.method === 'POST' && req.url.endsWith('/saveShifts') && response.statusCode === 200;
        if (shouldDelay) delayed = true;
        console.log(JSON.stringify({ stage: 'network.backend_response', requestId, status: response.statusCode,
          elapsedMs: Date.now() - started, delayedMs: shouldDelay ? 50000 : 0 }));
        const send = () => {
          if (!res.destroyed) {
            res.writeHead(response.statusCode, response.headers); res.end(Buffer.concat(output));
            console.log(JSON.stringify({ stage: 'network.client_response', requestId, status: response.statusCode }));
          }
        };
        if (shouldDelay) setTimeout(send, 50000); else send();
      });
    });
    upstream.on('error', (error) => { console.error(error.message); if (!res.destroyed) res.writeHead(502).end(); });
    res.on('close', () => console.log(JSON.stringify({ stage: 'network.client_close', requestId, elapsedMs: Date.now() - started })));
    upstream.end(body);
  });
}).listen(5002, '127.0.0.1', () => console.log('Demo-only response fault proxy: 127.0.0.1:5002 -> 127.0.0.1:5001; first successful save response delayed 50s.'));
