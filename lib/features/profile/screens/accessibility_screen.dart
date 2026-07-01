import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/accessibility_service.dart';

/// Pantalla de accesibilidad: escala del texto y modo de tema.
/// Diseñada específicamente pensando en usuarios mayores — controles grandes,
/// ejemplos visibles en tiempo real, sin jerga técnica.
class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    final theme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accesibilidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Volver',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Vista previa en vivo ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vista previa',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('Cambia los ajustes y verás cómo lucirá la app.',
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Tamaño del texto ─────────────────────────────────
          const _SectionHeader(
            title: 'Tamaño del texto',
            subtitle: 'Elige el que mejor puedas leer sin esforzarte.',
          ),
          const SizedBox(height: 12),
          for (final option in AppTextScale.values)
            _OptionTile(
              label: option.label,
              description: option.description,
              selected: option == scale,
              onTap: () =>
                  ref.read(textScaleProvider.notifier).set(option),
              trailingText: '×${option.scale}',
            ),
          const SizedBox(height: 32),

          // ── Modo de tema ─────────────────────────────────────
          const _SectionHeader(
            title: 'Modo claro u oscuro',
            subtitle: 'El modo oscuro es más cómodo con poca luz.',
          ),
          const SizedBox(height: 12),
          for (final option in AppThemeMode.values)
            _OptionTile(
              label: option.label,
              description: option.description,
              selected: option == theme,
              onTap: () =>
                  ref.read(themeModeProvider.notifier).set(option),
              trailingIcon: _iconForMode(option),
            ),
          const SizedBox(height: 32),

          // ── Otros consejos ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                      children: const [
                        TextSpan(
                            text: '¿Necesitas ayuda? ',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                            text:
                                'En cualquier pantalla puedes tocar el botón redondo con "?" para hablar con soporte por WhatsApp.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingText;
  final IconData? trailingIcon;

  const _OptionTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.trailingText,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.primaryLighter : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // 56px de altura mínima por item — cumple tap target ≥ 44px con
          // margen para dedos con temblor.
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Radio button grande, fácil de ver
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : Theme.of(context).dividerColor,
                      width: 2,
                    ),
                    color: selected
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(description,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (trailingText != null)
                  Text(trailingText!,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary)),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: AppColors.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
