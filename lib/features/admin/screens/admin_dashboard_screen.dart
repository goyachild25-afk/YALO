import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/csv_download_service.dart';
import '../../../core/services/demo_provider.dart';
import '../providers/admin_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_analytics_tab.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _disputeTypeLabel(String? type) {
  switch (type) {
    case 'serviceNotCompleted': return 'Servicio no completado';
    case 'fraudOrScam':        return 'Fraude o estafa';
    case 'propertyDamage':     return 'Daño a la propiedad';
    case 'inappropriateBehavior': return 'Conducta inapropiada';
    case 'noShow':             return 'No se presentó';
    case 'paymentIssue':       return 'Problema con el pago';
    default:                   return 'Otro motivo';
  }
}

String _bookingStatusLabel(String? s) {
  switch (s) {
    case 'pending':     return 'Pendiente';
    case 'accepted':    return 'Aceptada';
    case 'in_progress': return 'En curso';
    case 'completed':   return 'Completada';
    case 'cancelled':   return 'Cancelada';
    default:            return s ?? '-';
  }
}

Color _bookingStatusColor(String? s) {
  switch (s) {
    case 'pending':     return AppColors.warning;
    case 'accepted':    return AppColors.info;
    case 'in_progress': return AppColors.primary;
    case 'completed':   return AppColors.success;
    case 'cancelled':   return AppColors.error;
    default:            return AppColors.textHint;
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminVerificationsProvider);
    ref.invalidate(adminDisputesProvider);
    ref.invalidate(adminRecentUsersProvider);
    ref.invalidate(adminAllUsersProvider);
    ref.invalidate(adminRecentBookingsProvider);
    ref.invalidate(adminAllBookingsProvider);
    ref.invalidate(adminFinanceDataProvider);
    ref.invalidate(adminServiceCategoriesProvider);
    ref.invalidate(adminAppSettingsProvider);
    ref.invalidate(adminAuditLogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(adminAccessProvider);

    return accessAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _AccessDenied(onBack: () => context.go('/home')),
      data: (hasAccess) {
        if (!hasAccess) return _AccessDenied(onBack: () => context.go('/home'));
        return _AdminBody(tab: _tab, onRefresh: _refreshAll);
      },
    );
  }
}

