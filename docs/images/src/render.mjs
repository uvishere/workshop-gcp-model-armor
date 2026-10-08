// Renders every *.html in this folder to ../<name>.png with headless Chrome.
// No npm dependencies: Node 22+ has global fetch and WebSocket.
//
// Usage:  node docs/images/src/render.mjs [name ...]
//
// The pages load fonts from presentation/fonts/ by relative URL, and Chrome
// will not load fonts across file:// URLs, so the repo root is served over a
// throwaway local HTTP server instead.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SRC = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SRC, '..', '..', '..');
const OUT = path.resolve(SRC, '..');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const DEBUG_PORT = 9341;

const TYPES = { '.html': 'text/html', '.woff2': 'font/woff2', '.css': 'text/css', '.png': 'image/png' };

const server = http.createServer((req, res) => {
  const file = path.join(ROOT, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'render-'));
const chrome = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${DEBUG_PORT}`, `--user-data-dir=${profile}`, 'about:blank'], { stdio: 'ignore' });

async function connect() {
  for (let i = 0; i < 50; i++) {
    try {
      const tab = await (await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/new?about:blank`, { method: 'PUT' })).json();
      return tab.webSocketDebuggerUrl;
    } catch { await new Promise((r) => setTimeout(r, 200)); }
  }
  throw new Error('Chrome did not start');
}

const ws = new WebSocket(await connect());
await new Promise((r) => (ws.onopen = r));
let nextId = 0;
const pending = new Map();
ws.onmessage = (e) => { const m = JSON.parse(e.data); pending.get(m.id)?.(m); pending.delete(m.id); };
const send = (method, params = {}) => new Promise((r) => { const id = ++nextId; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); });
const evaluate = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result.result.value;

const only = process.argv.slice(2);
const pages = fs.readdirSync(SRC).filter((f) => f.endsWith('.html')).map((f) => f.slice(0, -5))
  .filter((n) => only.length === 0 || only.includes(n));

try {
  for (const name of pages) {
    await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 2, mobile: false });
    await send('Page.navigate', { url: `${base}/docs/images/src/${name}.html` });
    await evaluate(`new Promise((r) => { const go = () => document.fonts.ready.then(() => setTimeout(r, 150)); document.readyState === 'complete' ? go() : addEventListener('load', go); })`);
    const box = await evaluate(`(() => { const r = document.querySelector('.frame').getBoundingClientRect(); return { w: Math.ceil(r.width), h: Math.ceil(r.height) }; })()`);
    await send('Emulation.setDeviceMetricsOverride', { width: box.w, height: box.h, deviceScaleFactor: 2, mobile: false });
    const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: box.w, height: box.h, scale: 1 } });
    const file = path.join(OUT, `${name}.png`);
    fs.writeFileSync(file, Buffer.from(shot.result.data, 'base64'));
    console.log(`${name}.png  ${box.w * 2}x${box.h * 2}  ${Math.round(fs.statSync(file).size / 1024)} KB`);
  }
} finally {
  ws.close();
  chrome.kill();
  server.close();
}
