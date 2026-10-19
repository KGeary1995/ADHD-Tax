// Screenshots of the web build, with demo tasks loaded, for checking UI
// changes without a phone. Usage (from app/):
//
//   flutter build web --release --no-web-resources-cdn
//   (cd build/web && python3 -m http.server 8765 --bind 127.0.0.1) &
//   (cd tool/screenshots && npm install)      # once
//   node tool/screenshots/shoot.mjs out/ dashboard / 390 844
//   node tool/screenshots/shoot.mjs out/ tasks /tasks 360 780 --appearance light
//   node tool/screenshots/shoot.mjs out/ add / 390 844 --tap 356,790   # Add button
//
// Args: <outDir> <name> [path=/] [width=390] [height=844]
//       [--appearance light|dark|system]  (default dark; system follows
//                    the emulated phone, which is set to dark)
//       [--tap x,y]  (tap a point after loading, e.g. to open a sheet)
//       [--iphone]   (fakes a 34px home-indicator inset, like an iPhone)
//       [--empty]    (no demo data)
//       [--board]    (Tasks opens as a board)
// Writes <outDir>/<name>.png. Paths are app routes: / /tasks /progress
// /settings /task/<id> (demo ids are '1'..'7').
//
// Needs Chromium: Playwright's own (npx playwright install chromium) or the
// one at PLAYWRIGHT_BROWSERS_PATH. Behind an HTTPS proxy (cloud sessions)
// it's passed to Chromium automatically.
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const args = process.argv.slice(2);
const flag = (f) => args.includes(f);
const opt = (f, d) => (args.includes(f) ? args[args.indexOf(f) + 1] : d);
const valued = ['--appearance', '--tap'];
const pos = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && valued.includes(args[i - 1])));
const [outDir, name, path = '/', width = '390', height = '844'] = pos;
if (!outDir || !name) {
  console.error('Usage: node shoot.mjs <outDir> <name> [path] [width] [height] [--appearance a] [--tap x,y] [--iphone] [--empty]');
  process.exit(2);
}
const base = process.env.APP_URL ?? 'http://127.0.0.1:8765';

