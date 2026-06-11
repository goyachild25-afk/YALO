import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locales para timeago en español
  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Inicializar Supabase
  try {
    await SupabaseService.initialize();
  } catch (_) {
    // Sin credenciales reales → la app funciona en Modo Demo
  }

  // Inicializar Firebase (para push notifications)
  try {
    await NotificationService.initializeFirebase();
  } catch (_) {
    // Firebase no configurado aún → notificaciones no disponibles
  }

  runApp(
    const ProviderScope(
      child: ServiciosYaApp(),
    ),
  );
}
