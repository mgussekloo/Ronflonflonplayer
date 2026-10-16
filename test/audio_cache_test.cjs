const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('web/audio_cache.js', 'utf8');
function setup() {
  const entries = new Map();
  const revoked = [];
  let downloads = 0;
  let failDownload = false;
  let failWrite = false;
  const cache = {
    async match(url) { return entries.get(url)?.clone(); },
    async put(url, response) {
      if (failWrite) throw new Error('Quota exceeded');
      entries.set(url, response);
    },
    async delete(url) { return entries.delete(url); },
  };
  const context = {
    window: { isSecureContext: true, caches: true },
    caches: { async open() { return cache; } },
    URL: { createObjectURL() { return `blob:episode-${downloads}`; }, revokeObjectURL(url) { revoked.push(url); } },
    Blob, Response, AbortController, setTimeout, clearTimeout,
    async fetch(url, options) {
      downloads++;
      assert.equal(options.cache, 'no-store');
      if (failDownload) return new Response('Unavailable', { status: 503 });
      return new Response(new Uint8Array([1, 2, 3, 4]), { headers: { 'content-length': '4' } });
    },
  };
  vm.runInNewContext(source, context);
  return { api: context.window.ronflonflonCache, context, entries, revoked,
    downloads: () => downloads, failDownload: (value) => { failDownload = value; },
    failWrite: (value) => { failWrite = value; } };
}

test('downloads only on selection and reuses the cached copy', async () => {
  const state = setup();
  assert.equal(state.downloads(), 0);
  const progress = [];
  await state.api.prepare('https://example.com/1.mp3', value => progress.push(value));
  assert.equal(state.downloads(), 1);
  assert.equal(state.entries.size, 1);
  assert.equal(progress.at(-1), 1);
  await state.api.prepare('https://example.com/1.mp3', () => {});
  assert.equal(state.downloads(), 1);
  assert.equal(state.revoked.length, 1);
});

test('completion deletes only the selected audio; replay downloads it again', async () => {
  const state = setup();
  await state.api.prepare('first', () => {});
  await state.api.prepare('second', () => {});
  state.api.release();
  await state.api.remove('first');
  assert.equal(state.entries.has('first'), false);
  assert.equal(state.entries.has('second'), true);
  await state.api.prepare('first', () => {});
  assert.equal(state.downloads(), 3);
});

test('failed downloads are not cached and can be retried', async () => {
  const state = setup();
  state.failDownload(true);
  await assert.rejects(state.api.prepare('first', () => {}), /503/);
  assert.equal(state.entries.size, 0);
  state.failDownload(false);
  await state.api.prepare('first', () => {});
  assert.equal(state.entries.size, 1);
});

test('quota failures are visible and do not claim offline availability', async () => {
  const state = setup();
  state.failWrite(true);
  await assert.rejects(state.api.prepare('first', () => {}), /Quota/);
  assert.equal(state.entries.size, 0);
});

test('insecure origins fail with actionable guidance', async () => {
  const state = setup();
  state.context.window.isSecureContext = false;
  await assert.rejects(state.api.prepare('first', () => {}), /HTTPS or localhost/);
  assert.equal(state.downloads(), 0);
});
