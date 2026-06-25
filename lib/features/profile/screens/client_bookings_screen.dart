import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../providers_list/providers/providers_list_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ClientBookingsScreen extends ConsumerStatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  ConsumerState<ClientBookingsScreen> createState() =>
      _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends ConsumerState<ClientBookingsScreen> {
  // Track which booking IDs we've already auto-prompted for review
  final Set<String> _promptedReviewIds = {};
  bool _firstLoad = true;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    final isProvider =
        ref.watch(currentUserProvider).value?.role.name == 'provider';

    // ── Auto-trigger review when a booking newly becomes 'completed' ──
    ref.listen<AsyncValue<List<dynamic>>>(myBookingsProvider, (prev, next) {
      if (next.value == null) return;

      // On first load, register all existing completed IDs without triggering
      if (_firstLoad) {
        for (final b in next.value!) {
          if ((b as Map<String, dynamic>)['status'] == 'completed') {
            _promptedReviewIds.add(b['id'] as String);
          }
        }
        _firstLoad = false;
        return;
      }

      // Detect newly completed bookings
      for (final raw in next.value!) {
        final b = raw as Map<String, dynamic>;
        final id = b['id'] as String;
        if (b['status'] == 'completed' && !_promptedReviewIds.contains(id)) {
          _promptedReviewIds.add(id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showReviewDialog(context, b);
          });
          break; // show one dialog at a time
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis servicios'),
        automaticallyImplyLeading: false,
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookings) {
          if (bookings.isEmpty) return _buildEmpty(context);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final b = bookings[i] as Map<String, dynamic>;
                return _BookingCard(
                  booking: b,
                  onReview: () => _showReviewDialog(context, b),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 1, isProvider: isProvider),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cleaning_services_outlined,
                size: 40, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tienes servicios aún',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explora y solicita tu primer servicio',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Explorar servicios'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(
      BuildContext context, Map<String, dynamic> booking) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Check if review already submitted for this booking
    try {
      final existing = await SupabaseService.client
          .from('reviews')
          .select('id')
          .eq('booking_id', booking['id'] as String)
          .eq('client_id', user.id)
          .maybeSingle();
      if (existing != null) return; // already reviewed
    } catch (_) {}

    if (!context.mounted) return;

    double rating = 5;
    final ctrl = TextEditingController();
    bool sending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.star, size: 40),
              const SizedBox(height: 8),
              const Text('¿Cómo fue el servicio?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                booking['service_name'] as String? ?? 'Servicio',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => rating = (i + 1).toDouble()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < rating ? AppColors.star : AppColors.divider,
                        size: 38,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                _ratingLabel(rating),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: rating >= 4 ? AppColors.success : rating >= 3 ? AppColors.warning : AppColors.error,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Cuéntanos sobre tu experiencia (opcional)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      try {
                        final provProfile = await SupabaseService.client
                            .from('provider_profiles')
                            .select('id')
                            .eq('user_id', booking['provider_id'] as String)
                            .maybeSingle();

                        await SupabaseService.client.from('reviews').insert({
                          'provider_id': provProfile?['id'] ?? booking['provider_id'],
                          'client_id': user.id,
                          'booking_id': booking['id'],
                          'rating': rating,
                          'comment': ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                          'client_name': (await SupabaseService.client
                                  .from('profiles')
                                  .select('full_name')
                                  .eq('id', user.id)
                                  .maybeSingle())?['full_name'] ?? 'Cliente',
                          'created_at': DateTime.now().toIso8601String(),
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⭐ ¡Gracias por tu reseña!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar reseña'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  String _ratingLabel(double r) {
    if (r >= 5) return '😍 Excelente';
    if (r >= 4) return '😊 Muy bueno';
    if (r >= 3) return '😐 Regular';
    if (r >= 2) return '😟 Malo';
    return '😡 Muy malo';
  }
}

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onReview;

  const _BookingCard({required this.booking, required this.onReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = booking['status'] as String;
    final paymentStatus = booking['payment_status'] as String? ?? 'pending';
    final date = DateTime.tryParse(booking['scheduled_date'] as String? ?? '');
    final price = booking['agreed_price'];

    // needsPayment: el servicio está aceptado/en curso y el cliente aún no garantizó el pago
    final needsPayment = (status == 'accepted' || status == 'in_progress') &&
        paymentStatus == 'pending';

    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        statusLabel = 'Pendiente';
      case 'accepted':
        // Mostrar estado del pago en garantía
        if (paymentStatus == 'authorized') {
          statusColor = AppColors.success;
          statusBg = AppColors.successLight;
          statusLabel = '🔒 Pago en garantía';
        } else {
          statusColor = AppColors.success;
          statusBg = AppColors.successLight;
          statusLabel = 'Confirmado';
        }
      case 'in_progress':
        if (paymentStatus == 'authorized') {
          statusColor = AppColors.info;
          statusBg = AppColors.infoLight;
          statusLabel = '🔒 En progreso · Garantizado';
        } else {
          statusColor = AppColors.info;
          statusBg = AppColors.infoLight;
          statusLabel = 'En progreso';
        }
      case 'completed':
        final isReleased =
            paymentStatus == 'released' || paymentStatus == 'paid';
        statusColor = isReleased ? AppColors.primary : AppColors.warning;
        statusBg =
            isReleased ? AppColors.surfaceVariant : AppColors.warningLight;
        statusLabel = isReleased ? 'Completado ✓' : 'Pago pendiente';
      default:
        statusColor = AppColors.error;
        statusBg = AppColors.errorLight;
        statusLabel = 'Cancelado';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsPayment ? AppColors.warning.withValues(alpha: 0.5) : AppColors.divider,
          width: needsPayment ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking['service_name'] as String? ?? 'Servicio',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                booking['provider_name'] as String? ?? 'Prestador',
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
                const Icon(Icons.monetization_on_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 2),
                Text(
                  'RD\$$price',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          // Chat disponible para accepted e in_progress
          if (status == 'accepted' || status == 'in_progress') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Abrir chat'),
                onPressed: () => context.push(
                  '/chat/${booking['id']}?name=${Uri.encodeComponent(booking['provider_name'] as String? ?? '')}&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}',
                ),
              ),
            ),
          ],
          // ── COMPLETADO SIN PAGAR → botón de pago principal ────────
          if (needsPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El servicio fue completado. Realiza el pago al prestador.',
                      style: TextStyle(fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(price != null ? 'Pagar RD\$$price' : 'Realizar pago'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => context.push(
                  '/payment?bookingId=${booking['id']}'
                  '&amount=${price ?? 0}'
                  '&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}'
                  '&provider=${Uri.encodeComponent(booking['provider_name'] as String? ?? '')}'
                  '&currency=dop',
                ),
              ),
            ),
          ],
          // ── COMPLETADO → reseña y reporte (independiente del pago) ──
          if (status == 'completed') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReview,
                    child: const Text('Dejar reseña'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => context.push(
                    '/report?bookingId=${booking['id']}'
                    '&userId=${booking['provider_id']}'
                    '&userName=${Uri.encodeComponent(booking['provider_name'] as String? ?? '')}'
                    '&service=${Uri.encodeComponent(booking['service_name'] as String? ?? '')}',
                  ),
                  child: const Icon(Icons.flag_outlined, size: 18),
                ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Cancelar solicitud?'),
                      content: const Text(
                        'Esta acción no se puede deshacer. El prestador será notificado.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('No, mantener'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Sí, cancelar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;

                  final isDemo = ref.read(demoModeProvider);
                  if (!isDemo) {
                    await SupabaseService.client
                        .from('bookings')
                        .update({'status': 'cancelled'}).eq(
                            'id', booking['id']);
                    // El stream se actualiza automáticamente
                  }
                  // En demo: refrescar manualmente
                  if (isDemo) ref.invalidate(myBookingsProvider);
                },
                child: const Text('Cancelar solicitud'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isProvider;
  const _BottomNav({required this.currentIndex, required this.isProvider});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/bookings');
          case 2:
            if (isProvider) {
              context.go('/dashboard');
            } else {
              context.go('/profile');
            }
        }
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Mis servicios',
        ),
        BottomNavigationBarItem(
          icon: Icon(isProvider ? Icons.dashboard_outlined : Icons.person_outline),
          activeIcon: Icon(isProvider ? Icons.dashboard : Icons.person),
          label: isProvider ? 'Panel' : 'Perfil',
        ),
      ],
    );
  }
}
