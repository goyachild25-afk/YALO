import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/user_location_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/push_service.dart';
import '../../../core/utils/map_launcher.dart';
import '../../verification/providers/verification_status_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../providers_list/providers/providers_list_provider.dart';
import '../../../shared/models/service_category_model.dart';
import '../screens/provider_services_screen.dart';
import '../widgets/client_reputation_badge.dart';
import '../widgets/provider_stats_section.dart';
import '../widgets/level_progress_card.dart';
import '../../../shared/widgets/photo_picker_grid.dart';

// ── Mapa de actividad de RD ───────────────────────────────────────────────────


// ── Sección del mapa de actividad ─────────────────────────────────────────────

class _ActivityMapSection extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  const _ActivityMapSection({required this.requests});

  @override
  State<_ActivityMapSection> createState() => _ActivityMapSectionState();
}

class _ActivityMapSectionState extends State<_ActivityMapSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in widget.requests) {
      final p = r['client_province'] as String? ?? '';
      if (p.isNotEmpty) counts[p] = (counts[p] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = widget.requests.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Solicitudes en tu zona',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (total > 0)
              _PulseBadge(count: total),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: _UserLocationMap(requests: widget.requests),
          ),
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: sorted.take(5).map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${e.key.split(' ').first} · ${e.value}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )).toList(),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Sin solicitudes pendientes en tu provincia ahora mismo.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ],
    );
  }
}

class _PulseBadge extends StatefulWidget {
  final int count;
  const _PulseBadge({required this.count});

  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${widget.count} activas',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard principal ────────────────────────────────────────────────────────

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final bookingsAsync = ref.watch(providerBookingsProvider);

