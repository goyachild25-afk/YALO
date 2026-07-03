// Implementación web real de la suscripción Web Push (API estándar del
// navegador, sin Firebase). Registra un service worker dedicado (push-sw.js)
// con scope propio para no interferir con el service worker de cacheo que
// Flutter registra en la raíz.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, String>?> subscribeToWebPush(String vapidPublicKey) async {
  if (!html.Notification.supported) return null;
  final container = html.window.navigator.serviceWorker;
  if (container == null) return null;

  final permission = await html.Notification.requestPermission();
  if (permission != 'granted') return null;

  final reg = await container.register('push-sw.js', {'scope': './yalo-push/'});

  // pushManager.subscribe exige un worker en estado "active"; tras el primer
  // register puede tardar unos ciclos en activarse.
  var attempts = 0;
  while (reg.active == null && attempts < 50) {
    await Future.delayed(const Duration(milliseconds: 200));
    attempts++;
  }
  if (reg.active == null) return null;

  final manager = reg.pushManager;
  if (manager == null) return null;

  html.PushSubscription? sub;
  try {
    sub = await manager.getSubscription();
  } catch (_) {
    sub = null;
  }
  sub ??= await manager.subscribe({
    'userVisibleOnly': true,
    'applicationServerKey': _base64UrlDecode(vapidPublicKey),
  });

  final endpoint = sub.endpoint;
  final p256dh = sub.getKey('p256dh');
  final auth = sub.getKey('auth');
  if (endpoint == null || p256dh == null || auth == null) return null;

  return {
    'endpoint': endpoint,
    'p256dh': _bytesToBase64Url(p256dh.asUint8List()),
    'auth': _bytesToBase64Url(auth.asUint8List()),
    'userAgent': html.window.navigator.userAgent,
  };
}

Uint8List _base64UrlDecode(String input) {
  var s = input.replaceAll('-', '+').replaceAll('_', '/');
  while (s.length % 4 != 0) {
    s += '=';
  }
  return Uint8List.fromList(base64.decode(s));
}

String _bytesToBase64Url(Uint8List bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');