// Demo data in the pre-sync storage format. The app migrates these keys
// into its sync replicas on first launch (ReplicasController), so they stay
// a convenient way to seed a fresh browser profile.
const now = Date.now(), day = 864e5;
const iso = (ms) => new Date(ms).toISOString();
const T = (id, title, o = {}) => ({
  id, title, notes: '', firstStep: '', estimateMin: 15, requiresLeavingHouse: false,
  location: '', priority: 'p3', dueAt: null, hardDeadline: false, ugh: 0, energy: 'medium',
  workspace: 'personal', status: 'todo', chunkable: false, scheduledStart: null,
  createdAt: iso(now - day), updatedAt: iso(now - day), startedAt: null, completedAt: null,
  actualMin: null, skipCount: 0, lastSkippedAt: null, repeat: 'none', repeatFromDone: false, ...o,
});
const tasks = [
  T('1', 'Draft front-desk triage cheat sheet', { workspace: 'work', projectId: 'pw1', estimateMin: 60, priority: 'p1', chunkable: true,
    dueAt: iso(now + 0.8 * day), hardDeadline: true, firstStep: "Open last year's version and skim it", energy: 'high' }),
  T('2', 'Reply to Dr. Patel about Thursday template', { workspace: 'work', priority: 'p2', firstStep: 'Open the template doc' }),
  T('3', 'Schedule dentist appointment', { estimateMin: 5, ugh: 2, firstStep: 'Find the number in contacts', createdAt: iso(now - 9 * day) }),
  T('4', 'Renew car registration', { projectId: 'pp1', requiresLeavingHouse: true, location: 'DMV', estimateMin: 30, priority: 'p2', ugh: 2, dueAt: iso(now + 3 * day) }),
  T('5', 'Laundry', { estimateMin: 30, energy: 'low', repeat: 'weekly' }),
  T('6', 'Pick up prescription', { requiresLeavingHouse: true, location: 'Pharmacy' }),
  T('7', 'Weekly huddle notes', { workspace: 'work', repeat: 'weekly', dueAt: iso(now + 6 * day), scheduledStart: iso(now + 4 * day) }),
  T('8', 'Prior auth for Thursday clinic', { workspace: 'work', status: 'waiting', waitingOn: 'Insurance callback', followUpAt: iso(now - 36e5) }),
  T('9', 'Order new label printer', { workspace: 'work', status: 'waiting', waitingOn: 'IT ticket', followUpAt: iso(now + 3 * day) }),
  // Finished with the timer, so "How long things really take" has data.
  ...[20, 25, 30, 18, 40, 22].map((a, i) => T(`d${i}`, `Timed task ${i + 1}`, {
    status: 'done', estimateMin: 15, actualMin: a, completedAt: iso(now - (i + 1) * day), createdAt: iso(now - (i + 2) * day) })),
];
const progress = {
  xp: 640, coins: 61, started: 25, completed: 19, ughCompleted: 4, accurateEstimates: 6, oldTasksCleared: 2,
  focusMinutes: 512, justFiveKeptGoing: 3, panicStarts: 1, errandsByDay: {}, completionsByDay: {},
  recent: [], activeDays: [0, 1, 2, 3, 5, 6].map((i) => iso(new Date(new Date(now - i * day).toDateString()).getTime())),
  unlocked: {}, lastActiveAt: iso(now - 36e5),
};
// Notes and projects only exist in the replica format: seed those directly.
const clock = `${now.toString(36).padStart(10, '0')}-0000-demo`;
const rec = (f) => ({ f: { ...f, deleted: false }, t: clock });
const N = (id, ws, title, body, o = {}) => [id, rec({
  workspace: ws, title, body, pinned: false, projectId: '', taskId: '', tags: '',
  createdAt: iso(now - 2 * day), updatedAt: iso(now - (o.ago ?? 0.1) * day), ...o, ago: undefined,
})];
const replica = (c) => JSON.stringify({ v: 1, node: 'demo', clock, local: null, c });
const replicas = {
  work: replica({
    projects: { pw1: rec({ name: 'Front desk training', workspace: 'work', color: 0, createdAt: iso(now - 9 * day) }),
      pw2: rec({ name: 'Phones & scheduling', workspace: 'work', color: 2, createdAt: iso(now - 9 * day) }) },
    notes: Object.fromEntries([
      N('n1', 'work', 'Insurance callback script', 'Confirm the plan name first\nRead back the reference number #phones #billing', { pinned: true, projectId: 'pw2', ago: 3 }),
      N('n2', 'work', 'Huddle: new-hire onboarding', '- Shadow a full Monday\n- Cheat sheet by Friday\n- Pair with a senior for callbacks #training', { projectId: 'pw1', taskId: '1' }),
      N('n3', 'work', '', 'Label printer keeps jamming on the thick stock. IT ticket opened. #equipment', { ago: 1 }),
    ]),
  }),
  personal: replica({
    projects: { pp1: rec({ name: 'Car', workspace: 'personal', color: 3, createdAt: iso(now - 20 * day) }) },
    notes: Object.fromEntries([
      N('n4', 'personal', 'Gift ideas', 'Mom: the blue scarf from the market\nSam: board game #family', { ago: 5 }),
    ]),
  }),
};
const settings = { appearance: opt('--appearance', 'dark'), celebration: 'normal', quoteSeconds: 60, phiGuard: true };

const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
const browser = await chromium.launch({ args: proxy ? [`--proxy-server=${proxy}`] : [] });
const ctx = await browser.newContext({
  viewport: { width: +width, height: +height }, deviceScaleFactor: 2, locale: 'en-US',
  isMobile: +width < 600, hasTouch: +width < 600, colorScheme: 'dark',
});
await ctx.addInitScript(([t, p, s, r, empty, board]) => {
  if (!empty) {
    localStorage.setItem('flutter.tasks.v1', JSON.stringify(t));
    localStorage.setItem('flutter.progress.v1', JSON.stringify(p));
    for (const [ws, json] of Object.entries(r)) localStorage.setItem(`flutter.replica.v1.${ws}`, JSON.stringify(json));
  }
  if (board) localStorage.setItem('flutter.tasks.view', JSON.stringify('board'));
  localStorage.setItem('flutter.settings.v1', JSON.stringify(s));
}, [JSON.stringify(tasks), JSON.stringify(progress), JSON.stringify(settings), replicas, flag('--empty'), flag('--board')]);
const page = await ctx.newPage();
page.on('pageerror', (e) => console.log('pageerror:', e.message));
if (flag('--iphone')) {
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Emulation.setSafeAreaInsetsOverride', { insets: { top: 0, bottom: 34, left: 0, right: 0 } });
}
await page.goto(`${base}/#${path}`);
await page.waitForTimeout(6000); // Flutter web boot + first frames
const tap = opt('--tap', null);
if (tap) {
  const [x, y] = tap.split(',').map(Number);
  await page.mouse.click(x, y);
  await page.waitForTimeout(1500);
}
mkdirSync(outDir, { recursive: true });
await page.screenshot({ path: `${outDir}/${name}.png` });
console.log(`wrote ${outDir}/${name}.png`);
await browser.close();