    // ── Puerta de seguridad: sin verificación de identidad no hay panel ──
    // Los prestadores entran a hogares de clientes; nadie opera sin haber
    // pasado por la captura de cédula + selfie (Didit). Si el proceso no
    // se ha completado, el único camino es /verify-identity.
    final verifAsync = ref.watch(myVerificationRequestProvider);
    final verifRow = verifAsync.valueOrNull;
    if (verifAsync.hasValue && !verificationGateOk(verifRow)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/verify-identity');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner de bienvenida
            userAsync.when(
              data: (user) => _WelcomeBanner(name: user?.fullName ?? ''),
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),

            // ── Identidad en revisión: puede explorar, no aceptar ─────────
            if (verifRow != null && verifRow['status'] != 'approved') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded,
                        size: 22, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu identidad está en revisión (24-48h). Mientras tanto puedes configurar tu perfil y servicios, pero no aceptar solicitudes — así protegemos los hogares de nuestros clientes.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Prompt si no tiene servicios configurados
            const _SetupPrompt(),
            const SizedBox(height: 16),

            // ── Estadísticas
            bookingsAsync.when(
              data: (b) => _buildStats(context, b),
              loading: () => const _StatsSkeletonRow(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),

            // ── Disponibilidad
            const _AvailabilityToggle(),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              icon: const Icon(Icons.work_outline, size: 18),
              label: const Text('Gestionar mis servicios'),
              onPressed: () => context.push('/my-services'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Mapa de solicitudes + solicitudes abiertas en tiempo real
            const _OpenRequestsWithMap(),
            const SizedBox(height: 24),

            // ── Solicitudes recientes (ya asignadas al prestador)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mis solicitudes recientes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => context.push('/provider-history'),
                  child: const Text('Ver historial', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            bookingsAsync.when(
              loading: () => const _BookingsSkeletonList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bookings) {
                // Filter out completed, rejected and cancelled bookings
                final activeBookings = bookings
                    .where((b) =>
                        b['status'] != 'completed' &&
                        b['status'] != 'rejected' &&
                        b['status'] != 'cancelled')
                    .toList();
                if (activeBookings.isEmpty) return _buildEmptyBookings();
                final list = activeBookings.take(10).toList();
                return Column(
                  children: list.asMap().entries.map((entry) =>
                    _StaggeredCard(
                      delay: Duration(milliseconds: entry.key * 55),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BookingRequestCard(booking: entry.value as Map<String, dynamic>),
                      ),
                    ),
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _ProviderBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStats(BuildContext context, List<dynamic> bookings) {
    final pending = bookings.where((b) => b['status'] == 'pending').length;
    final completed = bookings.where((b) => b['status'] == 'completed').length;
    final totalEarned = bookings
        .where((b) => b['status'] == 'completed' && b['agreed_price'] != null)
        .fold<double>(0, (sum, b) => sum + (b['agreed_price'] as num).toDouble());

    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Pendientes', value: pending.toString(),
          icon: Icons.pending_outlined, color: AppColors.warning, background: AppColors.warningLight)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Completados', value: completed.toString(),
          icon: Icons.check_circle_outline, color: AppColors.success, background: AppColors.successLight,
          onTap: () => context.push('/provider-history'))),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Ingresos', value: 'RD\$${totalEarned.toStringAsFixed(0)}',
          icon: Icons.attach_money, color: AppColors.primary, background: AppColors.surfaceVariant)),
      ],
    );
  }

  Widget _buildEmptyBookings() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No tienes solicitudes aún',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            SizedBox(height: 4),
            Text('Asegúrate de tener tu perfil completo y estar disponible',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Solicitudes abiertas + mapa (combinados para compartir el stream) ─────────

class _OpenRequestsWithMap extends ConsumerStatefulWidget {
  const _OpenRequestsWithMap();

  @override
  ConsumerState<_OpenRequestsWithMap> createState() => _OpenRequestsWithMapState();
}

class _OpenRequestsWithMapState extends ConsumerState<_OpenRequestsWithMap> {
  String _province = '';
  List<String> _categoryNames = [];
  List<String> _categoryIds = [];
  bool _loadingProfile = true;
  int _previousRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final p = await SupabaseService.client
          .from('provider_profiles')
          .select('province')
          .eq('user_id', user.id)
          .maybeSingle();

      final province = p?['province'] as String? ?? '';

      // Categorías del prestador (para filtrar solicitudes por nicho)
      final services = await ref.read(myProviderServicesProvider.future);
      final categories = services
          .where((s) => s.categoryName.isNotEmpty)
          .map((s) => s.categoryName.toLowerCase())
          .toList();
      final catIds = services
          .where((s) => s.categoryId.isNotEmpty)
          .map((s) => s.categoryId)
          .toList();

      if (mounted) {
        setState(() {
          _province = province;
          _categoryNames = categories;
          _categoryIds = catIds;
        });
      }

      // Actualizar en background la posición real del prestador. Es lo que
      // alimenta el orden "Más cercanos" del lado del cliente: sin
      // coordenadas frescas, ese sort no tiene con qué trabajar.
      _syncMyCoordinates(user.id);

      // Suscribir este navegador a Web Push para recibir solicitudes nuevas
      // del nicho aunque la app esté cerrada (pide permiso la primera vez).
      PushService.ensureSubscribed();
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _syncMyCoordinates(String userId) async {
    try {
      final pos = await ref.read(userLocationProvider.future);
      if (pos == null) return;
      await SupabaseService.client.from('provider_profiles').update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      }).eq('user_id', userId);
    } catch (_) {
      // Sin permiso de ubicación o sin conexión: el prestador conserva las
      // coordenadas anteriores (o ninguna). Nunca interrumpe el dashboard.
    }
  }

  bool _matchesCategory(Map<String, dynamic> request) {
    if (_categoryNames.isEmpty && _categoryIds.isEmpty) return true;
    final catId = request['category_id'] as String? ?? '';
    if (catId.isEmpty) return true;

    // Coincidencia directa (solicitud directa a un prestador ya usa el id granular)
    if (_categoryIds.contains(catId)) return true;

    // Solicitud "broadcast" creada desde la categoría amplia que ve el cliente
    // (ej. 'maintenance') → expandir al set de categorías granulares reales
    // que sí usan los prestadores antes de comparar.
    final granular = broadToGranularCategoryIds[catId];
    if (granular != null && granular.any(_categoryIds.contains)) return true;

    return false;
  }

  Future<void> _acceptRequest(Map<String, dynamic> booking) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final profile = await SupabaseService.client
          .from('provider_profiles')
          .select('id, full_name, avatar_url, is_verified')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) { _showSnack('Completa tu perfil de prestador primero'); return; }

      // Seguridad: solo prestadores con identidad aprobada por el equipo
      // pueden aceptar trabajos en hogares de clientes.
      if (profile['is_verified'] != true) {
        _showSnack(
            'Tu identidad aún está en revisión. Podrás aceptar solicitudes cuando sea aprobada (24-48h).',
            AppColors.warning);
        return;
      }

      final updated = await SupabaseService.client
          .from('bookings')
          .update({
            'provider_id': profile['id'],
            'provider_name': profile['full_name'],
            'provider_avatar_url': profile['avatar_url'],
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', booking['id'] as String)
          .eq('status', 'pending')
          .select();

      if (!mounted) return;
      if ((updated as List).isEmpty) {
        _showSnack('Este servicio ya fue tomado por otro prestador', AppColors.warning);
      } else {
        _showSnack('¡Solicitud aceptada!', AppColors.success);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg, [Color color = AppColors.error]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(demoModeProvider)) return const SizedBox.shrink();
    if (_loadingProfile) return const SizedBox.shrink();

    final requestsAsync = ref.watch(openRequestsProvider(_province));

    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allRequests) {
        // Filtra por categorías del prestador
        final matched = allRequests
            .where((r) => r['provider_id'] == null && _matchesCategory(r))
            .toList();

        // Notificación si llega una solicitud nueva que coincide
        if (matched.length > _previousRequestCount && _previousRequestCount > 0) {
          Future.microtask(() {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Expanded(child: Text('¡Nueva solicitud disponible!'))
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        }
        _previousRequestCount = matched.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progreso al siguiente nivel (motivador)
            const LevelProgressCard(),
            const SizedBox(height: 16),

            // Mi rendimiento personal
            const ProviderStatsSection(),
            const SizedBox(height: 24),

            // Mapa de actividad con TODAS las solicitudes de la provincia
            _ActivityMapSection(requests: allRequests
                .where((r) => r['provider_id'] == null).toList()),
            const SizedBox(height: 24),

            // Solicitudes que coinciden con el nicho del prestador
            if (matched.isNotEmpty) ...[
              Row(
                children: [
                  const Text('Solicitudes para ti',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error, borderRadius: BorderRadius.circular(20)),
                    child: Text('${matched.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _categoryNames.isEmpty
                    ? 'Clientes de tu área buscando prestador'
                    : 'Clientes buscando: ${_categoryNames.take(2).join(", ")}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ...matched.take(5).map((r) => _OpenRequestCard(
                request: r, onAccept: () => _acceptRequest(r))),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: AppColors.textHint, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                      'Sin solicitudes de tu nicho ahora mismo. Te notificaremos cuando lleguen.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    )),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Tarjeta de solicitud abierta ──────────────────────────────────────────────

class _OpenRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final Future<void> Function() onAccept;
  const _OpenRequestCard({required this.request, required this.onAccept});

  @override
  State<_OpenRequestCard> createState() => _OpenRequestCardState();
}

class _OpenRequestCardState extends State<_OpenRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
    _enterCtrl.forward();
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final serviceName = r['service_name'] as String? ?? 'Servicio';
    final clientName = r['client_name'] as String? ?? 'Cliente';
    final address = r['address'] as String? ?? '';
    final province = r['client_province'] as String? ?? '';
    final notes = r['notes'] as String?;
    final scheduledDate = r['scheduled_date'] as String?;
    DateTime? date;
    try { if (scheduledDate != null) date = DateTime.parse(scheduledDate).toLocal(); } catch (_) {}

    return FadeTransition(
      opacity: _enterCtrl,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del servicio
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home_repair_service_outlined,
                      size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(serviceName,
                      style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Nuevo',
                        style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _InfoRow(
                                icon: Icons.person_outline, text: clientName)),
                        if ((r['client_id'] as String?) != null) ...[
                          const SizedBox(width: 8),
                          ClientReputationBadge(
                              clientId: r['client_id'] as String),
                        ],
                      ],
                    ),
                    if (province.isNotEmpty || address.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: [if (province.isNotEmpty) province, if (address.isNotEmpty) address]
                            .join(' · '),
                      ),
                    ],
                    if (date != null) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: '${date.day}/${date.month}/${date.year} '
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoRow(icon: Icons.note_outlined, text: notes, maxLines: 2),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_outlined, size: 18),
                          label: const Text('Rechazar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _accepting ? null : () async {
                            setState(() => _accepting = true);
                            try {
                              await SupabaseService.client
                                  .from('bookings')
                                  .update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()})
                                  .eq('id', widget.request['id'] as String);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Solicitud rechazada'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _accepting = false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _accepting
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(_accepting ? 'Aceptando…' : 'Aceptar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          onPressed: _accepting ? null : () async {
                            setState(() => _accepting = true);
                            await widget.onAccept();
                            if (mounted) setState(() => _accepting = false);
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;
  const _InfoRow({required this.icon, required this.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          maxLines: maxLines, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ── Banner de bienvenida ──────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String name;
  const _WelcomeBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, ${name.split(' ').first}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Gestiona tus servicios y mantente disponible',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          )),
          const Icon(Icons.handyman_outlined, color: Colors.white54, size: 42),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, background;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.icon,
      required this.color, required this.background, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

// ── Toggle de disponibilidad ──────────────────────────────────────────────────

class _AvailabilityToggle extends ConsumerStatefulWidget {
  const _AvailabilityToggle();

  @override
  ConsumerState<_AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends ConsumerState<_AvailabilityToggle> {
  bool _isAvailable = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  // El switch debe reflejar el valor real en la BD: si el prestador se puso
  // "No disponible" ayer, al reabrir la app debe seguir viéndose apagado.
  // Antes arrancaba siempre en true y el prestador podía creer que era
  // visible en búsquedas cuando no lo era.
  Future<void> _loadCurrent() async {
    if (ref.read(demoModeProvider)) return;
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;
      final row = await SupabaseService.client
          .from('provider_profiles')
          .select('is_available')
          .eq('user_id', user.id)
          .maybeSingle();
      final available = row?['is_available'] as bool?;
      if (mounted && available != null) {
        setState(() => _isAvailable = available);
      }
    } catch (_) {
      // Sin red dejamos el valor optimista; el toggle sigue funcionando.
    }
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      if (ref.read(demoModeProvider)) {
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        final user = SupabaseService.currentUser!;
        await SupabaseService.client
            .from('provider_profiles')
            .update({'is_available': !_isAvailable}).eq('user_id', user.id);
      }
      setState(() => _isAvailable = !_isAvailable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isAvailable ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _isAvailable ? AppColors.success : AppColors.error),
      ),
      child: Row(
        children: [
          Icon(_isAvailable ? Icons.check_circle : Icons.cancel,
            color: _isAvailable ? AppColors.success : AppColors.error),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isAvailable ? 'Disponible' : 'No disponible',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isAvailable ? AppColors.success : AppColors.error)),
              Text(_isAvailable ? 'Los clientes pueden encontrarte' : 'No aparecerás en búsquedas',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
          _loading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: _isAvailable, onChanged: (_) => _toggle()),
        ],
      ),
    );
  }
}

// ── Tarjeta de booking ya asignado ────────────────────────────────────────────

class _BookingRequestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  const _BookingRequestCard({required this.booking});

  @override
  ConsumerState<_BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends ConsumerState<_BookingRequestCard> {
  bool _loading = false;

  Future<void> _confirmCompleteWithPhotos() async {
    List<String> photos = [];
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marcar como completado',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Añade 1-3 fotos del trabajo terminado. Sirven como evidencia si surge una disputa y aumentan la confianza del cliente para dejarte 5 estrellas.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                PhotoPickerGrid(
                  bucket: 'booking-photos',
                  folder: '${widget.booking['id']}/completion',
                  maxPhotos: 3,
                  addLabel: 'Añadir\nfoto',
                  onChange: (urls) => setSheet(() => photos = urls),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(photos.isEmpty
                            ? 'Completar sin fotos'
                            : 'Completar (${photos.length})'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );

    if (confirmed != true) return;

    // Guardar las fotos ANTES de cambiar el status para que ya estén
    // registradas cuando el cliente entre a ver el detalle
    if (photos.isNotEmpty) {
      try {
        await SupabaseService.client.from('bookings').update({
          'completion_photos': photos,
        }).eq('id', widget.booking['id']);
      } catch (_) {
        // no bloqueamos el completar por un error de escritura de fotos
      }
    }

    await _updateStatus('completed');
  }

  Future<void> _confirmCancelAccepted() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El cliente será notificado. Cuéntale brevemente por qué cancelas — ayuda si hay una disputa.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej: emergencia familiar, no puedo llegar a tiempo…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Volver'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: const Text('Cancelar servicio'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    final existingNotes = widget.booking['notes'] as String?;
    final mergedNotes = [
      if (existingNotes != null && existingNotes.trim().isNotEmpty) existingNotes,
      'Cancelado por el prestador: $reason',
    ].join('\n\n');

    await _updateStatus('cancelled', extraFields: {'notes': mergedNotes});
  }

  Future<void> _updateStatus(String newStatus, {Map<String, dynamic>? extraFields}) async {
    setState(() => _loading = true);
    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        if (newStatus == 'completed') {
          final paymentIntentId = widget.booking['stripe_payment_intent_id'] as String?;
          final paymentStatus = widget.booking['payment_status'] as String? ?? 'pending';

          if (paymentIntentId != null && paymentStatus == 'authorized') {
            final captured = await PaymentService.capturePayment(
              bookingId: widget.booking['id'] as String,
              paymentIntentId: paymentIntentId,
            );
            if (!captured && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⚠️ No se pudo capturar el pago. Contacta soporte.'),
                    backgroundColor: AppColors.warning));
              setState(() => _loading = false);
              return;
            }
            setState(() => _loading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 Servicio completado — pago liberado'),
                    backgroundColor: AppColors.success));
              final clientId = widget.booking['client_id'] as String? ?? '';
              final clientName = Uri.encodeComponent(widget.booking['client_name'] as String? ?? 'Cliente');
              final service = Uri.encodeComponent(widget.booking['service_name'] as String? ?? 'Servicio');
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!mounted) return;
                context.push('/rate-client?bookingId=${widget.booking['id']}&clientId=$clientId&clientName=$clientName&service=$service');
              });
            }
            return;
          }
        }
        await SupabaseService.client.from('bookings').update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
          ...?extraFields,
        }).eq('id', widget.booking['id']);
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (ref.read(demoModeProvider)) ref.invalidate(providerBookingsProvider);

      if (mounted) {
        String msg;
        Color color;
        switch (newStatus) {
          case 'accepted': msg = '✅ Solicitud aceptada'; color = AppColors.success;
          case 'rejected': msg = 'Solicitud rechazada'; color = AppColors.error;
          case 'cancelled': msg = 'Servicio cancelado'; color = AppColors.error;
          case 'in_progress': msg = '🔄 En progreso'; color = AppColors.info;
          case 'completed': msg = '🎉 Servicio completado'; color = AppColors.primary;
          default: msg = 'Estado actualizado'; color = AppColors.textSecondary;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

        if (newStatus == 'completed' && mounted) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (!mounted) return;
            final clientId = widget.booking['client_id'] as String? ?? '';
            final clientName = Uri.encodeComponent(widget.booking['client_name'] as String? ?? 'Cliente');
            final service = Uri.encodeComponent(widget.booking['service_name'] as String? ?? 'Servicio');
            context.push('/rate-client?bookingId=${widget.booking['id']}&clientId=$clientId&clientName=$clientName&service=$service');
          });
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking['status'] as String;
    final paymentStatus = booking['payment_status'] as String? ?? 'pending';
    final date = DateTime.tryParse(booking['scheduled_date'] as String? ?? '');
    final price = booking['agreed_price'];
    final paymentGuaranteed = paymentStatus == 'authorized';

    Color statusColor; Color statusBg; String statusLabel;
    switch (status) {
      case 'pending':  statusColor = AppColors.warning; statusBg = AppColors.warningLight; statusLabel = 'Pendiente';
      case 'accepted': statusColor = AppColors.success; statusBg = AppColors.successLight; statusLabel = 'Aceptado';
      case 'completed': statusColor = AppColors.primary; statusBg = AppColors.surfaceVariant; statusLabel = 'Completado';
      case 'cancelled': statusColor = AppColors.error;   statusBg = AppColors.errorLight;   statusLabel = 'Cancelado por ti';
      default:         statusColor = AppColors.error;   statusBg = AppColors.errorLight;   statusLabel = 'Rechazado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(booking['service_name'] as String? ?? 'Servicio',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.person_outline, text: booking['client_name'] as String? ?? 'Cliente'),
          if (date != null) ...[
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.calendar_today_outlined,
              text: DateFormat('dd/MM/yyyy HH:mm').format(date)),
          ],
          if (price != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.attach_money, size: 14, color: AppColors.primary),
              Flexible(
                child: Text(
                  'Recibirás ${PaymentService.formatPesos(PaymentService.providerAmount((price as num).toDouble()))}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              if (paymentGuaranteed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline, size: 10, color: AppColors.success),
                    SizedBox(width: 3),
                    Text('Pago garantizado',
                      style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 1),
              child: Text(
                'de RD\$$price, −${(PaymentService.providerFeeRate * 100).toStringAsFixed(0)}% membresía',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (booking['address'] != null) ...[
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.location_on_outlined, text: booking['address'] as String),
          ],
          // Acciones
          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => _updateStatus('rejected'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  child: const Text('Rechazar'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => _updateStatus('accepted'),
                  child: const Text('Aceptar'))),
              ]),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 12),
              // Navegar directo a donde está el cliente (usa las coordenadas
              // GPS capturadas al crear la solicitud, o compartidas por chat)
              if (booking['client_lat'] != null &&
                  booking['client_lng'] != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Cómo llegar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => showOpenInMapsSheet(
                      context,
                      lat: (booking['client_lat'] as num).toDouble(),
                      lng: (booking['client_lng'] as num).toDouble(),
                      title:
                          'Ubicación de ${booking['client_name'] as String? ?? 'cliente'}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat'),
                  onPressed: () => context.push(
                    '/chat/${booking['id']}?name=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}&provider=true'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Completar'),
                  onPressed: _confirmCompleteWithPhotos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success, foregroundColor: Colors.white))),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar servicio'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  onPressed: _confirmCancelAccepted,
                ),
              ),
            ],
            if (status == 'completed') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Calificar'),
                  onPressed: () => context.push(
                    '/rate-client?bookingId=${booking['id']}&clientId=${booking['client_id'] ?? ''}&clientName=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.star, foregroundColor: Colors.white))),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  onPressed: () => context.push(
                    '/report?bookingId=${booking['id']}&userId=${booking['client_id'] ?? ''}&userName=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}'),
                  child: const Icon(Icons.flag_outlined, size: 18)),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Prompt para completar perfil ──────────────────────────────────────────────

