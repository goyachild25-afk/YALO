import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class _ReferralStats {
  final String code;
  final int invitedCount;
  final int completedFirstBooking;
  const _ReferralStats({
    required this.code,
    required this.invitedCount,
    required this.completedFirstBooking,
  });
}

final _referralStatsProvider =
    FutureProvider.autoDispose<_ReferralStats>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) {
    return const _ReferralStats(code: '------', invitedCount: 0, completedFirstBooking: 0);
  }
  final profile = await SupabaseService.client
      .from('profiles')
      .select('referral_code')
      .eq('id', user.id)
      .maybeSingle();
  final code = (profile?['referral_code'] as String?) ?? '------';

  // Cuántas cuentas se registraron con mi código
  final invited = await SupabaseService.client
      .from('profiles')
      .select('id, is_active')
      .eq('referred_by', user.id);
  final invitedList = (invited as List<dynamic>);

  // Cuántos de esos completaron al menos una reserva
  int completed = 0;
  for (final row in invitedList) {
    final id = (row as Map<String, dynamic>)['id'] as String;
    try {
      final bs = await SupabaseService.client
          .from('bookings')
          .select('id')
          .eq('client_id', id)
          .eq('status', 'completed')
          .limit(1);
      if ((bs as List).isNotEmpty) completed++;
    } catch (_) {}
  }

  return _ReferralStats(
    code: code,
    invitedCount: invitedList.length,
    completedFirstBooking: completed,
  );
});

class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  String _shareLink(String code) =>
      'https://goyachild25-afk.github.io/Serviciosya/#/register?ref=$code';

  Future<void> _shareWhatsApp(BuildContext context, String code) async {
    final msg =
        'Te invito a ServiciosYa 🏠 — la app dominicana para servicios del hogar. Usa mi código *$code* al registrarte: ${_shareLink(code)}';
    final uri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: _shareLink(code)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiado al portapapeles')),
      );
    }
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código $code copiado')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_referralStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invita a tus amigos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
            child: Text('No pudimos cargar tus referidos.')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header con gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.warmGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded,
                          color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Comparte y crece juntos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cuando un amigo se registra con tu código y completa su primera reserva, ambos crecen contigo.',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Código
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  const Text('Tu código de invitación',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _copyCode(context, stats.code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stats.code,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded,
                              color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Copiar link'),
                          onPressed: () => _copyLink(context, stats.code),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _shareWhatsApp(context, stats.code),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Invitados',
                    value: stats.invitedCount,
                    icon: Icons.person_add_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Activos',
                    value: stats.completedFirstBooking,
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              )),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
