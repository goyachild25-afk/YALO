import 'package:flutter/material.dart';
import '../../features/providers_list/models/service_provider_model.dart';

// ─── Colors por nivel ─────────────────────────────────────────────────────────
extension ProviderLevelColors on ProviderLevel {
  Color get color => switch (this) {
        ProviderLevel.newLevel  => const Color(0xFF6B7280), // gris
        ProviderLevel.destacado => const Color(0xFF2563EB), // azul
        ProviderLevel.experto   => const Color(0xFF7C3AED), // violeta
        ProviderLevel.elite     => const Color(0xFFD97706), // dorado
      };

  Color get bg => switch (this) {
        ProviderLevel.newLevel  => const Color(0xFFF3F4F6),
        ProviderLevel.destacado => const Color(0xFFEFF6FF),
        ProviderLevel.experto   => const Color(0xFFF5F3FF),
        ProviderLevel.elite     => const Color(0xFFFFFBEB),
      };

  List<Color> get gradient => switch (this) {
        ProviderLevel.newLevel  => [const Color(0xFF6B7280), const Color(0xFF9CA3AF)],
        ProviderLevel.destacado => [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
        ProviderLevel.experto   => [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
        ProviderLevel.elite     => [const Color(0xFFD97706), const Color(0xFFFBBF24)],
      };
}

// ─── Badge compacto (usado en tarjetas y listas) ──────────────────────────────
class LevelBadge extends StatelessWidget {
  final ProviderLevel level;
  final bool large;
  final bool showCommission;

  const LevelBadge(
    this.level, {
    super.key,
    this.large = false,
    this.showCommission = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 7,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: level.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            level.emoji,
            style: TextStyle(fontSize: large ? 14 : 10),
          ),
          SizedBox(width: large ? 5 : 3),
          Text(
            level.label,
            style: TextStyle(
              fontSize: large ? 13 : 10,
              fontWeight: FontWeight.w700,
              color: level.color,
            ),
          ),
          if (showCommission) ...[
            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 10,
              color: level.color.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            Text(
              '${level.commissionLabel} comisión',
              style: TextStyle(
                fontSize: 10,
                color: level.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Barra de progreso al siguiente nivel ─────────────────────────────────────
class LevelProgressCard extends StatelessWidget {
  final ProviderLevel level;
  final int completedJobs;

  const LevelProgressCard({
    super.key,
    required this.level,
    required this.completedJobs,
  });

  @override
  Widget build(BuildContext context) {
    final next = level.next;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: level.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: level.color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────
          Row(
            children: [
              Text(level.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel ${level.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Comisión: ${level.commissionLabel} por servicio',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedJobs trabajos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // ── Progreso al siguiente nivel ────────────────────────
          if (next != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Próximo nivel: ${next.emoji} ${next.label}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${next.minJobs - completedJobs} trabajos más',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progressValue(completedJobs, level, next),
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_progressPercent(completedJobs, level, next)}% hacia ${next.label} · '
              'Comisión bajará a ${next.commissionLabel}',
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  '¡Nivel máximo alcanzado! Comisión preferencial garantizada.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _progressValue(int jobs, ProviderLevel current, ProviderLevel next) {
    final start = current.minJobs;
    final end = next.minJobs;
    if (end <= start) return 1.0;
    return ((jobs - start) / (end - start)).clamp(0.0, 1.0);
  }

  String _progressPercent(
      int jobs, ProviderLevel current, ProviderLevel next) {
    return (_progressValue(jobs, current, next) * 100).toStringAsFixed(0);
  }
}

// ─── Tabla comparativa de niveles ────────────────────────────────────────────
class LevelComparisonSheet extends StatelessWidget {
  final ProviderLevel currentLevel;
  const LevelComparisonSheet({super.key, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Niveles de ServiciosYa',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Más trabajos = menor comisión = más ganancias',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ...ProviderLevel.values.map((lvl) => _LevelRow(
                level: lvl,
                isCurrent: lvl == currentLevel,
              )),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final ProviderLevel level;
  final bool isCurrent;
  const _LevelRow({required this.level, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? level.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? level.color : Colors.grey.shade200,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(level.emoji,
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(level.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: level.color,
                          fontSize: 14,
                        )),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: level.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Tú',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text(
                  level == ProviderLevel.elite
                      ? '${level.minJobs}+ trabajos'
                      : '${level.minJobs}–${level.maxJobs} trabajos',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                level.commissionLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: level.color,
                ),
              ),
              const Text('comisión',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}
