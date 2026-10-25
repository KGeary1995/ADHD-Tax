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
//       [--tap x,y]  (tap a point after loading, e.g. to open a sheet;
//                    repeat it to tap several points in turn)
//       [--wait ms]  (wait before the screenshot, e.g. past the Started
//                    screen on /focus/1)
//       [--celebration off|subtle|normal|party] [--blocks] (block timer)
//       [--boot ms]  (time allowed for loading, default 6000)
//       [--type text] (then type, e.g. into Quick add)
//       [--scroll px] (scroll the page down before the screenshot)
//       [--iphone]   (fakes a 34px home-indicator inset, like an iPhone)
//       [--top px]   (with --iphone: a status-bar inset too, e.g. 62 for
//                    the Dynamic Island; the store-screenshot frames)
//       [--empty]    (no demo data)
//       [--board]    (Tasks opens as a board)
//       [--scale n]  (device pixel ratio, default 2; 3 at 430x932 gives the
//                    App Store's 6.9" iPhone size, 1290x2796)
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
const valued = ['--top', '--appearance', '--tap', '--type', '--scroll', '--scale', '--wait', '--celebration', '--boot'];
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
  T('1', 'Draft the quarterly report', { workspace: 'work', projectId: 'pw1', estimateMin: 60, priority: 'p1', chunkable: true,
    dueAt: iso(now + 0.8 * day), hardDeadline: true, firstStep: "Open last quarter's report and skim it", energy: 'high',
    checklist: "[x] Open last quarter's report and skim it\n[ ] List the three numbers that matter\n[ ] Write a paragraph for each\n[ ] Ask Alex to read it over",
    tags: 'planning' }),
  T('2', 'Reply to Jordan about the launch date', { workspace: 'work', priority: 'p2', firstStep: 'Open the email thread' }),
  T('3', 'Schedule dentist appointment', { estimateMin: 5, ugh: 2, firstStep: 'Find the number in contacts', createdAt: iso(now - 9 * day) }),
  T('4', 'Renew car registration', { projectId: 'pp1', requiresLeavingHouse: true, location: 'DMV', estimateMin: 30, priority: 'p2', ugh: 2, dueAt: iso(now + 3 * day) }),
  T('5', 'Laundry', { estimateMin: 30, energy: 'low', repeat: 'weekly' }),
  T('6', 'Pick up prescription', { requiresLeavingHouse: true, location: 'Pharmacy' }),
  T('7', 'Weekly team notes', { workspace: 'work', tags: 'planning', repeat: 'weekly', dueAt: iso(now + 6 * day), scheduledStart: iso(now + 4 * day) }),
  T('8', 'Get the expense report approved', { workspace: 'work', status: 'waiting', waitingOn: 'Sign-off from Priya', followUpAt: iso(now - 36e5) }),
  T('9', 'Order a new monitor', { workspace: 'work', status: 'waiting', waitingOn: 'IT ticket', followUpAt: iso(now + 3 * day) }),
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
// Started tasks over the last eight weeks, so Progress has stars to draw:
// runs of days in a row with a few gaps, busier on some days.
const startEvents = {};
for (let d = 0; d < 56; d++) {
  if ([3, 4, 9, 15, 16, 17, 24, 30, 31, 38, 45, 46].includes(d)) continue;
  const n = 1 + ((d * 7) % 4 === 0 ? 2 : (d % 3 === 0 ? 1 : 0));
  for (let i = 0; i < n; i++) {
    startEvents[`s${d}-${i}`] = rec({ at: iso(now - d * day - i * 36e5), kind: 'started', label: 'Started a task',
      xp: 10, coins: 1, started: 1, completed: 0, ughCompleted: 0, accurate: 0, oldCleared: 0, focusMinutes: 0,
      keptGoing: 0, panic: 0, errands: 0 });
  }
}
const replicas = {
  work: replica({
    projects: { pw1: rec({ name: 'Q4 planning', workspace: 'work', color: 0, createdAt: iso(now - 9 * day) }),
      pw2: rec({ name: 'Client work', workspace: 'work', color: 2, createdAt: iso(now - 9 * day) }) },
    templates: {
      tw1: rec({ kind: 'task', name: 'Start the workday', workspace: 'work', title: 'Start the day', estimateMin: 15, body: '', tags: '',
        checklist: "[ ] Check email and messages\n[ ] Look over today's calendar\n[ ] Pick the one thing that matters most today\n[ ] Clear the desk",
        createdAt: iso(now - 5 * day) }),
      tw2: rec({ kind: 'note', name: 'Meeting notes', workspace: 'work', title: 'Meeting {date}', estimateMin: 15, checklist: '', tags: '',
        body: 'Who:\n\nDecisions:\n\nQuestions:\n\nTo do:\n- ', createdAt: iso(now - 5 * day) }),
    },
    notes: Object.fromEntries([
      N('n1', 'work', 'Launch call prep', 'Confirm the budget first\nRepeat back the next steps #clients\nFor [[Reply to Jordan about the launch date]]', { pinned: true, projectId: 'pw2', ago: 3 }),
      N('n2', 'work', 'Kickoff: new teammate onboarding', '- Shadow a full Monday\n- Report draft by Friday: [[Draft the quarterly report]]\n- Pair up for client calls #onboarding\n- Book the [[Big meeting room]]', { projectId: 'pw1', taskId: '1' }),
      N('n3', 'work', '', 'Monitor flickers on the left side. IT ticket opened. #equipment', { ago: 1 }),
    ]),
  }),
  personal: replica({
    events: startEvents,
    projects: { pp1: rec({ name: 'Car', workspace: 'personal', color: 3, createdAt: iso(now - 20 * day) }) },
    rewards: {
      r1: rec({ name: 'Fancy coffee out', cost: 25, workspace: 'personal', createdAt: iso(now - 3 * day) }),
      r2: rec({ name: 'Order takeout', cost: 50, workspace: 'personal', createdAt: iso(now - 3 * day) }),
      r3: rec({ name: 'New running shoes', cost: 150, workspace: 'personal', createdAt: iso(now - 3 * day) }),
    },
    templates: {
      tp1: rec({ kind: 'task', name: 'Weekly reset', workspace: 'personal', title: 'Weekly reset', estimateMin: 60, body: '', tags: '',
        checklist: '[ ] Laundry\n[ ] Clear the kitchen\n[ ] Plan meals for the week', createdAt: iso(now - 5 * day) }),
    },
    notes: Object.fromEntries([
      N('n4', 'personal', 'Gift ideas', 'Mom: the blue scarf from the market\nSam: board game #family', { ago: 5 }),
    ]),
  }),
};
const settings = { appearance: opt('--appearance', 'dark'), celebration: opt('--celebration', 'normal'), quoteSeconds: 60, phiGuard: false,
  timerBlocks: flag('--blocks') };

