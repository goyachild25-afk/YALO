import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class _ProviderStats {
  final int totalCompleted;
  final int last30DaysCompleted;
  final double last30DaysRevenue;
  final int pendingResponses;
  final Duration avgResponseTime;
  final double rating;
  final int reviewCount;

  const _ProviderStats({
    required this.totalCompleted,
    required this.last30DaysCompleted,
    required this.last30DaysRevenue,
    required this.pendingResponses,
    required this.avgResponseTime,
    required this.rating,
    required this.reviewCount,
  });
}

final _providerStatsProvider =
    FutureProvider.autoDispose<_ProviderStats>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) {
    return const _ProviderStats(
      totalCompleted: 0,
      last30DaysCompleted: 0,
      last30DaysRevenue: 0,
      pendingResponses: 0,
      avgResponseTime: Duration.zero,
      rating: 0,
      reviewCount: 0,
    );
  }

  // Resolver el provider_profile del usuario
  final pp = await SupabaseService.client
      .from('provider_profiles')
      .select('id, rating, review_count')
      .eq('user_id', user.id)
      .maybeSingle();
  if (pp == null) {
    return const _ProviderStats(
      totalCompleted: 0,
      last30DaysCompleted: 0,
      last30DaysRevenue: 0,
      pendingResponses: 0,
      avgResponseTime: Duration.zero,
      rating: 0,
      reviewCount: 0,
    );
  }

  final providerId = pp['id'] as String;
  final since30 =
      DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

  // Reservas del prestador
  final bookings = await SupabaseService.client
      .from('bookings')
      .select('status, agreed_price, created_at, updated_at')
      .eq('provider_id', providerId);
  final list = (bookings as List<dynamic>).cast<Map<String, dynamic>>();

  int totalCompleted = 0;
  int last30Completed = 0;
  double last30Revenue = 0;
  int pending = 0;
  final responseTimes = <Duration>[];

  for (final b in list) {
    final status = b['status'] as String?;
    if (status == 'completed') {
      totalCompleted++;
      final createdStr = b['created_at'] as String?;
      final updatedStr = b['updated_at'] as String?;
      if (createdStr != null && createdStr.compareTo(since30) >= 0) {
        last30Completed++;
        last30Revenue += (b['agreed_price'] as num?)?.toDouble() ?? 0;
      }
      // Tiempo de respuesta (created -> accepted). Aproximado usando
      // created vs updated para las que ya no están pending.
      final c = DateTime.tryParse(createdStr ?? '');
      final u = DateTime.tryParse(updatedStr ?? '');
      if (c != null && u != null && u.isAfter(c)) {
        responseTimes.add(u.difference(c));
      }
    } else if (status == 'pending') {
      pending++;
    }
  }

  Duration avgResponse = Duration.zero;
  if (responseTimes.isNotEmpty) {
    final totalMs =
        responseTimes.fold<int>(0, (s, d) => s + d.inMilliseconds);
    avgResponse = Duration(milliseconds: totalMs ~/ responseTimes.length);
  }

  return _ProviderStats(
    totalCompleted: totalCompleted,
    last30DaysCompleted: last30Completed,
    last30DaysRevenue: last30Revenue,
    pendingResponses: pending,
    avgResponseTime: avgResponse,
    rating: ((pp['rating'] as num?) ?? 0).toDouble(),
    reviewCount: (pp['review_count'] as int?) ?? 0,
  );
});

/// Sección "Mi rendimiento" para el dashboard del prestador. Es un
/// ConsumerWidget compacto que muestra:
///   - Trabajos completados en total y en los últimos 30 días
///   - Ingresos brutos de los últimos 30 días
///   - Rating y # de reseñas
///   - Tiempo promedio de respuesta
///   - Solicitudes pendientes
class ProviderStatsSection extends ConsumerWidget {
  const ProviderStatsSection({super.key});

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    if (h < 24) return '${h}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${(h % 24)}h';
  }

  String _formatMoney(double v) =>
      'RD\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_providerStatsProvider);
    return async.when(
      loading: () => const _StatsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi rendimiento',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _MetricCard(
                label: 'Ingresos (30 días)',
                value: _formatMoney(s.last30DaysRevenue),
                icon: Icons.attach_money_rounded,
                color: AppColors.success,
              ),
              _MetricCard(
                label: 'Trabajos (30 días)',
                value: '${s.last30DaysCompleted}',
                sub: 'Total: ${s.totalCompleted}',
                icon: Icons.work_history_rounded,
                color: AppColors.primary,
              ),
              _MetricCard(
                label: 'Calificación',
                value: s.rating > 0 ? '⭐ ${s.rating.toStringAsFixed(1)}' : '—',
                sub: '${s.reviewCount} reseñas',
                icon: Icons.star_rounded,
                color: AppColors.gold,
              ),
              _MetricCard(
                label: 'Tiempo de respuesta',
                value: s.avgResponseTime == Duration.zero
                    ? '—'
                    : _formatDuration(s.avgResponseTime),
                icon: Icons.timer_rounded,
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
