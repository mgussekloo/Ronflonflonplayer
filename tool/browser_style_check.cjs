const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(path.resolve('.tools/browser/node_modules/playwright-core'));

(async () => {
  const browser = await chromium.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1100, height: 1000 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (/overflowed|EXCEPTION CAUGHT/.test(message.text())) errors.push(message.text());
    });
    await page.goto('https://ronflonflonplayer.test');
    assert.equal(await page.evaluate(() => window.isSecureContext), true);
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 45000 });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await page.getByRole('button', { name: 'Start listening' }).waitFor({ timeout: 45000 });
    await page.getByText('328 available · 0 finished', { exact: true }).waitFor();
    await page.screenshot({ path: '.tools/browser/poster-desktop.png' });
    const search = page.getByRole('textbox');
    await search.fill('no-such-episode');
    await page.getByText('No episodes match this view.', { exact: true }).waitFor();
    await search.fill('');
    await page.getByRole('button', { name: 'About this player' }).click();
    await page.getByText('A little radio time machine', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Got it', exact: true }).click();
    await page.getByText('Hide finished', { exact: true }).click();
    await page.mouse.move(0, 0);
    await page.waitForTimeout(1800);
    for (const width of [390, 320]) {
      await page.setViewportSize({ width, height: 844 });
      await page.waitForTimeout(500);
      await page.screenshot({ path: `.tools/browser/poster-mobile-${width}.png` });
      assert.equal(await page.getByRole('button', { name: 'Start listening' }).isVisible(), true);
    }
    assert.equal(await page.evaluate(async () => (await (await caches.open('ronflonflon-audio-v1')).keys()).length), 0);
    assert.deepEqual(errors, []);
    console.log('Herd HTTPS: 328 episodes; search, filter, about, desktop/mobile layouts passed. No audio downloaded or browser errors.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
