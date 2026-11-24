// Measures the first load of the web app like a phone on slow 4G.
//
//   node tool/measure_web.mjs <url> [label]
//
// Opens a fresh Chrome (new profile, so an empty cache) through the
// DevTools protocol, with
// Chrome's "Slow 4G" preset (562.5 ms round trip, 1.44 Mbps down,
// 675 kbps up), an iPhone screen, and it reports itself as Safari (user
// agent, vendor, no Chrome-only hints), so Flutter fetches what an iPhone
// fetches. Reports:
//  - first paint: when anything is first drawn (the loading screen);
//  - Flutter's first frame: when the app itself is on screen;
//  - bytes downloaded (compressed, as sent) up to the first frame, and the
//    biggest files.
// Uses Chrome as installed; nothing extra to install (Node 22+).

import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2];
const label = process.argv[3] ?? '';
if (!url) {
  console.error('Usage: node tool/measure_web.mjs <url> [label]');
  process.exit(1);
}

const chromePaths = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
];
const chrome = chromePaths.find((p) => existsSync(p));
if (!chrome) throw new Error('Chrome not found');

const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), 'looma-measure-'));
const proc = spawn(chrome, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--no-first-run',
  '--no-default-browser-check',
  'about:blank',
]);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function json(path, method = 'GET') {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}${path}`, { method });
      return await res.json();
    } catch {
      await sleep(200);
    }
  }
  throw new Error('Chrome did not start');
}

const target = await json('/json/new?about:blank', 'PUT');
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));

let id = 0;
const pending = new Map();
const listeners = [];
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else if (msg.method) {
    for (const l of listeners) l(msg);
  }
});
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const n = ++id;
    pending.set(n, resolve);
    ws.send(JSON.stringify({ id: n, method, params }));
  });

// Every response's size as sent over the network (compressed).
const sizes = new Map();
const urls = new Map();
let firstFrameAt = null;
listeners.push((msg) => {
  if (msg.method === 'Network.responseReceived') {
    urls.set(msg.params.requestId, msg.params.response.url);
  }
  // Bytes as they arrive (works for every kind of file).
  if (msg.method === 'Network.dataReceived' && firstFrameAt === null) {
    const r = msg.params.requestId;
    sizes.set(r, (sizes.get(r) ?? 0) + msg.params.encodedDataLength);
  }
  if (msg.method === 'Network.loadingFinished' && firstFrameAt === null) {
    const r = msg.params.requestId;
    sizes.set(r, Math.max(sizes.get(r) ?? 0, msg.params.encodedDataLength));
  }
});

await send('Network.enable');
// Count every download as the page makes it (a first visit has no
// service worker in charge yet).
await send('Network.setBypassServiceWorker', { bypass: true });
await send('Page.enable');
await send('Network.emulateNetworkConditions', {
  offline: false,
  latency: 562.5,
  downloadThroughput: (1.44 * 1024 * 1024) / 8,
  uploadThroughput: (675 * 1024) / 8,
});
await send('Emulation.setUserAgentOverride', {
  userAgent:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) ' +
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 ' +
    'Safari/604.1',
  platform: 'iPhone',
});
await send('Emulation.setDeviceMetricsOverride', {
  width: 390,
  height: 844,
  deviceScaleFactor: 3,
  mobile: true,
});
await send('Page.addScriptToEvaluateOnNewDocument', {
  source: `
    // Look like Safari: Flutter picks its engine files by browser.
    Object.defineProperty(Navigator.prototype, 'userAgentData', { get: () => undefined });
    Object.defineProperty(Navigator.prototype, 'vendor', { get: () => 'Apple Computer, Inc.' });
    window.addEventListener('flutter-first-frame', () => {
    window.__firstFrame = performance.now();
  });`,
});

const started = Date.now();
await send('Page.navigate', { url });

let result = null;
while (Date.now() - started < 240000) {
  await sleep(250);
  const r = await send('Runtime.evaluate', {
    expression: `JSON.stringify({
      firstFrame: window.__firstFrame ?? null,
      paint: (performance.getEntriesByType('paint')
        .find((p) => p.name === 'first-contentful-paint')
        ?? performance.getEntriesByType('paint')[0] ?? {}).startTime ?? null,
    })`,
    returnByValue: true,
  });
  const v = JSON.parse(r.result?.result?.value ?? '{}');
  if (v.firstFrame) {
    firstFrameAt = Date.now();
    result = v;
    break;
  }
}
await sleep(300);

const total = [...sizes.values()].reduce((a, b) => a + b, 0);
const top = [...sizes.entries()]
  .map(([req, bytes]) => [urls.get(req) ?? req, bytes])
  .sort((a, b) => b[1] - a[1])
  .slice(0, 12);

const kb = (b) => `${(b / 1024).toFixed(0)} KB`;
console.log(`\n== ${label || url} ==`);
console.log('Network: Slow 4G (562.5 ms RTT, 1.44 Mbps down), as iPhone Safari, empty cache');
console.log(
  `First paint (anything on screen): ${result?.paint ? (result.paint / 1000).toFixed(1) + ' s' : 'n/a'}`,
);
console.log(
  `Flutter first frame (app on screen): ${result?.firstFrame ? (result.firstFrame / 1000).toFixed(1) + ' s' : 'not reached in 240 s'}`,
);
console.log(`Downloaded until first frame: ${kb(total)} in ${sizes.size} files`);
for (const [u, b] of top) {
  console.log(`  ${kb(b).padStart(8)}  ${u.replace(/^https?:\/\/[^/]+/, '')}`);
}

ws.close();
proc.kill();
await sleep(500);
try {
  rmSync(profile, { recursive: true, force: true });
} catch {}
process.exit(0);