class _SetupPrompt extends ConsumerWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myProviderServicesProvider).when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (services) {
        if (services.isNotEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF7C3AED).withValues(alpha: 0.1),
              AppColors.primaryLighter.withValues(alpha: 0.15),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¡Completa tu perfil!',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Agrega tus servicios para que los clientes te encuentren.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () => context.push('/my-services'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 13)),
                      child: const Text('Agregar servicios'))),
                ],
              )),
            ],
          ),
        );
      },
    );
  }
}

// ── Skeleton loaders ──────────────────────────────────────────────────────────

class _StatsSkeletonRow extends StatelessWidget {
  const _StatsSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 88, margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        )),
      ),
    );
  }
}

class _BookingsSkeletonList extends StatelessWidget {
  const _BookingsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(3, (_) => Container(
          height: 120, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
      ),
    );
  }
}

// ── Animación de entrada escalonada ──────────────────────────────────────────

class _StaggeredCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _StaggeredCard({required this.child, required this.delay});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child));
  }
}

// ── Bottom nav del prestador (sin rutas del cliente) ─────────────────────────

class _ProviderBottomNav extends ConsumerWidget {
  final int currentIndex;
  const _ProviderBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/dashboard');
          case 1: context.go('/notifications');
          case 2: context.go('/profile');
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Mi panel',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Avisos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}

// ── User location map with Google Maps ──────────────────────────────────────
class _UserLocationMap extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> requests;
  const _UserLocationMap({required this.requests});

