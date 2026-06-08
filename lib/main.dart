import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/services/payment_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locales para timeago en español
  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Inicializar Supabase (falla silenciosamente si no hay credenciales reales)
  try {
    await SupabaseService.initialize();
  } catch (_) {
    // Sin credenciales reales → la app funciona en Modo Demo
  }

  // Inicializar Stripe (opcional, solo para pagos reales)
  try {
    PaymentService.initialize();
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: ServiciosYaApp(),
    ),
  );
}
