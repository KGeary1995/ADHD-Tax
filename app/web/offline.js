// Offline copy of the app for the iPhone home-screen version.
//
// Network first, so a new version is picked up as soon as it's deployed.
// Opening the app falls back to the saved copy when the network fails or
// takes too long (a dead Wi-Fi), and that page then runs entirely from
// the saved copy; a page that opened fresh only falls back on failure, so
// one page never mixes two versions. Every fresh file is saved for next
// time, even when it arrives late.
const CACHE = 'adhd-tax-offline-v1';
const SLOW_MS = 4000;

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// The first visit loads the app before this worker is running, so none of
// it went through the fetch handler below. The page sends the list of
// what it loaded (index.html) and it's saved now, so the very next launch
// opens offline.
self.addEventListener('message', (event) => {
  const urls = event.data && event.data.warm;
  if (Array.isArray(urls)) event.waitUntil(warm(urls));
});

async function warm(urls) {
  const cache = await caches.open(CACHE);
  await Promise.all(['./', ...urls].map(async (u) => {
    let url;
    try {
      url = new URL(u, self.location.href);
    } catch (_) {
      return;
    }
    if (url.origin !== self.location.origin || url.pathname.includes('/auth/')) return;
    url.hash = '';
    if (await cache.match(url.href)) return;
    try {
      const res = await fetch(url.href);
      if (res.ok) await cache.put(url.href, res);
    } catch (_) {
      // Offline already: whatever loads next is saved by the fetch handler.
    }
  }));
}

// Pages opened from the saved copy (the network was down or slow when they
// loaded). Everything such a page asks for comes from the saved copy too,
// so it runs one consistent version instead of new code on old files.
const fromSaved = new Set();

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin ||
      url.pathname.includes('/auth/')) {
    // Sign-in and Drive calls go straight to the network; a sign-in reply
    // (it carries a one-time code) is never kept in the offline copy.
    return;
  }
  // Cloned at once (the page may read the body first) and saved whenever
  // it arrives, even after the saved copy already answered: waitUntil is
  // called here, during the event, so the worker stays alive for it.
  const network = fetch(req).then((res) => {
    // A server error (Cloudflare having a bad minute) is no better than no
    // network: use the saved copy instead, if there is one.
    if (res.status >= 500) throw new Error(`server ${res.status}`);
    return { res, copy: res.ok ? res.clone() : null };
  });
  event.waitUntil(
    network
      .then(async ({ copy }) => {
        if (copy) await (await caches.open(CACHE)).put(req, copy);
      })
      .catch(() => {}),
  );
  event.respondWith(respond(event, req, network));
});

async function respond(event, req, network) {
  const cache = await caches.open(CACHE);
  const saved = () =>
    cache.match(req).then((r) => r || (req.mode === 'navigate' ? cache.match('./') : undefined));
  const live = network.then(({ res }) => res);

  if (req.mode !== 'navigate') {
    // A page running from the saved copy keeps to it.
    if (fromSaved.has(event.clientId)) {
      const hit = await saved();
      if (hit) return hit;
    }
    // A page that loaded fresh gets fresh files, however slow: falling back
    // after a few seconds would mix a new main.dart.js with an old
    // CanvasKit. The saved copy only stands in when the network fails.
    try {
      return await live;
    } catch (_) {
      const hit = await saved();
      if (hit) return hit;
      return fetch(req);
    }
  }

  // Opening the app: the network if it answers quickly, else the saved copy
  // (a dead Wi-Fi), and then that page stays on the saved copy.
  try {
    return await Promise.race([
      live,
      new Promise((_, reject) => setTimeout(() => reject(new Error('slow')), SLOW_MS)),
    ]);
  } catch (_) {
    const fallback = await saved();
    if (fallback) {
      if (event.resultingClientId) fromSaved.add(event.resultingClientId);
      return fallback;
    }
    // Nothing saved yet: keep waiting on the network, and pass a server
    // error page through rather than failing the request.
    return live.catch(() => fetch(req));
  }
}
