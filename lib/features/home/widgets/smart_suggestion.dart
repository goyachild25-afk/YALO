import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';

/// Sugerencia calculada del historial del cliente.
class ClientSuggestion {
  /// Prestador con quien más ha reservado el mismo servicio.
  final String providerId;
  final String providerName;
  final String? providerAvatarUrl;

  /// Nombre del servicio (ej. "Limpieza del hogar").
  final String serviceName;

  /// category_id granular (ej. 'home_cleaning') — para navegar directo.
  final String categoryId;

  /// Cuántas veces el cliente reservó este servicio con este prestador.
  final int repeatCount;

  const ClientSuggestion({
    required this.providerId,
    required this.providerName,
    this.providerAvatarUrl,
    required this.serviceName,
    required this.categoryId,
    required this.repeatCount,
  });
}

/// Analiza las últimas reservas COMPLETADAS del cliente para sugerirle repetir
/// con el prestador con quien tiene mejor historial. Devuelve null si no hay
/// suficiente historial (2+ reservas con el mismo prestador del mismo servicio).
///
/// Es una consulta barata (limit 20) y `autoDispose` para no mantener cache
/// eterno entre navegaciones.
final smartSuggestionProvider =
    FutureProvider.autoDispose<ClientSuggestion?>((ref) async {
  if (ref.watch(demoModeProvider)) return null;
  final user = SupabaseService.currentUser;
  if (user == null) return null;

  try {
    final rows = await SupabaseService.client
        .from('bookings')
        .select(
            'provider_id, provider_name, provider_avatar_url, service_name, category_id, status')
        .eq('client_id', user.id)
        .eq('status', 'completed')
        .not('provider_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(20);

    // Agrupar por (provider_id, service_name)
    final counts = <String, _Bucket>{};
    for (final r in (rows as List<dynamic>)) {
      final m = r as Map<String, dynamic>;
      final pid = m['provider_id'] as String?;
      final svc = m['service_name'] as String?;
      if (pid == null || svc == null) continue;
      final key = '$pid|$svc';
      final b = counts.putIfAbsent(key, () => _Bucket());
      b.count++;
      b.providerId = pid;
      b.providerName = m['provider_name'] as String? ?? 'Prestador';
      b.providerAvatarUrl = m['provider_avatar_url'] as String?;
      b.serviceName = svc;
      b.categoryId = m['category_id'] as String? ?? '';
    }

    if (counts.isEmpty) return null;
    final top = counts.values.reduce((a, b) => a.count >= b.count ? a : b);
    // Solo sugerimos cuando hay repetición real (2+). Una sola vez es azar.
    if (top.count < 2) return null;

    return ClientSuggestion(
      providerId: top.providerId,
      providerName: top.providerName,
      providerAvatarUrl: top.providerAvatarUrl,
      serviceName: top.serviceName,
      categoryId: top.categoryId,
      repeatCount: top.count,
    );
  } catch (_) {
    return null;
  }
});

class _Bucket {
  int count = 0;
  String providerId = '';
  String providerName = '';
  String? providerAvatarUrl;
  String serviceName = '';
  String categoryId = '';
}

/// Tarjeta visual de sugerencia. Se colapsa a `SizedBox.shrink()` si no hay
/// nada que sugerir — así el home la puede montar sin gates externos.
class SmartSuggestionCard extends ConsumerWidget {
  const SmartSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(smartSuggestionProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/provider/${s.providerId}'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF3CC), // gold light
                      Color(0xFFFFE2D8), // coral light
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // Avatar del prestador sugerido
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        image: s.providerAvatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(s.providerAvatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: s.providerAvatarUrl == null
                          ? Center(
                              child: Text(
                                s.providerName.isNotEmpty
                                    ? s.providerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: AppColors.goldDark),
                              const SizedBox(width: 4),
                              Text(
                                'Sugerencia para ti',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.goldDark,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¿Repetir ${s.serviceName.toLowerCase()} con ${s.providerName.split(' ').first}?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ya lo has reservado ${s.repeatCount} veces con muy buen resultado.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
