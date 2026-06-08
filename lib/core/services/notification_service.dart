// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Push Notifications via FCM
//
// ESTADO: Estructura lista. Para activar:
//   1. Crear proyecto en Firebase Console (console.firebase.google.com)
//   2. Agregar app Android (com.serviciosya.app) y iOS
//   3. Descargar google-services.json → android/app/
//   4. Descargar GoogleService-Info.plist → ios/Runner/
//   5. En pubspec.yaml agregar:
//        firebase_core: ^3.x.x
//        firebase_messaging: ^15.x.x
//        flutter_local_notifications: ^18.x.x
//   6. Quitar los comentarios de este archivo
//   7. Llamar NotificationService.initialize() en main.dart
//   8. Crear Supabase Edge Function 'send-push' que llame a FCM API
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';

// ─── Provider global ──────────────────────────────────────────────────────────
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // FCM token del dispositivo actual
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Inicializar el servicio.
  /// Llamar desde main.dart después de inicializar Supabase.
  Future<void> initialize() async {
    if (kIsWeb) {
      // Push notifications no disponibles en web — usar polling via Supabase Realtime
      debugPrint('NotificationService: Web mode — FCM not available, using Supabase Realtime');
      return;
    }

    // ── Descomentar cuando se agreguen las dependencias de Firebase ──────────
    //
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    //
    // final messaging = FirebaseMessaging.instance;
    //
    // // Solicitar permisos (iOS)
    // await messaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
    //
    // // Obtener token FCM
    // _fcmToken = await messaging.getToken();
    // debugPrint('FCM Token: $_fcmToken');
    //
    // // Guardar token en Supabase para enviar notificaciones al usuario
    // if (_fcmToken != null) {
    //   await _saveFcmToken(_fcmToken!);
    // }
    //
    // // Escuchar cambios de token
    // messaging.onTokenRefresh.listen(_saveFcmToken);
    //
    // // Manejar notificaciones en foreground
    // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    //
    // // Manejar tap en notificación (app en background/terminada)
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    //
    // // Inicializar flutter_local_notifications para mostrar en foreground
    // await _initLocalNotifications();
    // ─────────────────────────────────────────────────────────────────────────

    debugPrint('NotificationService: FCM not configured yet');
  }

  /// Guarda el token FCM en la tabla device_tokens de Supabase.
  Future<void> _saveFcmToken(String token) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      await SupabaseService.client.from('device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // ── Handlers (descomentar con Firebase) ─────────────────────────────────────

  // void _handleForegroundMessage(RemoteMessage message) {
  //   debugPrint('FCM foreground: ${message.notification?.title}');
  //   _showLocalNotification(message);
  // }

  // void _handleNotificationTap(RemoteMessage message) {
  //   // Navegar según el tipo de notificación
  //   final data = message.data;
  //   final type = data['type'] as String?;
  //   switch (type) {
  //     case 'bookingAccepted':
  //     case 'newBookingRequest':
  //       // router.push('/bookings/${data['booking_id']}');
  //       break;
  //     case 'newMessage':
  //       // router.push('/chat/${data['booking_id']}');
  //       break;
  //   }
  // }
}

// ─────────────────────────────────────────────────────────────────────────────
// SQL para crear la tabla device_tokens en Supabase:
//
// CREATE TABLE IF NOT EXISTS device_tokens (
//   id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
//   user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
//   token       TEXT NOT NULL,
//   platform    TEXT NOT NULL DEFAULT 'android',
//   updated_at  TIMESTAMPTZ DEFAULT NOW(),
//   UNIQUE(user_id, token)
// );
//
// ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
//
// CREATE POLICY "users_own_tokens" ON device_tokens
//   FOR ALL USING (auth.uid() = user_id);
// ─────────────────────────────────────────────────────────────────────────────
