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
    page.setDefaultTimeout(15000);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (/overflowed|EXCEPTION CAUGHT/.test(message.text())) errors.push(message.text());
    });
    await page.goto('https://ronflonflonplayer.test');
    console.log('Herd page loaded.');
    assert.equal(await page.evaluate(() => window.isSecureContext), true);
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 45000 });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await page.getByRole('button', { name: 'Begin met luisteren' }).waitFor({ timeout: 45000 });
    await page.getByText('328 beschikbaar · 0 beluisterd', { exact: true }).waitFor();
    console.log('Dutch episode list loaded.');
    assert.equal(await page.locator('html').getAttribute('lang'), 'nl');
    await page.getByText('De radio, de radio, wat is er op de radio?', { exact: true }).waitFor();
    await page.getByText('Alle uitzendingen van gisteren! Maar dan vandaag.', { exact: true }).waitFor();
    await page.screenshot({ path: '.tools/browser/poster-desktop.png' });
    const search = page.getByRole('textbox');
    await search.click();
    await search.pressSequentially('no-such-episode', { delay: 40 });
    await page.getByText('Geen uitzendingen gevonden.', { exact: true }).waitFor().catch(async error => {
      console.log('Search value:', await search.inputValue());
      console.log('Search UI:', await page.locator('body').innerText());
      throw error;
    });
    await search.fill('');
    await page.getByRole('button', { name: 'Over deze speler' }).click();
    await page.getByText('Deze onafhankelijke speler gebruikt de Ronflonflon-collectie op Archive.org.', { exact: false }).waitFor();
    await page.getByRole('button', { name: 'Begrepen', exact: true }).click();
    await page.getByText('Verberg beluisterde uitzendingen', { exact: true }).click();
    await page.mouse.move(0, 0);
    await page.waitForTimeout(1800);
    for (const width of [390, 320]) {
      await page.setViewportSize({ width, height: 844 });
      await page.waitForTimeout(500);
      await page.screenshot({ path: `.tools/browser/poster-mobile-${width}.png` });
      assert.equal(await page.getByRole('button', { name: 'Begin met luisteren' }).isVisible(), true);
    }
    assert.equal(await page.evaluate(async () => (await (await caches.open('ronflonflon-audio-v1')).keys()).length), 0);
    assert.deepEqual(errors, []);
    console.log('Herd HTTPS: 328 episodes; search, filter, about, desktop/mobile layouts passed. No audio downloaded or browser errors.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