// ─── Body (shown only when access is granted) ─────────────────────────────────
class _AdminBody extends ConsumerWidget {
  final TabController tab;
  final VoidCallback onRefresh;
  const _AdminBody({required this.tab, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final pendingVerif = statsAsync.valueOrNull?.pendingVerifications ?? 0;
    final openDisputes = statsAsync.valueOrNull?.openDisputes ?? 0;

    // Avisa en el momento si llega una verificación o disputa nueva mientras
    // el admin está en el dashboard — antes solo se enteraba si tocaba
    // "Actualizar datos" o volvía a entrar a esa pestaña.
    ref.listen(newVerificationInsertProvider, (_, next) {
      final row = next.valueOrNull;
      if (row == null) return;
      ref.invalidate(adminVerificationsProvider);
      ref.invalidate(adminStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.fact_check_outlined, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text('Nueva verificación de identidad pendiente')),
        ]),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 4),
      ));
    });
    ref.listen(newDisputeInsertProvider, (_, next) {
      final row = next.valueOrNull;
      if (row == null) return;
      ref.invalidate(adminDisputesProvider);
      ref.invalidate(adminStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.report_problem_outlined, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text('Nueva disputa reportada')),
        ]),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
      ));
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 20),
            SizedBox(width: 8),
            Text('Panel Administrador',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              onRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Actualizando datos…'),
                    ],
                  ),
                  duration: Duration(milliseconds: 1200),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Confirmar antes de cerrar sesión (evita salidas accidentales
              // por tap fantasma en móvil).
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                      '¿Quieres cerrar tu sesión de administrador?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              // signOut real. Sin esto, la sesión de Supabase sigue viva,
              // el router redirect ve authState != null y devuelve el
              // usuario a /admin inmediatamente.
              try {
                await ref
                    .read(authControllerProvider.notifier)
                    .signOut();
              } catch (_) {}
              if (context.mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Resumen'),
            Tab(
              child: Row(
                children: [
                  const Text('Verificaciones'),
                  if (pendingVerif > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(pendingVerif),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Disputas'),
                  if (openDisputes > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(openDisputes),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Usuarios'),
            const Tab(text: 'Reservas'),
            const Tab(text: 'Finanzas'),
            const Tab(text: 'Configuración'),
            const Tab(text: 'Analytics'),
            const Tab(text: 'Auditoría'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tab,
        children: const [
          _SummaryTab(),
          _VerificationsTab(),
          _DisputesTab(),
          _UsersTab(),
          _BookingsTab(),
          _FinanceTab(),
          _SettingsTab(),
          AdminAnalyticsTab(),
          _AuditLogTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — RESUMEN
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString(),
          onRetry: () => ref.invalidate(adminStatsProvider)),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats grid ─────────────────────────────────────────────────
            const _SectionTitle('Vista general'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _StatCard(
                  label: 'Usuarios totales',
                  value: stats.totalUsers.toString(),
                  icon: Icons.people_outline,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Prestadores activos',
                  value: stats.activeProviders.toString(),
                  icon: Icons.work_outline,
                  color: const Color(0xFF7C3AED),
                ),
                _StatCard(
                  label: 'Reservas totales',
                  value: stats.totalBookings.toString(),
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.success,
                ),
                _StatCard(
                  label: 'Reservas pendientes',
                  value: stats.pendingBookings.toString(),
                  icon: Icons.pending_actions_outlined,
                  color: AppColors.info,
                  alert: stats.pendingBookings > 10,
                ),
                _StatCard(
                  label: 'Verif. pendientes',
                  value: stats.pendingVerifications.toString(),
                  icon: Icons.verified_user_outlined,
                  color: AppColors.warning,
                  alert: stats.pendingVerifications > 0,
                ),
                _StatCard(
                  label: 'Disputas abiertas',
                  value: stats.openDisputes.toString(),
                  icon: Icons.gavel_outlined,
                  color: AppColors.error,
                  alert: stats.openDisputes > 0,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Revenue ────────────────────────────────────────────────────
            _RevenueCard(revenue: stats.monthlyRevenue),
            const SizedBox(height: 16),

            // ── Eficiencia operativa ───────────────────────────────────────
            const _SectionTitle('Eficiencia operativa'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RateCard(
                    label: 'Tasa de finalización',
                    rate: stats.completionRate,
                    color: AppColors.success,
                    icon: Icons.task_alt_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RateCard(
                    label: 'Cancelación / rechazo',
                    rate: stats.cancellationRate,
                    color: stats.cancellationRate > 0.2
                        ? AppColors.error
                        : AppColors.warning,
                    icon: Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Acciones rápidas ───────────────────────────────────────────
            const _SectionTitle('Acciones rápidas'),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.verified_user_outlined,
              label: 'Verificaciones pendientes',
              badge: stats.pendingVerifications > 0
                  ? stats.pendingVerifications.toString()
                  : null,
              color: AppColors.warning,
              onTap: () {},
            ),
            _QuickActionTile(
              icon: Icons.gavel_outlined,
              label: 'Disputas abiertas',
              badge: stats.openDisputes > 0
                  ? stats.openDisputes.toString()
                  : null,
              color: AppColors.error,
              onTap: () {},
            ),
            _QuickActionTile(
              icon: Icons.people_outline,
              label: 'Usuarios recientes',
              color: AppColors.primary,
              onTap: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — VERIFICACIONES
// ═════════════════════════════════════════════════════════════════════════════
class _VerificationsTab extends ConsumerStatefulWidget {
  const _VerificationsTab();

  @override
  ConsumerState<_VerificationsTab> createState() => _VerificationsTabState();
}

class _VerificationsTabState extends ConsumerState<_VerificationsTab> {
  // Track locally processed IDs to give instant feedback
  final Set<String> _processed = {};
  bool _acting = false;

  Future<void> _approve(Map<String, dynamic> req) async {
    if (_acting) return;
    final id = req['id'] as String;
    final userId = req['user_id'] as String;

    setState(() { _acting = true; _processed.add(id); });

    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        await SupabaseService.client
            .from('verification_requests')
            .update({'status': 'approved'}).eq('id', id);
        await SupabaseService.client
            .from('profiles')
            .update({'is_verified': true}).eq('id', userId);
        try {
          await SupabaseService.client
              .from('provider_profiles')
              .update({'is_verified': true}).eq('user_id', userId);
        } catch (_) {}
        ref.invalidate(adminVerificationsProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Prestador aprobado y verificado'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      setState(() => _processed.remove(id));
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final note = await _showNoteDialog(
      context: context,
      title: 'Rechazar verificación',
      hint: 'Motivo del rechazo (se enviará al prestador)...',
      confirmLabel: 'Rechazar',
      confirmColor: AppColors.error,
    );
    if (note == null) return;

    final id = req['id'] as String;
    setState(() { _acting = true; _processed.add(id); });

    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        await SupabaseService.client
            .from('verification_requests')
            .update({'status': 'rejected', 'rejection_note': note}).eq('id', id);
        ref.invalidate(adminVerificationsProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Solicitud rechazada'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      setState(() => _processed.remove(id));
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showError(String e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminVerificationsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString(),
          onRetry: () => ref.invalidate(adminVerificationsProvider)),
      data: (list) {
        final visible = list
            .where((r) => !_processed.contains(r['id']))
            .toList();

        if (visible.isEmpty) {
          return const _EmptyState(
            icon: Icons.verified_outlined,
            title: 'Sin verificaciones pendientes',
            subtitle: 'Todos los prestadores han sido revisados.',
            color: AppColors.success,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _VerificationCard(
            req: visible[i],
            onApprove: () => _approve(visible[i]),
            onReject: () => _reject(visible[i]),
          ),
        );
      },
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _VerificationCard({required this.req, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final profile = (req['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final fullName = profile['full_name'] as String? ?? req['full_name'] as String? ?? 'Sin nombre';
    final province = profile['province'] as String? ?? '';
    final city = profile['city'] as String? ?? '';
    final email = profile['email'] as String? ?? '';
    final cedula = req['id_number'] as String? ?? '—';
    final submittedAt = DateTime.tryParse((req['submitted_at'] as String?) ?? '');

    final frontUrl = req['id_front_url'] as String?;
    final backUrl = req['id_back_url'] as String?;
    final selfieUrl = req['selfie_url'] as String?;
    final hasLocalPhotos = frontUrl != null || backUrl != null || selfieUrl != null;
    final diditStatus = req['didit_status'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLighter,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('$city${province.isNotEmpty ? ', $province' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (email.isNotEmpty)
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Pendiente',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Cédula + fecha
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Cédula: $cedula',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (submittedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(submittedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Resultado de la verificación automática (Didit): apoyo para la
          // revisión, nunca reemplaza el criterio del admin — los botones
          // de Aprobar/Rechazar siguen siendo la decisión final humana.
          if (diditStatus != null) ...[
            _DiditResultBadge(status: diditStatus),
            const SizedBox(height: 12),
          ],

          // Document photos (solicitudes antiguas subidas manualmente;
          // las nuevas se capturan en la sesión hospedada de Didit y no
          // dejan copia local — el resultado de arriba es la evidencia).
          if (hasLocalPhotos) ...[
            Row(
              children: [
                _DocPhoto(url: frontUrl, label: 'Frente'),
                const SizedBox(width: 8),
                _DocPhoto(url: backUrl, label: 'Reverso'),
                const SizedBox(width: 8),
                _DocPhoto(url: selfieUrl, label: 'Selfie'),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (diditStatus == null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Esperando a que el prestador complete la verificación.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rechazar'),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aprobar'),
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Resultado de la verificación automática de Didit (OCR + liveness + face
/// match). Es información de apoyo para el admin, no una aprobación —
/// aunque diga "Aprobado", el admin sigue confirmando con sus propios
/// botones antes de que el prestador quede verificado en la plataforma.
class _DiditResultBadge extends StatelessWidget {
  final String status;
  const _DiditResultBadge({required this.status});

  ({String label, Color color, IconData icon}) _resolve(String s) {
    switch (s) {
      case 'Approved':
        return (label: 'Didit: documento e identidad verificados', color: AppColors.success, icon: Icons.verified_outlined);
      case 'Declined':
        return (label: 'Didit: verificación rechazada', color: AppColors.error, icon: Icons.error_outline);
      case 'In Review':
        return (label: 'Didit: en revisión manual de ellos', color: AppColors.warning, icon: Icons.hourglass_top_outlined);
      case 'Expired':
      case 'KYC Expired':
        return (label: 'Didit: la sesión expiró sin completarse', color: AppColors.textHint, icon: Icons.timer_off_outlined);
      case 'Abandoned':
        return (label: 'Didit: el prestador abandonó la sesión', color: AppColors.textHint, icon: Icons.cancel_outlined);
      case 'In Progress':
        return (label: 'Didit: verificación en curso', color: AppColors.info, icon: Icons.autorenew);
      default: // NOT_STARTED u otros
        return (label: 'Didit: aún no inicia la verificación', color: AppColors.textHint, icon: Icons.schedule_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolve(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: r.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: r.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(r.icon, size: 16, color: r.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.color)),
          ),
        ],
      ),
    );
  }
}

class _DocPhoto extends StatefulWidget {
  final String? url;
  final String label;
  const _DocPhoto({required this.url, required this.label});

  @override
  State<_DocPhoto> createState() => _DocPhotoState();
}

class _DocPhotoState extends State<_DocPhoto> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  /// El bucket 'verification-docs' es PRIVADO (contiene cédulas), pero el
  /// flujo de verificación guardó URLs "públicas" que devuelven 400 en un
  /// bucket privado — por eso el panel mostraba placeholders grises en vez
  /// de los documentos. Extraemos el path del objeto y generamos una URL
  /// firmada de 1 hora (la política verdocs_admin_read nos da acceso).
  Future<void> _resolve() async {
    final raw = widget.url;
    if (raw == null || raw.isEmpty) return;
    const marker = '/verification-docs/';
    final idx = raw.indexOf(marker);
    if (idx == -1) {
      // URL de otro bucket (público) → usarla tal cual
      if (mounted) setState(() => _signedUrl = raw);
      return;
    }
    try {
      final path = Uri.decodeComponent(
          raw.substring(idx + marker.length).split('?').first);
      final signed = await SupabaseService.client.storage
          .from('verification-docs')
          .createSignedUrl(path, 3600);
      if (mounted) setState(() => _signedUrl = signed);
    } catch (_) {
      // Sin permiso o el objeto no existe → queda el placeholder
    }
  }

  void _openFullScreen() {
    if (_signedUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(imageUrl: _signedUrl!),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: _openFullScreen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _signedUrl != null
                  ? CachedNetworkImage(
                      imageUrl: _signedUrl!,
                      height: 70,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined,
              color: AppColors.textHint, size: 28),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — DISPUTAS
// ═════════════════════════════════════════════════════════════════════════════
class _DisputesTab extends ConsumerStatefulWidget {
  const _DisputesTab();

  @override
  ConsumerState<_DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends ConsumerState<_DisputesTab> {
  final Map<String, String> _localStatus = {}; // id → new status (optimistic)

  Future<void> _markInReview(String id) async {
    setState(() => _localStatus[id] = 'inReview');
    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        await SupabaseService.client
            .from('disputes')
            .update({'status': 'inReview'}).eq('id', id);
        ref.invalidate(adminDisputesProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Disputa marcada en revisión'),
          backgroundColor: AppColors.info,
        ));
      }
    } catch (e) {
      setState(() => _localStatus.remove(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _resolve(Map<String, dynamic> dispute) async {
    final resolution = await _showNoteDialog(
      context: context,
      title: 'Resolver disputa',
      hint: 'Describe la resolución adoptada...',
      confirmLabel: 'Resolver',
      confirmColor: AppColors.success,
    );
    if (resolution == null) return;

    final id = dispute['id'] as String;
    setState(() => _localStatus[id] = 'resolved');

    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        await SupabaseService.client.from('disputes').update({
          'status': 'resolved',
          'resolution': resolution,
          'resolved_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
        ref.invalidate(adminDisputesProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Disputa resuelta'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      setState(() => _localStatus.remove(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminDisputesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminDisputesProvider)),
      data: (disputes) {
        // Apply optimistic local status updates; hide resolved ones
        final visible = disputes
            .where((d) => _localStatus[d['id']] != 'resolved')
            .toList();

        if (visible.isEmpty) {
          return const _EmptyState(
            icon: Icons.gavel_outlined,
            title: 'Sin disputas abiertas',
            subtitle: 'No hay disputas pendientes de gestión.',
            color: AppColors.success,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = visible[i];
            final effectiveStatus = _localStatus[d['id']] ?? d['status'] as String? ?? 'open';
            return _DisputeCard(
              dispute: d,
              effectiveStatus: effectiveStatus,
              onMarkInReview: effectiveStatus == 'open'
                  ? () => _markInReview(d['id'] as String)
                  : null,
              onResolve: () => _resolve(d),
            );
          },
        );
      },
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final String effectiveStatus;
  final VoidCallback? onMarkInReview;
  final VoidCallback onResolve;

  const _DisputeCard({
    required this.dispute,
    required this.effectiveStatus,
    this.onMarkInReview,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final reporter = (dispute['reporter'] as Map?)?.cast<String, dynamic>();
    final reported = (dispute['reported'] as Map?)?.cast<String, dynamic>();
    final reporterName = reporter?['full_name'] as String? ?? 'Desconocido';
    final reportedName = reported?['full_name'] as String? ?? 'Desconocido';
    final type = dispute['type'] as String?;
    final description = dispute['description'] as String? ?? '';
    final adminNotes = dispute['admin_notes'] as String?;
    final createdAt = DateTime.tryParse((dispute['created_at'] as String?) ?? '');

    final isInReview = effectiveStatus == 'inReview';
    final statusColor = isInReview ? AppColors.info : AppColors.error;
    final statusLabel = isInReview ? 'En revisión' : 'Abierta';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + status badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_disputeTypeLabel(type),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Parties
          Row(
            children: [
              _PartyChip(
                  label: 'Reportó', name: reporterName, color: AppColors.info,
                  onContact: () => contactUser(
                      context: context,
                      name: reporterName,
                      phone: reporter?['phone'] as String?,
                      email: reporter?['email'] as String?)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 8),
              _PartyChip(
                  label: 'Reportado',
                  name: reportedName,
                  color: AppColors.error,
                  onContact: () => contactUser(
                      context: context,
                      name: reportedName,
                      phone: reported?['phone'] as String?,
                      email: reported?['email'] as String?)),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(description,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4)),

          // Admin notes (if any)
          if (adminNotes != null && adminNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(adminNotes,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.info, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],

          if (createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Reportada el ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              if (onMarkInReview != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('En revisión', style: TextStyle(fontSize: 13)),
                    onPressed: onMarkInReview,
                  ),
                ),
              if (onMarkInReview != null) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Resolver', style: TextStyle(fontSize: 13)),
                  onPressed: onResolve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyChip extends StatelessWidget {
  final String label;
  final String name;
  final Color color;
  final VoidCallback? onContact;
  const _PartyChip(
      {required this.label, required this.name, required this.color, this.onContact});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onContact != null)
              InkWell(
                onTap: onContact,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chat_outlined, size: 16, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — USUARIOS
// ═════════════════════════════════════════════════════════════════════════════
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final Set<String> _busy = {};
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _roleFilter = 'all'; // all | client | provider | admin

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final nameCtrl = TextEditingController(text: user['full_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] as String? ?? '');
    final provinceCtrl = TextEditingController(text: user['province'] as String? ?? '');
    final cityCtrl = TextEditingController(text: user['city'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar perfil',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono')),
              const SizedBox(height: 10),
              TextField(controller: provinceCtrl,
                  decoration: const InputDecoration(labelText: 'Provincia')),
              const SizedBox(height: 10),
              TextField(controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Ciudad')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (saved != true) return;
    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        final updates = {
          'full_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'province': provinceCtrl.text.trim(),
          'city': cityCtrl.text.trim(),
        };
        await SupabaseService.client.from('profiles').update(updates).eq('id', id);
        await logAdminAction(
            action: 'Editó perfil de usuario',
            targetTable: 'profiles', targetId: id, details: updates);
        ref.invalidate(adminAllUsersProvider);
        ref.invalidate(adminRecentUsersProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Perfil actualizado'), backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _showDetail(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user['full_name'] as String? ?? 'Usuario',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Email: ${user['email'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                Text('Teléfono: ${user['phone'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                Text('Rol: ${user['role'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                Text('Ubicación: ${user['city'] ?? '-'}, ${user['province'] ?? '-'}',
                    style: const TextStyle(fontSize: 12)),
                Text('ID: $id',
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                const SizedBox(height: 12),
                const Text('Últimas reservas',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Consumer(builder: (_, ref, __) {
                  final async = ref.watch(adminUserBookingsProvider(id));
                  return async.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Text('No se pudieron cargar las reservas.',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    data: (bookings) {
                      if (bookings.isEmpty) {
                        return const Text('Sin reservas registradas.',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint));
                      }
                      return Column(
                        children: bookings.take(8).map((b) {
                          final status = b['status'] as String?;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(b['service_name'] as String? ?? '-',
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Text(_bookingStatusLabel(status),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _bookingStatusColor(status))),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final isActive = user['is_active'] as bool? ?? true;
    final name = user['full_name'] as String? ?? 'este usuario';

    String? reason;
    if (isActive) {
      // Suspender: el motivo es obligatorio — el usuario lo verá al
      // intentar entrar, y queda en el audit log.
      reason = await _showNoteDialog(
        context: context,
        title: 'Suspender a $name',
        hint: 'Motivo de la suspensión (lo verá el usuario)...',
        confirmLabel: 'Suspender',
        confirmColor: AppColors.error,
      );
      if (reason == null) return;
    } else {
      final confirmed = await _showConfirmDialog(
        context: context,
        title: 'Reactivar usuario',
        message: '¿Reactivar a $name? Podrá volver a iniciar sesión y usar la app.',
        confirmLabel: 'Reactivar',
        confirmColor: AppColors.success,
      );
      if (!confirmed) return;
    }

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client.from('profiles').update({
          'is_active': !isActive,
          'suspension_reason': isActive ? reason : null,
        }).eq('id', id);
        await logAdminAction(
            action: isActive ? 'Suspendió usuario' : 'Reactivó usuario',
            targetTable: 'profiles', targetId: id,
            details: isActive ? {'name': name, 'reason': reason} : {'name': name});
        ref.invalidate(adminRecentUsersProvider);
        ref.invalidate(adminAllUsersProvider);

        // Revoca (o restaura) la posibilidad de renovar la sesión a nivel
        // de Supabase Auth — is_active por sí solo no bloquea nada del lado
        // del servidor. Si esto falla, el usuario igual queda bloqueado por
        // la app (login + router ya verifican is_active), pero avisamos.
        var hardBlockFailed = false;
        try {
          final resp = await SupabaseService.client.functions.invoke(
            'suspend-user',
            body: {'user_id': id, 'banned': isActive},
          );
          if (resp.status != 200) hardBlockFailed = true;
        } catch (_) {
          hardBlockFailed = true;
        }
        if (mounted && hardBlockFailed) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Perfil actualizado, pero no se pudo revocar la sesión a nivel de servidor. Reintenta si es urgente.'),
            backgroundColor: AppColors.warning,
          ));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isActive ? '🚫 Usuario suspendido' : '✅ Usuario reactivado'),
          backgroundColor: isActive ? AppColors.error : AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final role = user['role'] as String? ?? 'client';
    final isAdmin = role == 'admin';
    final name = user['full_name'] as String? ?? 'este usuario';
    final confirmed = await _showConfirmDialog(
      context: context,
      title: isAdmin ? 'Quitar admin' : 'Hacer admin',
      message: isAdmin
          ? '¿Quitar el rol de administrador a $name? Quedará como cliente.'
          : '¿Dar acceso de administrador a $name? Podrá ver y gestionar todo el panel admin.',
      confirmLabel: isAdmin ? 'Quitar admin' : 'Hacer admin',
      confirmColor: isAdmin ? AppColors.warning : AppColors.primary,
    );
    if (!confirmed) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client
            .from('profiles')
            .update({'role': isAdmin ? 'client' : 'admin'}).eq('id', id);
        await logAdminAction(
            action: isAdmin ? 'Quitó rol admin' : 'Otorgó rol admin',
            targetTable: 'profiles', targetId: id, details: {'name': name});
        ref.invalidate(adminRecentUsersProvider);
        ref.invalidate(adminAllUsersProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAdmin ? 'Rol de admin removido' : '✅ Ahora es administrador'),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminAllUsersProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminAllUsersProvider)),
      data: (allUsers) {
        final users = allUsers.where((u) {
          if (_roleFilter != 'all' && (u['role'] as String? ?? 'client') != _roleFilter) {
            return false;
          }
          if (_query.isEmpty) return true;
          final name = (u['full_name'] as String? ?? '').toLowerCase();
          final email = (u['email'] as String? ?? '').toLowerCase();
          return name.contains(_query) || email.contains(_query);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o email...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final f in const [
                    ['all', 'Todos'], ['client', 'Clientes'],
                    ['provider', 'Prestadores'], ['admin', 'Admins'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f[1], style: const TextStyle(fontSize: 11)),
                        selected: _roleFilter == f[0],
                        onSelected: (_) => setState(() => _roleFilter = f[0]),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    '${users.length} de ${allUsers.length} usuarios',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (users.isEmpty)
              const Expanded(
                child: _EmptyState(
                  icon: Icons.people_outline,
                  title: 'Sin resultados',
                  subtitle: 'Ningún usuario coincide con la búsqueda/filtro.',
                  color: AppColors.primary,
                ),
              )
            else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = users[i];
                  final role = u['role'] as String? ?? 'client';
                  final isProvider = role == 'provider';
                  final isAdmin = role == 'admin';
                  final isVerified = u['is_verified'] as bool? ?? false;
                  final isActive = u['is_active'] as bool? ?? true;
                  final name = u['full_name'] as String? ?? '—';
                  final email = u['email'] as String? ?? '';
                  final city = u['city'] as String? ?? '';
                  final province = u['province'] as String? ?? '';
                  final createdAt = DateTime.tryParse(
                      (u['created_at'] as String?) ?? '');

                  Color roleColor = isAdmin
                      ? AppColors.error
                      : isProvider
                          ? const Color(0xFF7C3AED)
                          : AppColors.primary;
                  String roleLabel = isAdmin
                      ? 'Admin'
                      : isProvider
                          ? 'Prestador'
                          : 'Cliente';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: roleColor),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        if (isVerified)
                          const Icon(Icons.verified,
                              color: AppColors.success, size: 14),
                        if (!isActive)
                          const Icon(Icons.block,
                              color: AppColors.error, size: 14),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                        if (city.isNotEmpty)
                          Text('$city${province.isNotEmpty ? ', $province' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                    trailing: _busy.contains(u['id'])
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(roleLabel,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: roleColor,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  if (createdAt != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd/MM/yy').format(createdAt),
                                      style: const TextStyle(
                                          fontSize: 10, color: AppColors.textHint),
                                    ),
                                  ],
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 18, color: AppColors.textHint),
                                onSelected: (action) {
                                  if (action == 'detail') _showDetail(u);
                                  if (action == 'edit') _editProfile(u);
                                  if (action == 'active') _toggleActive(u);
                                  if (action == 'admin') _toggleAdmin(u);
                                  if (action == 'contact') {
                                    contactUser(
                                      context: context,
                                      name: name,
                                      phone: u['phone'] as String?,
                                      email: email,
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'detail',
                                    child: Text('Ver detalle'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'contact',
                                    child: Text('Contactar'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar perfil'),
                                  ),
                                  PopupMenuItem(
                                    value: 'active',
                                    child: Text(isActive ? 'Suspender' : 'Reactivar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'admin',
                                    child: Text(isAdmin ? 'Quitar admin' : 'Hacer admin'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                    isThreeLine: city.isNotEmpty,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 5 — RESERVAS
// ═════════════════════════════════════════════════════════════════════════════
class _BookingsTab extends ConsumerStatefulWidget {
  const _BookingsTab();

  @override
  ConsumerState<_BookingsTab> createState() => _BookingsTabState();
}

const _bookingStatuses = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled'];

class _BookingsTabState extends ConsumerState<_BookingsTab> {
  final Set<String> _busy = {};
  String _statusFilter = 'all';

  Future<void> _forceStatus(Map<String, dynamic> b) async {
    final id = b['id'] as String;
    String selected = b['status'] as String? ?? 'pending';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Cambiar estado de la reserva',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bookingStatuses.map((s) => RadioListTile<String>(
              dense: true,
              title: Text(_bookingStatusLabel(s)),
              value: s,
              groupValue: selected,
              onChanged: (v) => setLocal(() => selected = v!),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client.from('bookings').update({'status': selected}).eq('id', id);
        await logAdminAction(
            action: 'Forzó estado de reserva a "$selected"',
            targetTable: 'bookings', targetId: id);
        ref.invalidate(adminAllBookingsProvider);
        ref.invalidate(adminRecentBookingsProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Estado actualizado'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> b) async {
    final id = b['id'] as String;
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'Cancelar reserva',
      message: '¿Cancelar esta reserva? Esta acción notificará el cambio de estado.',
      confirmLabel: 'Cancelar reserva',
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client.from('bookings').update({'status': 'cancelled'}).eq('id', id);
        await logAdminAction(action: 'Canceló reserva', targetTable: 'bookings', targetId: id);
        ref.invalidate(adminAllBookingsProvider);
        ref.invalidate(adminRecentBookingsProvider);
        ref.invalidate(adminStatsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🚫 Reserva cancelada'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _refund(Map<String, dynamic> b) async {
    final id = b['id'] as String;
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'Marcar como reembolsada',
      message: '¿Marcar el pago de esta reserva como reembolsado? Esto solo actualiza el registro; el reembolso real en la pasarela de pago debe procesarse por separado.',
      confirmLabel: 'Marcar reembolsada',
      confirmColor: AppColors.warning,
    );
    if (!confirmed) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client
            .from('bookings').update({'payment_status': 'refunded'}).eq('id', id);
        await logAdminAction(action: 'Marcó reserva como reembolsada', targetTable: 'bookings', targetId: id);
        ref.invalidate(adminAllBookingsProvider);
        ref.invalidate(adminRecentBookingsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💸 Marcada como reembolsada'), backgroundColor: AppColors.warning));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reassign(Map<String, dynamic> b) async {
    final id = b['id'] as String;
    final providersAsync = ref.read(adminActiveProvidersProvider);
    final providers = providersAsync.valueOrNull ?? [];
    if (providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay prestadores disponibles para reasignar.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    String? selectedId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Reasignar prestador',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            items: providers
                .map((p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['full_name'] as String? ?? '-')))
                .toList(),
            onChanged: (v) => setLocal(() => selectedId = v),
            decoration: const InputDecoration(labelText: 'Nuevo prestador'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: selectedId == null ? null : () => Navigator.of(ctx).pop(true),
                child: const Text('Reasignar')),
          ],
        ),
      ),
    );
    if (confirmed != true || selectedId == null) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client
            .from('bookings').update({'provider_id': selectedId}).eq('id', id);
        await logAdminAction(
            action: 'Reasignó prestador de reserva',
            targetTable: 'bookings', targetId: id, details: {'new_provider_id': selectedId});
        ref.invalidate(adminAllBookingsProvider);
        ref.invalidate(adminRecentBookingsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Prestador reasignado'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showDetail(Map<String, dynamic> b) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalle de la reserva',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Servicio: ${b['service_name'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              Text('Estado: ${_bookingStatusLabel(b['status'] as String?)}', style: const TextStyle(fontSize: 12)),
              Text('Pago: ${b['payment_status'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              Text('Precio acordado: RD\$${b['agreed_price'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              Text('Dirección: ${b['address'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              Text('Notas: ${b['notes'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text('ID: ${b['id']}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminActiveProvidersProvider); // precarga para el diálogo de reasignar
    final async = ref.watch(adminAllBookingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminAllBookingsProvider)),
      data: (allBookings) {
        final bookings = _statusFilter == 'all'
            ? allBookings
            : allBookings.where((b) => b['status'] == _statusFilter).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in ['all', ..._bookingStatuses])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == 'all' ? 'Todas' : _bookingStatusLabel(f),
                              style: const TextStyle(fontSize: 11)),
                          selected: _statusFilter == f,
                          onSelected: (_) => setState(() => _statusFilter = f),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    '${bookings.length} de ${allBookings.length} reservas',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (bookings.isEmpty)
              const Expanded(
                child: _EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'Sin reservas',
                  subtitle: 'No hay reservas para este filtro.',
                  color: AppColors.primary,
                ),
              )
            else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final b = bookings[i];
                  final client = (b['client'] as Map?)?.cast<String, dynamic>();
                  final provider = (b['provider'] as Map?)?.cast<String, dynamic>();
                  final clientName = client?['full_name'] as String? ??
                      b['client_id'] as String? ?? '—';
                  final providerName = provider?['full_name'] as String? ??
                      b['provider_id'] as String? ?? '—';
                  final status = b['status'] as String?;
                  final amount = (b['agreed_price'] as num?)?.toDouble();
                  final serviceName = b['service_name'] as String? ?? '—';
                  final createdAt = DateTime.tryParse(
                      (b['created_at'] as String?) ?? '');
                  final isBusy = _busy.contains(b['id']);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                serviceName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _bookingStatusColor(status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _bookingStatusLabel(status),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _bookingStatusColor(status)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            isBusy
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        size: 18, color: AppColors.textHint),
                                    onSelected: (action) {
                                      if (action == 'detail') _showDetail(b);
                                      if (action == 'status') _forceStatus(b);
                                      if (action == 'refund') _refund(b);
                                      if (action == 'reassign') _reassign(b);
                                      if (action == 'cancel') _cancelBooking(b);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'detail', child: Text('Ver detalle')),
                                      PopupMenuItem(value: 'status', child: Text('Cambiar estado')),
                                      PopupMenuItem(value: 'reassign', child: Text('Reasignar prestador')),
                                      PopupMenuItem(value: 'refund', child: Text('Marcar reembolsada')),
                                      PopupMenuItem(value: 'cancel', child: Text('Cancelar reserva')),
                                    ],
                                  ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 12, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Cliente: $clientName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.work_outline,
                                size: 12, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Prestador: $providerName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                            if (amount != null)
                              Text(
                                'RD\$${NumberFormat('#,###').format(amount.toInt())}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success),
                              ),
                          ],
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textHint),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 6 — FINANZAS
// ═════════════════════════════════════════════════════════════════════════════
class _FinanceTab extends ConsumerWidget {
  const _FinanceTab();

  String _buildCsv(AdminFinanceData finance) {
    const f = CsvDownloadService.field;
    final buffer = StringBuffer();
    buffer.writeln(f('YALO — Reporte financiero'));
    buffer.writeln('${f('Generado')},${f(DateTime.now().toIso8601String())}');
    buffer.writeln();

    buffer.writeln(f('Tendencia de ingresos (últimas 8 semanas)'));
    buffer.writeln('${f('Semana')},${f('Ingresos (RD\$)')}');
    for (final w in finance.weeklyTrend) {
      buffer.writeln(
          '${f(DateFormat('dd/MM/yyyy').format(w.weekStart))},${f(w.total.toStringAsFixed(2))}');
    }
    buffer.writeln();

    buffer.writeln(f('Ingresos por servicio (últimos 90 días)'));
    buffer.writeln('${f('Servicio')},${f('Reservas')},${f('Ingresos (RD\$)')}');
    for (final s in finance.byService) {
      buffer.writeln('${f(s.name)},${f(s.count)},${f(s.total.toStringAsFixed(2))}');
    }
    buffer.writeln();

    buffer.writeln(f('Top prestadores por ingresos'));
    buffer.writeln('${f('Prestador')},${f('Trabajos')},${f('Ingresos (RD\$)')}');
    for (final p in finance.topProviders) {
      buffer.writeln('${f(p.name)},${f(p.jobs)},${f(p.total.toStringAsFixed(2))}');
    }
    return buffer.toString();
  }

  void _exportCsv(BuildContext context, AdminFinanceData finance) {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    CsvDownloadService.download('yalo-finanzas-$stamp.csv', _buildCsv(finance));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ CSV descargado'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminFinanceDataProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminFinanceDataProvider)),
      data: (finance) {
        final noFinanceData = finance.weeklyTrend.isEmpty && finance.byService.isEmpty;

        final maxWeekly = finance.weeklyTrend.isEmpty
            ? 0.0
            : finance.weeklyTrend.map((w) => w.total).reduce((a, b) => a > b ? a : b);
        final maxService = finance.byService.isEmpty
            ? 0.0
            : finance.byService.map((s) => s.total).reduce((a, b) => a > b ? a : b);
        final maxProvider = finance.topProviders.isEmpty
            ? 0.0
            : finance.topProviders.map((p) => p.total).reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: noFinanceData ? null : () => _exportCsv(context, finance),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Exportar CSV'),
                ),
              ),
              const SizedBox(height: 16),
              if (noFinanceData) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aún no hay reservas completadas en los últimos 90 días.',
                          style: TextStyle(fontSize: 12, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const _SectionTitle('Tendencia de ingresos (últimas 8 semanas)'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: finance.weeklyTrend
                      .map((w) => _BarRow(
                            label: DateFormat('dd/MM').format(w.weekStart),
                            value: w.total,
                            maxValue: maxWeekly,
                            color: AppColors.primary,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              const _SectionTitle('Ingresos por servicio (últimos 90 días)'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: finance.byService
                      .map((s) => _BarRow(
                            label: '${s.name} (${s.count})',
                            value: s.total,
                            maxValue: maxService,
                            color: const Color(0xFF7C3AED),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              const _SectionTitle('Top 5 prestadores por ingresos'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: finance.topProviders
                      .map((p) => _BarRow(
                            label: '${p.name} (${p.jobs} trabajos)',
                            value: p.total,
                            maxValue: maxProvider,
                            color: AppColors.success,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              const _SectionTitle('Categorías de servicio'),
              const SizedBox(height: 12),
              const _CategoriesSection(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

/// Lista de categorías de servicio con toggle de activo/inactivo.
class _CategoriesSection extends ConsumerStatefulWidget {
  const _CategoriesSection();

  @override
  ConsumerState<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends ConsumerState<_CategoriesSection> {
  final Set<String> _busy = {};

  Future<void> _toggle(Map<String, dynamic> cat) async {
    final id = cat['id'] as String;
    final isActive = cat['is_active'] as bool? ?? true;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client
            .from('service_categories')
            .update({'is_active': !isActive}).eq('id', id);
        await logAdminAction(
            action: isActive ? 'Desactivó categoría' : 'Activó categoría',
            targetTable: 'service_categories', targetId: id);
        ref.invalidate(adminServiceCategoriesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _createOrEdit({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final idCtrl = TextEditingController(text: existing?['id'] as String? ?? '');
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final emojiCtrl = TextEditingController(text: existing?['emoji'] as String? ?? '🔧');
    final orderCtrl = TextEditingController(
        text: (existing?['sort_order'] as int?)?.toString() ?? '0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Editar categoría' : 'Nueva categoría',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEdit)
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                      labelText: 'ID (slug, ej: pet_care)', hintText: 'sin espacios, minúsculas'),
                ),
              if (!isEdit) const SizedBox(height: 10),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: emojiCtrl,
                  decoration: const InputDecoration(labelText: 'Emoji')),
              const SizedBox(height: 10),
              TextField(controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden (sort_order)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != true) return;
    if (nameCtrl.text.trim().isEmpty || (!isEdit && idCtrl.text.trim().isEmpty)) return;

    final id = isEdit ? existing['id'] as String : idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        final data = {
          'name': nameCtrl.text.trim(),
          'emoji': emojiCtrl.text.trim(),
          'sort_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
        };
        if (isEdit) {
          await SupabaseService.client.from('service_categories').update(data).eq('id', id);
          await logAdminAction(action: 'Editó categoría', targetTable: 'service_categories', targetId: id, details: data);
        } else {
          await SupabaseService.client.from('service_categories').insert({...data, 'id': id, 'is_active': true});
          await logAdminAction(action: 'Creó categoría', targetTable: 'service_categories', targetId: id, details: data);
        }
        ref.invalidate(adminServiceCategoriesProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? '✅ Categoría actualizada' : '✅ Categoría creada'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> cat) async {
    final id = cat['id'] as String;
    final name = cat['name'] as String? ?? id;
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'Eliminar categoría',
      message: '¿Eliminar "$name"? Si hay servicios de prestadores usando esta categoría, la eliminación fallará — desactívala en su lugar.',
      confirmLabel: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;

    setState(() => _busy.add(id));
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client.from('service_categories').delete().eq('id', id);
        await logAdminAction(action: 'Eliminó categoría', targetTable: 'service_categories', targetId: id, details: {'name': name});
        ref.invalidate(adminServiceCategoriesProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🗑️ Categoría eliminada'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo eliminar (puede estar en uso): $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminServiceCategoriesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminServiceCategoriesProvider)),
      data: (categories) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _createOrEdit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva categoría'),
            ),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin categorías configuradas.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: categories.map((cat) {
                    final id = cat['id'] as String;
                    final isActive = cat['is_active'] as bool? ?? true;
                    final name = cat['name'] as String? ?? id;
                    final emoji = cat['emoji'] as String? ?? '🔧';
                    return ListTile(
                      dense: true,
                      title: Text('$emoji  $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(isActive ? 'Visible para clientes' : 'Oculta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      trailing: _busy.contains(id)
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isActive,
                                  onChanged: (_) => _toggle(cat),
                                  activeColor: AppColors.success,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _createOrEdit(existing: cat),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () => _delete(cat),
                                ),
                              ],
                            ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 7 — CONFIGURACIÓN
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  bool _saving = false;
  final TextEditingController _clientFeeCtrl = TextEditingController();
  final TextEditingController _providerFeeCtrl = TextEditingController();

  Future<void> _saveFees() async {
    final clientPct = double.tryParse(_clientFeeCtrl.text.trim());
    final providerPct = double.tryParse(_providerFeeCtrl.text.trim());
    if (clientPct == null || clientPct < 0 || clientPct > 100 ||
        providerPct == null || providerPct < 0 || providerPct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa porcentajes válidos entre 0 y 100.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      if (!ref.read(demoModeProvider)) {
        final now = DateTime.now().toIso8601String();
        await SupabaseService.client.from('app_settings').upsert([
          {'key': 'client_fee_rate', 'value': clientPct / 100, 'updated_at': now},
          {'key': 'provider_fee_rate', 'value': providerPct / 100, 'updated_at': now},
        ], onConflict: 'key');
        await logAdminAction(
            action: 'Actualizó comisión de la plataforma',
            targetTable: 'app_settings', targetId: 'client_fee_rate,provider_fee_rate',
            details: {'client_fee_rate': clientPct / 100, 'provider_fee_rate': providerPct / 100});
        ref.invalidate(adminAppSettingsProvider);
        PaymentService.clientFeeRate = clientPct / 100;
        PaymentService.providerFeeRate = providerPct / 100;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Comisión actualizada'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleMaintenance(bool current) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: current ? 'Desactivar modo mantenimiento' : 'Activar modo mantenimiento',
      message: current
          ? '¿Quitar el modo mantenimiento? La app volverá a estar disponible para todos.'
          : '¿Activar modo mantenimiento? Esto bloqueará el acceso a usuarios normales (clientes y prestadores) hasta que lo desactives. Los administradores seguirán teniendo acceso.',
      confirmLabel: current ? 'Desactivar' : 'Activar mantenimiento',
      confirmColor: current ? AppColors.success : AppColors.error,
    );
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      if (!ref.read(demoModeProvider)) {
        await SupabaseService.client.from('app_settings').update({
          'value': !current,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('key', 'maintenance_mode');
        await logAdminAction(
            action: !current ? 'Activó modo mantenimiento' : 'Desactivó modo mantenimiento',
            targetTable: 'app_settings', targetId: 'maintenance_mode');
        ref.invalidate(adminAppSettingsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _clientFeeCtrl.dispose();
    _providerFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminAppSettingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminAppSettingsProvider)),
      data: (settings) {
        final clientFeeRate =
            ((settings['client_fee_rate'] as num?) ?? PaymentService.clientFeeRate).toDouble();
        final providerFeeRate =
            ((settings['provider_fee_rate'] as num?) ?? PaymentService.providerFeeRate).toDouble();
        final maintenanceMode = settings['maintenance_mode'] as bool? ?? false;
        if (_clientFeeCtrl.text.isEmpty) {
          _clientFeeCtrl.text = (clientFeeRate * 100).toStringAsFixed(1);
        }
        if (_providerFeeCtrl.text.isEmpty) {
          _providerFeeCtrl.text = (providerFeeRate * 100).toStringAsFixed(1);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Comisión de la plataforma'),
              const SizedBox(height: 4),
              const Text(
                'Garantía YALO (cargo al cliente) y Membresía de Visibilidad (descuento al prestador), por separado.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _clientFeeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Garantía YALO — cliente (%)', suffixText: '%'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _providerFeeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Membresía — prestador (%)', suffixText: '%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveFees,
                        child: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Modo mantenimiento'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile(
                  value: maintenanceMode,
                  onChanged: _saving ? null : (_) => _toggleMaintenance(maintenanceMode),
                  activeColor: AppColors.error,
                  title: const Text('Bloquear acceso a usuarios normales',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    maintenanceMode
                        ? 'Activo: solo administradores pueden usar la app.'
                        : 'Inactivo: la app funciona normalmente para todos.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 8 — AUDITORÍA
// ═════════════════════════════════════════════════════════════════════════════
class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAuditLogProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminAuditLogProvider)),
      data: (logs) {
        if (logs.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: 'Sin actividad registrada',
            subtitle: 'Las acciones de administradores aparecerán aquí.',
            color: AppColors.primary,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final log = logs[i];
            final createdAt = DateTime.tryParse((log['created_at'] as String?) ?? '');
            return ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18, color: AppColors.textHint),
              title: Text(log['action'] as String? ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${log['admin_name'] ?? '-'}'
                '${log['target_table'] != null ? ' · ${log['target_table']}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: createdAt != null
                  ? Text(DateFormat('dd/MM HH:mm').format(createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textHint))
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Fila de barra horizontal simple (sin librería de gráficos) para
/// visualizar montos relativos: etiqueta, monto en RD$, y una barra
/// cuyo ancho es proporcional a `value / maxValue`.
class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                'RD\$${NumberFormat('#,###').format(value.toInt())}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(height: 8, color: AppColors.surfaceVariant),
                  Container(
                    height: 8,
                    width: constraints.maxWidth * fraction,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _RateCard extends StatelessWidget {
  final String label;
  final double rate;
  final Color color;
  final IconData icon;

  const _RateCard({
    required this.label,
    required this.rate,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text('${(rate * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alert;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert ? color.withValues(alpha: 0.6) : AppColors.divider,
          width: alert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              if (alert)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double revenue;
  const _RevenueCard({required this.revenue});

  @override
  Widget build(BuildContext context) {
    // Comisión total = tasas configuradas en Configuración (Garantía YALO + Membresía)
    final clientFeeTotal    = revenue * PaymentService.clientFeeRate;
    final providerFeeTotal  = revenue * PaymentService.providerFeeRate;
    final totalCommission   = clientFeeTotal + providerFeeTotal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.attach_money, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              'Ingresos este mes · ${DateFormat('MMMM yyyy', 'es').format(DateTime.now())}',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            revenue > 0
                ? 'RD\$${NumberFormat('#,###').format(revenue.toInt())}'
                : 'RD\$0',
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          // Desglose 5%+5%
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Garantía YALO (5% cliente): '
                      'RD\$${NumberFormat('#,###').format(clientFeeTotal.toInt())}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      'Membresía Visibilidad (5% prestador): '
                      'RD\$${NumberFormat('#,###').format(providerFeeTotal.toInt())}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total comisión YALO: '
                      'RD\$${NumberFormat('#,###').format(totalCommission.toInt())}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon, required this.label, required this.color,
    required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          : Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error, borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Error al cargar datos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final VoidCallback onBack;
  const _AccessDenied({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outlined, size: 72, color: AppColors.error),
              const SizedBox(height: 20),
              const Text('Acceso denegado',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Solo los administradores pueden acceder a este panel.\nContacta al equipo técnico si crees que esto es un error.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al inicio'),
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Simple confirm dialog (sin texto libre) ──────────────────────────────────
// ─── Contactar directo (WhatsApp con el teléfono, o abrir el correo) ─────────
Future<void> contactUser({
  required BuildContext context,
  required String name,
  String? phone,
  String? email,
}) async {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 10) {
    // Números dominicanos: 10 dígitos locales → anteponer código de país (1).
    final withCountryCode = digits.length == 10 ? '1$digits' : digits;
    final uri = Uri.parse(
        'https://wa.me/$withCountryCode?text=${Uri.encodeComponent("Hola $name, te contacto desde el equipo de YALO.")}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  }
  if (email != null && email.isNotEmpty) {
    final uri = Uri(scheme: 'mailto', path: email,
        queryParameters: {'subject': 'YALO'});
    final ok = await launchUrl(uri);
    if (ok) return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name no tiene teléfono ni correo válido registrado.'),
      backgroundColor: AppColors.warning,
    ));
  }
}

Future<bool> _showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─── Note/resolution dialog ───────────────────────────────────────────────────
Future<String?> _showNoteDialog({
  required BuildContext context,
  required String title,
  required String hint,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result?.isEmpty == true ? null : result;
}
