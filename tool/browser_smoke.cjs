const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(path.resolve('.tools/browser/node_modules/playwright-core'));
const root = path.resolve(process.env.RONFLONFLON_WEB_ROOT || 'build/web');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.otf': 'font/otf' };
const server = http.createServer((req, res) => {
  let file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (file.endsWith('/')) file += 'index.html';
  if (!file.startsWith(root)) { res.writeHead(403); res.end(); return; }
  fs.readFile(file, (error, data) => {
    if (error) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
});
(async () => {
  let browser;
  try {
    await new Promise(resolve => server.listen(7357, '127.0.0.1', resolve));
    browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
    const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
    await page.addInitScript(() => {
      const originalPlay = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function (...args) {
        window.testAudio = this;
        return originalPlay.apply(this, args);
      };
    });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:7357');
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 45000 });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await page.getByRole('button', { name: 'Begin met luisteren' }).waitFor({ timeout: 45000 });
    await page.waitForFunction(async () => {
      const cache = await caches.open('ronflonflon-audio-v1');
      return (await cache.keys()).length === 0;
    });
    console.log('Initial list loaded without downloading audio.');
    await page.getByRole('button', { name: 'Begin met luisteren' }).click();
    await page.getByRole('button', { name: 'Pauzeren', exact: true }).waitFor({ timeout: 120000 });
    await page.waitForFunction(() => {
      const raw = JSON.parse(localStorage.getItem('flutter.ronflonflon.progress.v1'));
      const progress = typeof raw === 'string' ? JSON.parse(raw) : raw;
      return progress?.positions?.[progress.currentId] > 1000;
    }, null, { timeout: 30000 }).catch(async error => {
      console.log('Browser state:', await page.locator('body').innerText());
      console.log('Progress storage:', await page.evaluate(() => localStorage.getItem('flutter.ronflonflon.progress.v1')));
      throw error;
    });
    await page.getByRole('button', { name: 'Pauzeren', exact: true }).click();
    const read = () => page.evaluate(() => {
          const stored = JSON.parse(localStorage.getItem('flutter.ronflonflon.progress.v1'));
          return typeof stored === 'string' ? JSON.parse(stored) : stored;
        });
    const saved = await read();
    assert(saved.currentId.includes('001'));
    assert(saved.positions[saved.currentId] > 1000);
    assert.equal(await page.evaluate(async () => (await (await caches.open('ronflonflon-audio-v1')).keys()).length), 1);
    console.log('Real Archive.org MP3 downloaded, played, paused, and persisted:', saved.positions[saved.currentId], 'ms');
    await page.reload();
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 45000 });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await page.getByRole('button', { name: 'Verder luisteren', exact: true }).waitFor({ timeout: 45000 });
    assert.equal((await read()).positions[saved.currentId], saved.positions[saved.currentId]);
    await page.getByRole('button', { name: 'Verder luisteren', exact: true }).click();
    await page.getByRole('button', { name: 'Pauzeren', exact: true }).waitFor({ timeout: 15000 });
    // Advance the real media element to the end instead of waiting 54 minutes.
    await page.evaluate(() => { window.testAudio.currentTime = window.testAudio.duration - 0.2; });
    await page.waitForFunction(async () => (await (await caches.open('ronflonflon-audio-v1')).keys()).length === 0);
    await page.waitForFunction(() => {
      const stored = JSON.parse(localStorage.getItem('flutter.ronflonflon.progress.v1'));
      const state = typeof stored === 'string' ? JSON.parse(stored) : stored;
      return state.completed.includes(state.currentId);
    }, null, { timeout: 15000 }).catch(async error => {
      console.log('Completion state:', await read());
      console.log('Completion UI:', await page.locator('body').innerText());
      throw error;
    });
    assert((await read()).completed.includes(saved.currentId));
    console.log('Resume after reload, natural completion, and automatic audio deletion passed.');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: '.tools/browser/mobile.png' });
    assert.deepEqual(errors, []);
    console.log('Mobile layout rendered; no uncaught browser errors.');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
