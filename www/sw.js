// Pixel Planner Service Worker
const CACHE_NAME = 'pixel-planner-v1';

const PRECACHE_URLS = [
  'manifest.json',
  'pixel_calendar.html',
  'icon.svg',
  'https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap'
];

// Install: pre-cache critical resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('SW precache partial failure:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

// Activate: clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Cache First strategy
self.addEventListener('fetch', (event) => {
  // Only handle GET requests
  if (event.request.method !== 'GET') return;

  // Skip chrome-extension and other non-http(s) requests
  const url = new URL(event.request.url);
  if (!url.protocol.startsWith('http')) return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(event.request).then((response) => {
        // Don't cache non-success responses
        if (!response || response.status !== 200 || response.type !== 'basic') {
          return response;
        }
        // Clone and cache
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseClone);
        });
        return response;
      }).catch(() => {
        // Offline fallback: return cached HTML for navigation requests
        if (event.request.mode === 'navigate') {
          return caches.match('pixel_calendar.html');
        }
        return new Response('Offline - Resource not available', { status: 503 });
      });
    })
  );
});
