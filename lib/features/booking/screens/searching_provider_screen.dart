import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/demo_provider.dart';
import '../../providers_list/providers/providers_list_provider.dart';

class SearchingProviderScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const SearchingProviderScreen({super.key, required this.bookingId});

  @override
  ConsumerState<SearchingProviderScreen> createState() =>
      _SearchingProviderScreenState();
}

class _SearchingProviderScreenState
    extends ConsumerState<SearchingProviderScreen>
    with TickerProviderStateMixin {
  late final AnimationController _radarCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;

  Timer? _timeoutTimer;
  bool _timedOut = false;

  static const _timeoutMinutes = 10;

  @override
  void initState() {
    super.initState();

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _timeoutTimer = Timer(const Duration(minutes: _timeoutMinutes), () {
      if (mounted && !_timedOut) setState(() => _timedOut = true);
    });

  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onFound() {
    _radarCtrl.stop();
    _pulseCtrl.stop();
    _successCtrl.forward();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(demoModeProvider);

    // Demo: simulate acceptance after 4 seconds
    if (isDemo) {
      return _DemoSearching(
        radarCtrl: _radarCtrl,
        pulseCtrl: _pulseCtrl,
        successCtrl: _successCtrl,
        onFound: _onFound,
        bookingId: widget.bookingId,
      );
    }

    final bookingAsync = ref.watch(singleBookingProvider(widget.bookingId));

    return bookingAsync.when(
      loading: () => _buildSearchingUI(null),
      error: (_, __) => _buildSearchingUI(null),
      data: (booking) {
        final providerId = booking?['provider_id'];
        final status = booking?['status'] as String? ?? 'pending';

        if (providerId != null && status == 'accepted') {
          _onFound();
          return _buildFoundUI(booking!);
        }
        if (_timedOut) return _buildTimeoutUI();
        return _buildSearchingUI(booking);
      },
    );
  }

  // ── State: Searching ─────────────────────────────────────────────────────────

  Widget _buildSearchingUI(Map<String, dynamic>? booking) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/bookings'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Ver mis solicitudes'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Radar animation
                  _RadarAnimation(
                    radarCtrl: _radarCtrl,
                    pulseCtrl: _pulseCtrl,
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    'Buscando prestador…',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contactando prestadores disponibles\ncerca de tu área',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  if (booking != null) _buildBookingSummary(booking),
                ],
              ),
            ),

            // Timeout hint
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Text(
                'Si ningún prestador acepta en $_timeoutMinutes minutos,\nte avisaremos para reagendar.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State: Found ─────────────────────────────────────────────────────────────

  Widget _buildFoundUI(Map<String, dynamic> booking) {
    final providerName = booking['provider_name'] as String? ?? 'Prestador';
    final serviceName = booking['service_name'] as String? ?? 'Servicio';
    final scheduledDate = booking['scheduled_date'] as String?;
    final bookingId = booking['id'] as String;

    DateTime? date;
    if (scheduledDate != null) {
      try {
        date = DateTime.parse(scheduledDate).toLocal();
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppColors.successLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Success icon
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _successCtrl,
                  curve: Curves.elasticOut,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: AppColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                '¡Prestador encontrado!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                '$providerName aceptó tu solicitud',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ConfirmRow(
                      icon: Icons.person_outline,
                      label: 'Prestador',
                      value: providerName,
                    ),
                    const Divider(height: 20),
                    _ConfirmRow(
                      icon: Icons.home_repair_service_outlined,
                      label: 'Servicio',
                      value: serviceName,
                    ),
                    if (date != null) ...[
                      const Divider(height: 20),
                      _ConfirmRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Fecha',
                        value:
                            '${date.day}/${date.month}/${date.year} a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Abrir chat con el prestador'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => context.push(
                    '/chat/$bookingId'
                    '?name=${Uri.encodeComponent(providerName)}'
                    '&service=${Uri.encodeComponent(serviceName)}',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/bookings'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Ver mis solicitudes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State: Timeout ───────────────────────────────────────────────────────────

  Widget _buildTimeoutUI() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 80,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sin prestadores disponibles',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'No encontramos un prestador disponible ahora mismo en tu área. Tu solicitud quedó guardada y te notificaremos cuando uno esté disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/bookings'),
                child: const Text('Ver mis solicitudes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Booking summary card ──────────────────────────────────────────────────────

  Widget _buildBookingSummary(Map<String, dynamic> booking) {
    final serviceName = booking['service_name'] as String? ?? '';
    final address = booking['address'] as String? ?? '';
    final scheduledDate = booking['scheduled_date'] as String?;

    DateTime? date;
    if (scheduledDate != null) {
      try {
        date = DateTime.parse(scheduledDate).toLocal();
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serviceName.isNotEmpty)
            _SummaryRow(
              icon: Icons.home_repair_service_outlined,
              text: serviceName,
            ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.location_on_outlined,
              text: address,
            ),
          ],
          if (date != null) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.calendar_today_outlined,
              text: '${date.day}/${date.month}/${date.year} a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ],
      ),
    );
  }
}

// ── Demo searching widget ─────────────────────────────────────────────────────

class _DemoSearching extends StatefulWidget {
  final AnimationController radarCtrl;
  final AnimationController pulseCtrl;
  final AnimationController successCtrl;
  final VoidCallback onFound;
  final String bookingId;

  const _DemoSearching({
    required this.radarCtrl,
    required this.pulseCtrl,
    required this.successCtrl,
    required this.onFound,
    required this.bookingId,
  });

  @override
  State<_DemoSearching> createState() => _DemoSearchingState();
}

class _DemoSearchingState extends State<_DemoSearching> {
  bool _found = false;

  @override
  void initState() {
    super.initState();
    // Simulate provider accepting after 4 seconds in demo
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onFound();
        setState(() => _found = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_found) {
      return Scaffold(
        backgroundColor: AppColors.successLight,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 40),
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: widget.successCtrl,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 72, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '¡Prestador encontrado!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Juan Pérez aceptó tu solicitud',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Abrir chat con el prestador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.push(
                      '/chat/${widget.bookingId}'
                      '?name=${Uri.encodeComponent('Juan P%C3%A9rez')}'
                      '&service=Servicio',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('Ver mis solicitudes'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/bookings'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Ver mis solicitudes'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RadarAnimation(
                    radarCtrl: widget.radarCtrl,
                    pulseCtrl: widget.pulseCtrl,
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Buscando prestador…',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contactando prestadores disponibles\ncerca de tu área',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Radar animation widget ────────────────────────────────────────────────────

class _RadarAnimation extends StatelessWidget {
  final AnimationController radarCtrl;
  final AnimationController pulseCtrl;

  const _RadarAnimation({
    required this.radarCtrl,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rings
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, __) {
                final factor = (pulseCtrl.value + i / 3) % 1.0;
                return Container(
                  width: 80 + factor * 140,
                  height: 80 + factor * 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: (1 - factor) * 0.4),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),

          // Radar sweep
          AnimatedBuilder(
            animation: radarCtrl,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(160, 160),
                painter: _RadarPainter(radarCtrl.value),
              );
            },
          ),

          // Center icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.home_repair_service_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Radar sweep painter ───────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double progress;

  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final angle = progress * 2 * math.pi - math.pi / 2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - math.pi / 3,
        endAngle: angle,
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.5),
        ],
        transform: const GradientRotation(0),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Leading line
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
