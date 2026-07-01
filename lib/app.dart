import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/accessibility_service.dart';
import 'core/services/live_notifications_service.dart';
import 'core/theme/app_theme.dart';

class ServiciosYaApp extends ConsumerWidget {
  const ServiciosYaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final textScale = ref.watch(textScaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'ServiciosYa',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode.mode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Aplica la escala de texto elegida por el usuario. Cualquier Text
        // en la app hereda esta escala automáticamente. También monta el
        // LiveNotificationsHost — al ir por encima del child, sus overlays
        // aparecen sobre cualquier pantalla del router.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale.scale),
          ),
          child: LiveNotificationsHost(child: child!),
        );
      },
    );
  }
}
