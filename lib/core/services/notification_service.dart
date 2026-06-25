import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/firebase_options.dart';
import 'supabase_service.dart';

// Handler de background — debe ser función top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  /// Inicializar Firebase + FCM. Llamar en main() antes de runApp.
  static Future<void> initializeFirebase() async {
    if (_initialized) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _initialized = true;
  }

  /// Solicitar permiso y guardar token FCM del usuario logueado.
  static Future<void> registerUser(String userId) async {
    try {
      final settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 8));
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = kIsWeb
          ? await FirebaseMessaging.instance
              .getToken(vapidKey: AppFirebaseOptions.webVapidKey)
              .timeout(const Duration(seconds: 8))
          : await FirebaseMessaging.instance
              .getToken()
              .timeout(const Duration(seconds: 8));

      if (token != null) await _upsertToken(userId, token);

      FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => _upsertToken(userId, t));
    } catch (e) {
      debugPrint('FCM registerUser error: $e');
    }
  }

  static Future<void> _upsertToken(String userId, String token) async {
    try {
      await SupabaseService.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('FCM upsertToken error: $e');
    }
  }

  /// Eliminar token cuando el usuario cierra sesión.
  static Future<void> unregisterUser(String userId) async {
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
      if (token == null) return;
      await SupabaseService.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token)
          .timeout(const Duration(seconds: 5));
      await FirebaseMessaging.instance
          .deleteToken()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM unregisterUser error: $e');
    }
  }

  /// Stream de notificaciones con app en primer plano.
  static Stream<RemoteMessage> get onForeground =>
      FirebaseMessaging.onMessage;

  /// Stream de mensajes que abrieron la app.
  static Stream<RemoteMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Mensaje que lanzó la app desde estado terminado.
  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();

  /// Tipo de notificación para navegar al destino correcto.
  static String? getRouteFromMessage(RemoteMessage msg) {
    final type = msg.data['type'];
    final id = msg.data['booking_id'] ?? msg.data['id'];
    switch (type) {
      case 'new_booking':
      case 'booking_accepted':
      case 'booking_completed':
        return id != null ? '/bookings' : null;
      case 'new_message':
        return id != null ? '/chat/$id' : null;
      default:
        return null;
    }
  }
}

final foregroundMessageProvider =
    StreamProvider<RemoteMessage>((ref) => NotificationService.onForeground);
