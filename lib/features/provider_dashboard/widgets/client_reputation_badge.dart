import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class ClientReputation {
  final double avgRating;
  final int reviewCount;
  final int completedBookings;

  const ClientReputation({
    required this.avgRating,
    required this.reviewCount,
    required this.completedBookings,
  });

  bool get isNew => completedBookings == 0;
  bool get isNewish => completedBookings > 0 && completedBookings < 3;
}

/// Reputación agregada del cliente para que el prestador decida si aceptar
/// una solicitud. Dos ratos:
///   - `client_ratings` → estrellas dadas por prestadores previos
///   - `bookings.status='completed'` → cuántos trabajos ya se completaron
final clientReputationProvider =
    FutureProvider.autoDispose.family<ClientReputation, String>(
  (ref, clientId) async {
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.client
            .from('client_ratings')
            .select('rating')
            .eq('client_id', clientId),
        SupabaseService.client
            .from('bookings')
            .select('id')
            .eq('client_id', clientId)
            .eq('status', 'completed'),
      ]);

      final ratings = (results[0] as List<dynamic>);
      final completed = (results[1] as List<dynamic>).length;

      double avg = 0;
      if (ratings.isNotEmpty) {
        final total = ratings.fold<double>(
          0,
          (s, r) =>
              s + ((r as Map<String, dynamic>)['rating'] as num).toDouble(),
        );
        avg = total / ratings.length;
      }

      return ClientReputation(
        avgRating: avg,
        reviewCount: ratings.length,
        completedBookings: completed,
      );
    } catch (_) {
      return const ClientReputation(
          avgRating: 0, reviewCount: 0, completedBookings: 0);
    }
  },
);

/// Badge inline con la reputación del cliente. Muy pequeño pero informativo:
///   ⭐ 4.7 · 12 trabajos    (cliente frecuente)
///   ⭐ 5.0 · 1 trabajo      (cliente nuevo, 1 reseña)
///   🆕 Cliente nuevo         (0 trabajos completados)
class ClientReputationBadge extends ConsumerWidget {
  final String clientId;
  final bool compact;
  const ClientReputationBadge({
    super.key,
    required this.clientId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientReputationProvider(clientId));
    return async.when(
      loading: () => const SizedBox(
          height: 20,
          child: Center(
            child: SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          )),
      error: (_, __) => const SizedBox.shrink(),
      data: (rep) {
        // Cliente completamente nuevo — mostrar badge diferente
        if (rep.isNew) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_new_rounded,
                    size: 14, color: AppColors.info),
                SizedBox(width: 4),
                Text('Cliente nuevo',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info)),
              ],
            ),
          );
        }

        // Cliente con historial pero sin reseñas todavía
        if (rep.reviewCount == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${rep.completedBookings} trabajos',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        // Cliente con estrellas
        final color = rep.avgRating >= 4.5
            ? AppColors.success
            : rep.avgRating >= 3.5
                ? AppColors.primary
                : AppColors.warning;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 14, color: color),
              const SizedBox(width: 2),
              Text(
                rep.avgRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${rep.completedBookings} trabajos',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
