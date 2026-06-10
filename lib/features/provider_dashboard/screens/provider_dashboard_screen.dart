import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/payment_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../providers_list/providers/providers_list_provider.dart';
import '../screens/provider_services_screen.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final bookingsAsync = ref.watch(providerBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Estás seguro de que quieres salir?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                final notifier = ref.read(authControllerProvider.notifier);
                await notifier.signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userAsync.when(
              data: (user) => _WelcomeBanner(name: user?.fullName ?? ''),
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),
            // Prompt para completar perfil si no tiene servicios
            const _SetupPrompt(),
            const SizedBox(height: 16),
            bookingsAsync.when(
              data: (bookings) => _buildStats(bookings),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 24),
            _buildAvailabilityToggle(ref),
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
            const Text(
              'Solicitudes recientes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            bookingsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return _buildEmptyBookings();
                }
                return Column(
                  children: bookings
                      .take(10)
                      .map((b) => _BookingRequestCard(booking: b))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 2),
    );
  }

  Widget _buildStats(List<dynamic> bookings) {
    final pending = bookings.where((b) => b['status'] == 'pending').length;
    final completed = bookings.where((b) => b['status'] == 'completed').length;
    final totalEarned = bookings
        .where((b) =>
            b['status'] == 'completed' && b['agreed_price'] != null)
        .fold<double>(
            0, (sum, b) => sum + (b['agreed_price'] as num).toDouble());

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Pendientes',
            value: pending.toString(),
            icon: Icons.pending_outlined,
            color: AppColors.warning,
            background: AppColors.warningLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Completados',
            value: completed.toString(),
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            background: AppColors.successLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Ingresos',
            value: '\$${totalEarned.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: AppColors.primary,
            background: AppColors.surfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityToggle(WidgetRef ref) {
    return _AvailabilityToggle();
  }

  Widget _buildEmptyBookings() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'No tienes solicitudes aún',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Asegúrate de tener tu perfil completo y estar disponible',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String name;
  const _WelcomeBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${name.split(' ').first} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Revisa tus solicitudes y gestiona tu disponibilidad',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.cleaning_services_rounded,
              color: Colors.white70, size: 40),
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
  final Color background;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AvailabilityToggle> createState() =>
      _AvailabilityToggleState();
}

class _AvailabilityToggleState extends ConsumerState<_AvailabilityToggle> {
  bool _isAvailable = true;
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      final isDemo = ref.read(demoModeProvider);
      if (isDemo) {
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        final user = SupabaseService.currentUser!;
        await SupabaseService.client
            .from('provider_profiles')
            .update({'is_available': !_isAvailable}).eq('user_id', user.id);
      }
      setState(() => _isAvailable = !_isAvailable);
    } catch (_) {
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
        border: Border.all(
          color: _isAvailable ? AppColors.success : AppColors.error,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAvailable
                ? Icons.check_circle
                : Icons.cancel,
            color: _isAvailable ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? 'Disponible' : 'No disponible',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        _isAvailable ? AppColors.success : AppColors.error,
                  ),
                ),
                Text(
                  _isAvailable
                      ? 'Los clientes pueden encontrarte'
                      : 'No aparecerás en búsquedas',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isAvailable,
                  activeThumbColor: AppColors.success,
                  onChanged: (_) => _toggle(),
                ),
        ],
      ),
    );
  }
}

class _BookingRequestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  const _BookingRequestCard({required this.booking});

  @override
  ConsumerState<_BookingRequestCard> createState() =>
      _BookingRequestCardState();
}