const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
const browser = await chromium.launch({ args: proxy ? [`--proxy-server=${proxy}`] : [] });
const ctx = await browser.newContext({
  viewport: { width: +width, height: +height }, deviceScaleFactor: +opt('--scale', '2'), locale: 'en-US',
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
  const top = +opt('--top', '0');
  await cdp.send('Emulation.setSafeAreaInsetsOverride', { insets: { top, bottom: 34, left: 0, right: 0 } });
}
await page.goto(`${base}/#${path}`);
await page.waitForTimeout(+opt('--boot', '6000')); // Flutter web boot + first frames
for (const [i, a] of args.entries()) {
  if (a !== '--tap') continue;
  const [x, y] = args[i + 1].split(',').map(Number);
  await page.mouse.click(x, y);
  await page.waitForTimeout(1500);
}
const type = opt('--type', null);
if (type) {
  await page.keyboard.type(type, { delay: 20 });
  await page.waitForTimeout(800);
}
const scroll = opt('--scroll', null);
if (scroll) {
  await page.mouse.move(+width / 2, +height / 2);
  await page.mouse.wheel(0, +scroll);
  await page.waitForTimeout(800);
}
const wait = opt('--wait', null);
if (wait) await page.waitForTimeout(+wait);
mkdirSync(outDir, { recursive: true });
await page.screenshot({ path: `${outDir}/${name}.png` });
console.log(`wrote ${outDir}/${name}.png`);
await browser.close();
