// Offline copy of the app for the iPhone home-screen version.
//
// Network first, so a new version is picked up as soon as it's deployed;
// the saved copy is only used when the network fails or takes too long
// (a dead clinic Wi-Fi), so it's never stuck on an old version.
const CACHE = 'adhd-tax-offline-v1';
const SLOW_MS = 4000;

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin ||
      url.pathname.includes('/auth/')) {
    // Sign-in and Drive calls go straight to the network; a sign-in reply
    // (it carries a one-time code) is never kept in the offline copy.
    return;
  }
  event.respondWith(respond(event, req));
});

async function respond(event, req) {
  const cache = await caches.open(CACHE);
  const network = fetch(req).then((res) => {
    // A server error (Cloudflare having a bad minute) is no better than no
    // network: use the saved copy instead, if there is one.
    if (res.status >= 500) throw new Error(`server ${res.status}`);
    // Keep the worker alive until the copy is saved.
    if (res.ok) event.waitUntil(cache.put(req, res.clone()));
    return res;
  });
  network.catch(() => {}); // Handled below; no "unhandled rejection" noise.
  const saved = () =>
    cache.match(req).then((r) => r || (req.mode === 'navigate' ? cache.match('./') : undefined));
  try {
    return await Promise.race([
      network,
      new Promise((_, reject) => setTimeout(() => reject(new Error('slow')), SLOW_MS)),
    ]);
  } catch (_) {
    const fallback = await saved();
    if (fallback) return fallback;
    // Nothing saved yet: keep waiting on the network, and pass a server
    // error page through rather than failing the request.
    return network.catch(() => fetch(req));
  }
}
