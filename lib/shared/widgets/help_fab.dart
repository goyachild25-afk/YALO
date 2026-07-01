import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

/// Floating "?" button that opens WhatsApp with a message tagged with the
/// screen the user was on. Read the support phone from public.app_settings
/// so an admin can update it without a code change.
///
/// Diseñado para adultos mayores: 64x64 px (más grande que un FAB normal),
/// contraste alto, halo verde WhatsApp para reconocimiento inmediato.
class HelpFab extends ConsumerStatefulWidget {
  /// Etiqueta del contexto que se manda con el mensaje de WhatsApp
  /// (p.ej. "Inicio", "Solicitar servicio", "Mis reservas").
  final String screenLabel;

  const HelpFab({super.key, required this.screenLabel});

  @override
  ConsumerState<HelpFab> createState() => _HelpFabState();
}

class _HelpFabState extends ConsumerState<HelpFab> {
  String? _whatsapp;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await SupabaseService.client
          .from('app_settings')
          .select('value')
          .eq('key', 'support_whatsapp')
          .maybeSingle();
      if (mounted) setState(() => _whatsapp = row?['value'] as String?);
    } catch (_) {
      // fallback a hardcoded si falla la lectura
      if (mounted) setState(() => _whatsapp = '18095550000');
    }
  }

  Future<void> _open() async {
    HapticFeedback.mediumImpact();
    if (_whatsapp == null || _whatsapp!.isEmpty) return;
    setState(() => _loading = true);
    final msg =
        'Hola, necesito ayuda con ServiciosYa. Estoy en: ${widget.screenLabel}';
    final uri = Uri.parse(
        'https://wa.me/${_whatsapp!}?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudo abrir WhatsApp. Puedes escribir a +$_whatsapp')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Necesito ayuda por WhatsApp',
      child: Material(
        elevation: 8,
        shape: const CircleBorder(),
        color: const Color(0xFF25D366), // Verde WhatsApp
        shadowColor: const Color(0x8025D366),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _loading ? null : _open,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper para colocar el FAB de ayuda en cualquier Scaffold. Lo posicionamos
/// en bottom-left para NO chocar con FABs de acción principal (por ejemplo,
/// el FAB "publicar" del prestador está a la derecha). También añade padding
/// para que respete la BottomNavigationBar.
class HelpFabAnchor extends StatelessWidget {
  final String screenLabel;
  final double? bottomOffset;
  const HelpFabAnchor({
    super.key,
    required this.screenLabel,
    this.bottomOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: bottomOffset ?? (kBottomNavigationBarHeight + 20),
      child: HelpFab(screenLabel: screenLabel),
    );
  }
}

/// Helper: vibrar cuando algo se confirma con éxito.
/// Uso: `await confirmHaptic();` justo después de un submit exitoso.
Future<void> confirmHaptic() async {
  // Doble tick corto — reconocible sin ser molesto, funciona en Android/iOS
  await HapticFeedback.mediumImpact();
  await Future.delayed(const Duration(milliseconds: 60));
  await HapticFeedback.lightImpact();
}
