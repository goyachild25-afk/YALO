import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../providers_list/models/service_provider_model.dart';

class _LevelInfo {
  final ProviderLevel current;
  final int completedJobs;
  const _LevelInfo({required this.current, required this.completedJobs});
}

final _levelInfoProvider =
    FutureProvider.autoDispose<_LevelInfo?>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return null;
  try {
    final pp = await SupabaseService.client
        .from('provider_profiles')
        .select('level, completed_jobs')
        .eq('user_id', user.id)
        .maybeSingle();
    if (pp == null) return null;
    return _LevelInfo(
      current: ProviderLevelX.fromDb(pp['level'] as String?),
      completedJobs: (pp['completed_jobs'] as int?) ?? 0,
    );
  } catch (_) {
    return null;
  }
});

/// Tarjeta motivadora en el dashboard del prestador: muestra el nivel
/// actual, cuántos trabajos faltan para el siguiente, y qué beneficio
/// desbloqueará. Si ya es Élite, celebra el logro.
class LevelProgressCard extends ConsumerWidget {
  const LevelProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_levelInfoProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        final level = info.current;
        final next = level.next;
        final done = info.completedJobs;

        // Si es Élite → tarjeta de celebración
        if (next == null) {
          return _CelebrationCard(current: level, completedJobs: done);
        }

        final minCurrent = level.minJobs;
        final minNext = next.minJobs;
        final range = (minNext - minCurrent).clamp(1, 1000);
        final progress = ((done - minCurrent) / range).clamp(0.0, 1.0);
        final remaining = (minNext - done).clamp(1, 1000);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                (next == ProviderLevel.elite
                        ? const Color(0xFF7C3AED)
                        : AppColors.gold)
                    .withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(level.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    level.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$done trabajos',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(
                    next == ProviderLevel.elite
                        ? const Color(0xFF7C3AED)
                        : AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Mensaje motivador
              Row(
                children: [
                  Text(next.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4),
                        children: [
                          const TextSpan(text: 'Faltan '),
                          TextSpan(
                            text: '$remaining trabajo${remaining == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const TextSpan(text: ' para llegar a '),
                          TextSpan(
                            text: next.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: next == ProviderLevel.elite
                                  ? const Color(0xFF7C3AED)
                                  : AppColors.goldDark,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' — tu comisión bajará a ${next.commissionLabel}.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final ProviderLevel current;
  final int completedJobs;
  const _CelebrationCard({
    required this.current,
    required this.completedJobs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF0077B6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('💎', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Eres ${current.label}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$completedJobs trabajos completados · comisión ${current.commissionLabel} · badge visible para todos los clientes.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
