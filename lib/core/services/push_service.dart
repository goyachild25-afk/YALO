import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'supabase_service.dart';

// Import condicional: en Flutter web usa la implementación real (dart:html);
// en cualquier otra plataforma (o en `flutter test` sobre la VM) usa el stub.
import 'push_service_stub.dart'
    if (dart.library.html) 'push_service_web.dart' as impl;

/// Web Push para prestadores: pide permiso de notificaciones, suscribe el
/// navegador con la clave VAPID pública y registra la suscripción vía RPC
/// `claim_push_subscription`. La Edge Function `notify-new-request` usa esas
/// filas para avisar de solicitudes nuevas aunque la app esté cerrada.
class PushService {
  PushService._();

  static bool _done = false;

  /// Best-effort: nunca lanza ni bloquea la UI. Llamar al entrar al
  /// dashboard del prestador (es quien recibe pushes de solicitudes).
  static Future<void> ensureSubscribed() async {
    if (!kIsWeb || _done) return;
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final sub = await impl.subscribeToWebPush(AppConstants.vapidPublicKey);
      if (sub == null) return; // sin soporte o permiso denegado
      await SupabaseService.client.rpc('claim_push_subscription', params: {
        'p_endpoint': sub['endpoint'],
        'p_p256dh': sub['p256dh'],
        'p_auth': sub['auth'],
        'p_user_agent': sub['userAgent'],
      });
      _done = true;
    } catch (_) {
      // El push es un extra: si falla, la app sigue funcionando igual.
    }
  }
}
