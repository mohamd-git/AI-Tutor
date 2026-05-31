// Kill-switch service worker.
//
// Earlier builds registered a Flutter offline service worker that kept serving
// an OLD copy of the app, so fixes never reached devices that had opened it
// before (the desktop only worked because it was hard-refreshed).
//
// Any browser still running that old worker fetches this file when it checks
// for an update. This replacement immediately unregisters itself, deletes every
// cache, and reloads open tabs - so the device drops the stale copy and loads
// the latest version from the network. New visitors never register a worker at
// all (see the script in index.html), so this only runs once per stuck device.
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      try {
        var keys = await caches.keys();
        await Promise.all(keys.map(function (k) { return caches.delete(k); }));
      } catch (e) {}
      try {
        await self.registration.unregister();
      } catch (e) {}
      try {
        var clients = await self.clients.matchAll({ type: 'window' });
        clients.forEach(function (c) {
          c.navigate(c.url);
        });
      } catch (e) {}
    })()
  );
});

// Always go to the network; never serve anything from a cache.
self.addEventListener('fetch', function (event) {});
