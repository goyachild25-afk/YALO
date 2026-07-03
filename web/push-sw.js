// YALO — Service worker dedicado a Web Push (API estándar, sin Firebase).
// Registrado por push_service_web.dart con scope './yalo-push/' para
// coexistir con el service worker de cacheo de Flutter.
//
// El payload lo envía la Edge Function notify-new-request:
//   { title, body, data: { type, booking_id } }

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {}

  const title = payload.title || 'YALO';
  const data = payload.data || {};

  event.waitUntil(self.registration.showNotification(title, {
    body: payload.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data,
    tag: data.booking_id || 'yalo',
    renotify: true,
    vibrate: [200, 100, 200],
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  // push-sw.js vive en la raíz del deploy (p.ej. /Serviciosya/), así que la
  // base de la app se deriva de la URL del propio worker.
  const base = new URL('./', self.location.href).href;
  const url = base + '#/dashboard';

  event.waitUntil((async () => {
    const wins = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of wins) {
      if (w.url.startsWith(base) && 'focus' in w) {
        await w.focus();
        return;
      }
    }
    await clients.openWindow(url);
  })());
});
