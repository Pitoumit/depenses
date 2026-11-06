// Met en cache l'interface pour un démarrage rapide. Les données viennent toujours de Supabase.
const CACHE = "depenses-v10";
const SHELL = ["./", "index.html", "config.js", "manifest.webmanifest", "apple-touch-icon.png", "icon-192.png", "icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  const isShell = url.origin === location.origin || url.hostname === "cdn.jsdelivr.net";
  if (!isShell) return; // appels Supabase : jamais en cache
  e.respondWith(
    // "no-cache" : toujours vérifier auprès du serveur (évite d'attendre ~10 min après une mise à jour)
    fetch(e.request, url.origin === location.origin ? { cache: "no-cache" } : {})
      .then((res) => { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(e.request, copy)); return res; })
      .catch(() => caches.match(e.request))
  );
});
