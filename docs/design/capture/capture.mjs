// Screenshots of every screen, sheet and dialog of the web build, with the
// demo data from app/tool/screenshots/shoot.mjs, for design reviews
// (docs/design/REDESIGN_PROMPT.md). Steps tap widgets by their accessible
// label, so scenes survive layout changes. Usage (from the repo root, with
// the web build served on 127.0.0.1:8765 as in shoot.mjs's header, and
// `npm install` done once in app/tool/screenshots):
//
//   node docs/design/capture/capture.mjs ./scenes.mjs out/            # all scenes
//   node docs/design/capture/capture.mjs ./scenes.mjs out/ focus      # names containing "focus"
//   SHARD=0/4 node docs/design/capture/capture.mjs ./scenes.mjs out/  # 1 of 4 parallel runs
//   python3 docs/design/capture/sheets.py out/ sheets/                # contact sheets per section
//
// Cloud sessions: the pinned Playwright doesn't match the preinstalled
// Chromium, so set CHROMIUM_PATH=/opt/pw-browsers/chromium.
import { createRequire } from 'node:module';
import { mkdirSync, readFileSync } from 'node:fs';

const shootUrl = new URL('../../../app/tool/screenshots/shoot.mjs', import.meta.url);
const { chromium } = createRequire(new URL('../../../app/tool/screenshots/package.json', import.meta.url))('playwright');
const base = process.env.APP_URL ?? 'http://127.0.0.1:8765';

// Reuse shoot.mjs's demo data (everything from `const now` up to its
// settings line) instead of keeping a second copy.
const shoot = readFileSync(shootUrl, 'utf8');
const dataSrc = shoot.slice(shoot.indexOf('const now = Date.now()'), shoot.indexOf('const settings = '));
const { tasks, progress, replicas } = new Function(`${dataSrc}; return { tasks, progress, replicas };`)();
const [scenesFile, outDir, only] = process.argv.slice(2);
const [shard, of] = (process.env.SHARD ?? '0/1').split('/').map(Number);
const scenes = (await import(scenesFile)).default.filter((s, i) => (!only || s.name.includes(only)) && i % of === shard);
const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: proxy ? [`--proxy-server=${proxy}`] : [] });
mkdirSync(outDir, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
for (const sc of scenes) {
  const [w, h] = sc.size ?? [390, 844];
  const settings = { appearance: sc.appearance ?? 'light', celebration: 'normal', quoteSeconds: 60, phiGuard: true, ...(sc.settings ?? {}) };
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: sc.scale ?? 2, locale: 'en-US',
    isMobile: w < 600, hasTouch: w < 600, colorScheme: 'dark' });
  await ctx.addInitScript(([t, p, s, r, empty, board, extra]) => {
    if (!empty) {
      localStorage.setItem('flutter.tasks.v1', JSON.stringify(t));
      localStorage.setItem('flutter.progress.v1', JSON.stringify(p));
      for (const [ws, json] of Object.entries(r)) localStorage.setItem(`flutter.replica.v1.${ws}`, JSON.stringify(json));
    }
    if (board) localStorage.setItem('flutter.tasks.view', JSON.stringify('board'));
    localStorage.setItem('flutter.settings.v1', JSON.stringify(s));
    for (const [k, v] of Object.entries(extra)) localStorage.setItem(k, v);
  }, [JSON.stringify(tasks), JSON.stringify(progress), JSON.stringify(settings), replicas, !!sc.empty, !!sc.board, sc.storage ?? {}]);
  const page = await ctx.newPage();
  if (w < 600 && sc.iphone !== false) {
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('Emulation.setSafeAreaInsetsOverride', { insets: { top: 0, bottom: 34, left: 0, right: 0 } });
  }
  try {
    if (sc.clock) await page.clock.install();
    await page.goto(`${base}/#${sc.path ?? '/'}`);
    await page.waitForTimeout(6000);
    // Turn on Flutter's semantics tree so steps can find widgets by label.
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
    for (const st of sc.steps ?? []) {
      if (st.tap) {
        const loc = !st.text ? page.getByRole(st.role ?? 'button', { name: st.tap, exact: !!st.exact })
                            : page.getByText(st.tap, { exact: !!st.exact });
        await loc.nth(st.nth ?? 0).click({ timeout: 5000 });
      }
      if (st.label) await page.locator(`[aria-label*="${st.label}"]`).nth(st.nth ?? 0).click({ timeout: 5000 });
      if (st.xy) await page.mouse.click(st.xy[0], st.xy[1]);
      if (st.type) await page.keyboard.type(st.type, { delay: 20 });
      if (st.hash) await page.evaluate((h) => { location.hash = h; }, st.hash);
      if (st.ff) await page.clock.fastForward(st.ff);
      if (st.key) await page.keyboard.press(st.key);
      if (st.scroll) { await page.mouse.move(w / 2, h / 2); await page.mouse.wheel(0, st.scroll); }
      if (st.dump) {
        const labels = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) =>
          `${e.getAttribute('role') ?? ''}|${e.getAttribute('aria-label') ?? ''}|${(e.childElementCount ? '' : e.textContent)}`).filter((x) => x !== '||'));
        console.log(sc.name, JSON.stringify(labels));
      }
      await page.waitForTimeout(st.wait ?? 1200);
    }
    await page.screenshot({ path: `${outDir}/${sc.name}.png` });
    console.log('ok', sc.name);
  } catch (e) {
    console.log('FAIL', sc.name, e.message.split('\n')[0]);
  }
  await ctx.close();
}
await browser.close();