class _BookingRequestCardState extends ConsumerState<_BookingRequestCard> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        // ── Al completar: capturar el pago en escrow antes de actualizar el estado
        if (newStatus == 'completed') {
          final paymentIntentId =
              widget.booking['stripe_payment_intent_id'] as String?;
          final paymentStatus =
              widget.booking['payment_status'] as String? ?? 'pending';

          if (paymentIntentId != null && paymentStatus == 'authorized') {
            // Capturar pago en Stripe + marcar payment_status='released' en BD
            final captured = await PaymentService.capturePayment(
              bookingId: widget.booking['id'] as String,
              paymentIntentId: paymentIntentId,
            );
            if (!captured && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '⚠️ No se pudo capturar el pago. Contacta soporte.'),
                  backgroundColor: AppColors.warning,
                ),
              );
              setState(() => _loading = false);
              return; // No marcar completed si el pago falló
            }
            // La Edge Function ya actualiza status+payment_status en BD
            setState(() => _loading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Servicio completado — pago liberado'),
                  backgroundColor: AppColors.success,
                ),
              );
              final clientId =
                  widget.booking['client_id'] as String? ?? '';
              final clientName = Uri.encodeComponent(
                  widget.booking['client_name'] as String? ?? 'Cliente');
              final service = Uri.encodeComponent(
                  widget.booking['service_name'] as String? ?? 'Servicio');
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!mounted) return;
                context.push(
                  '/rate-client?bookingId=${widget.booking['id']}'
                  '&clientId=$clientId'
                  '&clientName=$clientName'
                  '&service=$service',
                );
              });
            }
            return; // La Edge Function ya actualizó el estado
          }
        }

        await SupabaseService.client
            .from('bookings')
            .update({
              'status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.booking['id']);
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // En modo real el stream se actualiza automáticamente
      // En demo refrescamos manualmente
      if (ref.read(demoModeProvider)) {
        ref.invalidate(providerBookingsProvider);
      }

      if (mounted) {
        String msg;
        Color color;
        switch (newStatus) {
          case 'accepted':
            msg = '✅ Solicitud aceptada';
            color = AppColors.success;
          case 'rejected':
            msg = 'Solicitud rechazada';
            color = AppColors.error;
          case 'in_progress':
            msg = '🔄 Marcado como en progreso';
            color = AppColors.info;
          case 'completed':
            msg = '🎉 Servicio marcado como completado';
            color = AppColors.primary;
          default:
            msg = 'Estado actualizado';
            color = AppColors.textSecondary;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color),
        );

        // ── Al completar: navegar a calificar cliente ─────────────
        if (newStatus == 'completed' && mounted) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (!mounted) return;
            final clientId = widget.booking['client_id'] as String? ?? '';
            final clientName = Uri.encodeComponent(
                widget.booking['client_name'] as String? ?? 'Cliente');
            final service = Uri.encodeComponent(
                widget.booking['service_name'] as String? ?? 'Servicio');
            context.push(
              '/rate-client?bookingId=${widget.booking['id']}'
              '&clientId=$clientId'
              '&clientName=$clientName'
              '&service=$service',
            );
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

    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        statusLabel = 'Pendiente';
      case 'accepted':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        statusLabel = 'Aceptado';
      case 'completed':
        statusColor = AppColors.primary;
        statusBg = AppColors.surfaceVariant;
        statusLabel = 'Completado';
      default:
        statusColor = AppColors.error;
        statusBg = AppColors.errorLight;
        statusLabel = 'Rechazado';
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
              Text(
                booking['service_name'] as String? ?? 'Servicio',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                booking['client_name'] as String? ?? 'Cliente',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          if (price != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money,
                    size: 14, color: AppColors.primary),
                Text(
                  'RD\$$price',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (paymentGuaranteed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 10, color: AppColors.success),
                        SizedBox(width: 3),
                        Text(
                          'Pago garantizado',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (booking['address'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking['address'] as String,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // ── Acciones según estado ──────────────────────────────
          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus('rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus('accepted'),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Chat'),
                      // provider=true → activa el modo prestador en el chat (oferta de precio)
                      onPressed: () => context.push(
                        '/chat/${booking['id']}?name=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}&provider=true',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Completar'),
                      onPressed: () => _updateStatus('completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'completed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('Calificar'),
                      onPressed: () => context.push(
                        '/rate-client'
                        '?bookingId=${booking['id']}'
                        '&clientId=${booking['client_id'] ?? ''}'
                        '&clientName=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}'
                        '&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.star,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => context.push(
                      '/report'
                      '?bookingId=${booking['id']}'
                      '&userId=${booking['client_id'] ?? ''}'
                      '&userName=${Uri.encodeComponent(booking['client_name'] as String? ?? '')}'
                      '&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}',
                    ),
                    child: const Icon(Icons.flag_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Prompt para completar el perfil ──────────────────────────────────────────
class _SetupPrompt extends ConsumerWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync =
        ref.watch(myProviderServicesProvider);

    return servicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (services) {
        if (services.isNotEmpty) return const SizedBox.shrink();

        // No tiene servicios → mostrar prompt
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C3AED).withValues(alpha: 0.1),
                AppColors.primaryLighter.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Completa tu perfil!',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Agrega tus servicios para que los clientes te encuentren.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () => context.push('/my-services'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Agregar servicios'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/bookings');
          case 2:
            context.go('/dashboard');
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Mis servicios',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Panel',
        ),
      ],
    );
  }
}