  @override
  ConsumerState<_UserLocationMap> createState() => _UserLocationMapState();
}

class _UserLocationMapState extends ConsumerState<_UserLocationMap> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission().timeout(const Duration(seconds: 8));
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
          _updateMarkers();
        });

        // Animate camera to user location
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _userLocation!,
              zoom: 13,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userLocation = const LatLng(18.4861, -69.9312); // Default: Santo Domingo
          _isLoadingLocation = false;
          _updateMarkers();
        });
      }
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // User location marker
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _userLocation!,
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Un marcador naranja por cada solicitud abierta que trae coordenadas
    // exactas del cliente. El prestador ve DÓNDE está cada trabajo, no solo
    // "hay 3 en tu provincia".
    for (final r in widget.requests) {
      final lat = (r['client_lat'] as num?)?.toDouble();
      final lng = (r['client_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('req-${r['id']}'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: r['service_name'] as String? ?? 'Solicitud',
            snippet: r['client_name'] as String? ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  @override
  void didUpdateWidget(covariant _UserLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El stream de solicitudes es Realtime: si entra una nueva mientras el
    // mapa está abierto, sus pines deben aparecer sin recargar.
    if (!identical(oldWidget.requests, widget.requests)) {
      _updateMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(
        target: _userLocation ?? const LatLng(18.4861, -69.9312),
        zoom: 13,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapType: MapType.normal,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ── Historial de trabajos completados ─────────────────────────────────────────
// Antes solo se veían en "Mis solicitudes recientes" hasta que se completaban
// y desaparecían — el prestador se quedaba solo con el contador "Completados".
// Esta pantalla es el historial completo, más reciente primero.

class ProviderHistoryScreen extends ConsumerWidget {
  const ProviderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(providerBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Historial de trabajos')),
      body: bookingsAsync.when(
        loading: () => const _BookingsSkeletonList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookings) {
          final completed = bookings
              .where((b) => (b as Map<String, dynamic>)['status'] == 'completed')
              .cast<Map<String, dynamic>>()
              .toList()
            ..sort((a, b) {
              final da = DateTime.tryParse(a['scheduled_date'] as String? ?? '');
              final db = DateTime.tryParse(b['scheduled_date'] as String? ?? '');
              if (da == null || db == null) return 0;
              return db.compareTo(da);
            });

          if (completed.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 56, color: AppColors.textHint),
                    SizedBox(height: 12),
                    Text('Aún no tienes trabajos completados',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          final totalEarned = completed
              .where((b) => b['agreed_price'] != null)
              .fold<double>(0, (sum, b) =>
                  sum + PaymentService.providerAmount((b['agreed_price'] as num).toDouble()));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${completed.length} trabajos completados',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                    Text('Recibido: ${PaymentService.formatPesos(totalEarned)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...completed.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BookingRequestCard(booking: b),
                  )),
            ],
          );
        },
      ),
    );
  }
}
