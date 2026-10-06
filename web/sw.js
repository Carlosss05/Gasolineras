// Service worker de Gasolineras: permite abrir la app sin conexión y mostrar
// los últimos precios descargados. Sustituye al de Flutter, que está obsoleto.
//
// Estrategias:
// - Páginas y código de la app: red primero (para recibir actualizaciones)
//   y, sin conexión, la copia guardada.
// - Motor de Flutter y tipografías (URLs versionadas): caché primero.
// - API de precios: red primero con tiempo límite; sin conexión, la última
//   respuesta guardada (la app muestra la fecha de publicación de esos precios).
// - Teselas del mapa: caché primero, con un máximo de entradas.

const VERSION = 'v1';
const APP = `app-${VERSION}`;
const RUNTIME = `runtime-${VERSION}`;
const PRICES = `prices-${VERSION}`;
const TILES = `tiles-${VERSION}`;
const MAX_TILES = 400;

const SHELL = ['./', 'index.html', 'main.dart.js', 'flutter.js', 'flutter_bootstrap.js', 'manifest.json',
  'icons/Icon-192.png', 'favicon.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(APP).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  const keep = new Set([APP, RUNTIME, PRICES, TILES]);
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => !keep.has(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.hostname === 'sedeaplicaciones.minetur.gob.es') {
    event.respondWith(networkFirst(req, PRICES, 15000));
  } else if (url.hostname === 'tile.openstreetmap.org') {
    event.respondWith(cacheFirst(req, TILES, MAX_TILES));
  } else if (url.hostname === 'www.gstatic.com' || url.hostname.startsWith('fonts.')) {
    event.respondWith(cacheFirst(req, RUNTIME));
  } else if (url.origin === self.location.origin) {
    event.respondWith(networkFirst(req, APP, 6000));
  }
  // El resto (p. ej. OpenStreetMap Nominatim) va directo a la red.
});

async function networkFirst(req, cacheName, timeoutMs) {
  const cache = await caches.open(cacheName);
  try {
    const res = await withTimeout(fetch(req), timeoutMs);
    if (res.ok) cache.put(req, res.clone());
    return res;
  } catch (err) {
    const cached = await cache.match(req, { ignoreSearch: req.mode === 'navigate' });
    if (cached) return cached;
    if (req.mode === 'navigate') {
      const shell = await cache.match('index.html');
      if (shell) return shell;
    }
    throw err;
  }
}

async function cacheFirst(req, cacheName, maxEntries) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  if (cached) return cached;
  const res = await fetch(req);
  if (res.ok || res.type === 'opaque') {
    await cache.put(req, res.clone());
    if (maxEntries) trim(cache, maxEntries);
  }
  return res;
}

async function trim(cache, maxEntries) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - maxEntries; i++) await cache.delete(keys[i]);
}

function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout')), ms);
    promise.then((v) => { clearTimeout(t); resolve(v); }, (e) => { clearTimeout(t); reject(e); });
  });
}
