import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../providers/admin_provider.dart';

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
    _tab = TabController(length: 5, vsync: this);
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
    ref.invalidate(adminRecentBookingsProvider);
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
            onPressed: onRefresh,
          ),
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
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
    final cedula = req['cedula_number'] as String? ?? '—';
    final submittedAt = DateTime.tryParse((req['submitted_at'] as String?) ?? '');

    final frontUrl = req['cedula_front_url'] as String?;
    final backUrl = req['cedula_back_url'] as String?;
    final selfieUrl = req['selfie_url'] as String?;

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
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('$city${province.isNotEmpty ? ', $province' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (email.isNotEmpty)
                      Text(email,
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
              Text('Cédula: $cedula',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (submittedAt != null)
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(submittedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Document photos
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

class _DocPhoto extends StatelessWidget {
  final String? url;
  final String label;
  const _DocPhoto({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null
                ? CachedNetworkImage(
                    imageUrl: url!,
                    height: 70,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(height: 4),
          Text(label,
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
                  label: 'Reportó', name: reporterName, color: AppColors.info),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 8),
              _PartyChip(
                  label: 'Reportado',
                  name: reportedName,
                  color: AppColors.error),
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
  const _PartyChip(
      {required this.label, required this.name, required this.color});

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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — USUARIOS
// ═════════════════════════════════════════════════════════════════════════════
class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentUsersProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminRecentUsersProvider)),
      data: (users) {
        if (users.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            title: 'Sin usuarios',
            subtitle: 'No hay usuarios registrados aún.',
            color: AppColors.primary,
          );
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Últimos ${users.length} usuarios registrados',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
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
                            style: const TextStyle(fontSize: 11)),
                        if (city.isNotEmpty)
                          Text('$city${province.isNotEmpty ? ', $province' : ''}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                    trailing: Column(
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
class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentBookingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminRecentBookingsProvider)),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'Sin reservas',
            subtitle: 'No hay reservas registradas aún.',
            color: AppColors.primary,
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Últimas ${bookings.length} reservas',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
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
                  final amount = (b['amount'] as num?)?.toDouble();
                  final serviceName = b['service_name'] as String? ?? '—';
                  final createdAt = DateTime.tryParse(
                      (b['created_at'] as String?) ?? '');

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
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

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
    final commission = revenue * 0.15;
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
          const SizedBox(height: 4),
          Text(
            'Comisión ServiciosYa (15%): RD\$${NumberFormat('#,###').format(commission.toInt())}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
