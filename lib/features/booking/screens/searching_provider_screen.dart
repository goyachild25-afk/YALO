import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/push_service.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _successCtrl;
  Timer? _timeoutTimer;
  bool _timedOut = false;
  static const _timeoutMinutes = 10;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _timeoutTimer = Timer(const Duration(minutes: _timeoutMinutes), () {
      if (mounted && !_timedOut) setState(() => _timedOut = true);
    });
    // Suscribir al cliente a Web Push AHORA: está esperando que acepten su
    // solicitud — el momento perfecto para pedir permiso de notificaciones.
    // Así el "te notificaremos" de esta pantalla se cumple aunque cierre la app.
    PushService.ensureSubscribed();
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onFound() => _successCtrl.forward();

  @override
  Widget build(BuildContext context) {
    if (ref.watch(demoModeProvider)) {
      return _DemoSearching(successCtrl: _successCtrl, onFound: _onFound,
          bookingId: widget.bookingId);
    }

    final bookingAsync = ref.watch(singleBookingProvider(widget.bookingId));

    return bookingAsync.when(
      loading: () => _buildSearchingUI(null),
      error: (_, __) => _buildSearchingUI(null),
      data: (booking) {
        if (booking?['provider_id'] != null && booking!['status'] == 'accepted') {
          _onFound();
          return _buildFoundUI(booking);
        }
        if (_timedOut) return _buildTimeoutUI();
        return _buildSearchingUI(booking);
      },
    );
  }

  // ── Buscando ──────────────────────────────────────────────────────────────────
  Widget _buildSearchingUI(Map<String, dynamic>? booking) {
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _RadarWidget(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Text(
                'Si ningún prestador acepta en $_timeoutMinutes minutos,\nte notificaremos cuando uno esté disponible.',
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

  // ── Encontrado ────────────────────────────────────────────────────────────────
  Widget _buildFoundUI(Map<String, dynamic> booking) {
    final providerName = booking['provider_name'] as String? ?? 'Prestador';
    final serviceName = booking['service_name'] as String? ?? 'Servicio';
    final bookingId = booking['id'] as String;

    return Scaffold(
      backgroundColor: AppColors.successLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              ScaleTransition(
                scale: CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 28, spreadRadius: 4,
                    )],
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 72, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 28),
              const Text('¡Prestador encontrado!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('$providerName está en camino',
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  _ConfirmRow(icon: Icons.person_outline, label: 'Prestador', value: providerName),
                  const Divider(height: 20),
                  _ConfirmRow(icon: Icons.home_repair_service_outlined, label: 'Servicio', value: serviceName),
                  const Divider(height: 20),
                  const _ConfirmRow(icon: Icons.bolt_rounded, label: 'Llegada', value: 'Lo antes posible'),
                ]),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Abrir chat con el prestador'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => context.push(
                    '/chat/$bookingId?name=${Uri.encodeComponent(providerName)}&service=${Uri.encodeComponent(serviceName)}'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/bookings'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  // ── Timeout ───────────────────────────────────────────────────────────────────
  Widget _buildTimeoutUI() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 80, color: AppColors.textHint),
              const SizedBox(height: 24),
              const Text('Sin prestadores disponibles',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'No encontramos un prestador disponible ahora mismo en tu área. Tu solicitud quedó guardada y te notificaremos cuando uno esté disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.go('/bookings'), child: const Text('Ver mis solicitudes')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingSummary(Map<String, dynamic> booking) {
    final serviceName = booking['service_name'] as String? ?? '';
    final address = booking['address'] as String? ?? '';

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
          if (serviceName.isNotEmpty) _SummaryRow(icon: Icons.home_repair_service_outlined, text: serviceName),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SummaryRow(icon: Icons.location_on_outlined, text: address),
          ],
          const SizedBox(height: 8),
          const _SummaryRow(icon: Icons.bolt_rounded, text: 'Servicio inmediato'),
        ],
      ),
    );
  }
}

// ── Radar widget (StatefulWidget con su propia animación) ─────────────────────

class _RadarWidget extends StatefulWidget {
  const _RadarWidget();

  @override
  State<_RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<_RadarWidget> with TickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  final List<_Blip> _blips = [];
  Timer? _blipTimer;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Agrega blips aleatorios periódicamente
    _blipTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      final r = 0.35 + _rng.nextDouble() * 0.55;
      final a = _rng.nextDouble() * 2 * math.pi;
      setState(() {
        _blips.add(_Blip(
          position: Offset(r * math.cos(a), r * math.sin(a)),
          born: DateTime.now(),
        ));
        // Elimina blips expirados (>5s)
        _blips.removeWhere(
          (b) => DateTime.now().difference(b.born).inMilliseconds > 5000);
      });
    });
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _blipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweepCtrl,
        builder: (_, __) {
          final now = DateTime.now();
          final blipData = _blips.map((b) {
            final age = now.difference(b.born).inMilliseconds / 5000.0;
            return _BlipData(position: b.position, opacity: (1.0 - age).clamp(0.0, 1.0));
          }).toList();

          return CustomPaint(
            size: const Size(220, 220),
            painter: _RadarPainter(progress: _sweepCtrl.value, blips: blipData),
          );
        },
      ),
    );
  }
}

class _Blip {
  final Offset position; // normalizado -1..1 desde el centro
  final DateTime born;
  const _Blip({required this.position, required this.born});
}

class _BlipData {
  final Offset position;
  final double opacity;
  const _BlipData({required this.position, required this.opacity});
}

// ── Radar painter corregido ───────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double progress;
  final List<_BlipData> blips;

  const _RadarPainter({required this.progress, required this.blips});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Fondo del radar
    canvas.drawCircle(center, radius,
        Paint()..color = AppColors.primary.withValues(alpha: 0.05));

    // Anillos de cuadrícula
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }

    // Líneas de cruz
    final crossPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);

    // Ángulo actual del barrido (comienza a las 12 en punto)
    final angle = progress * 2 * math.pi - math.pi / 2;

    // ── Barrido del radar (canvas.rotate + clipPath) ──────────────────────────
    //
    // Rotamos el canvas para que el borde frontal del barrido quede en angle.
    // El arco va de -sweepArc a 0 en el sistema rotado, que equivale de
    // (angle - sweepArc) a angle en el sistema original. El clip garantiza
    // que solo se pinta el cuadrante del barrido, no todo el círculo.
    const sweepArc = math.pi * 0.55; // ~100° de estela

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final wedge = Path()
      ..moveTo(0, 0)
      ..arcTo(sweepRect, -sweepArc, sweepArc, false)
      ..close();

    canvas.clipPath(wedge);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = SweepGradient(
          startAngle: -sweepArc,
          endAngle: 0,
          colors: [
            Colors.transparent,
            AppColors.primary.withValues(alpha: 0.07),
            AppColors.primary.withValues(alpha: 0.42),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sweepRect),
    );
    canvas.restore();

    // Línea frontal del barrido
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.9)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ── Puntos detectados (blips) ─────────────────────────────────────────────
    for (final blip in blips) {
      final bx = center.dx + blip.position.dx * radius;
      final by = center.dy + blip.position.dy * radius;
      final a = blip.opacity.clamp(0.0, 1.0);

      // Halo exterior
      canvas.drawCircle(Offset(bx, by), 10,
          Paint()..color = AppColors.success.withValues(alpha: a * 0.18));
      // Anillo
      canvas.drawCircle(
        Offset(bx, by), 6,
        Paint()
          ..color = AppColors.success.withValues(alpha: a * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Núcleo
      canvas.drawCircle(Offset(bx, by), 3,
          Paint()..color = AppColors.success.withValues(alpha: a * 0.95));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.blips.length != blips.length;
}

// ── Demo ──────────────────────────────────────────────────────────────────────

class _DemoSearching extends StatefulWidget {
  final AnimationController successCtrl;
  final VoidCallback onFound;
  final String bookingId;

  const _DemoSearching({
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
                  scale: CurvedAnimation(parent: widget.successCtrl, curve: Curves.elasticOut),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 72, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('¡Prestador encontrado!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Juan Pérez aceptó tu solicitud',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Abrir chat con el prestador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.push('/chat/${widget.bookingId}?name=Juan+P%C3%A9rez&service=Servicio'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/bookings'), child: const Text('Ver mis solicitudes')),
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ),
            ),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RadarWidget(),
                  SizedBox(height: 36),
                  Text('Buscando prestador…',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Contactando prestadores disponibles\ncerca de tu área',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ConfirmRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        )),
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
        Expanded(child: Text(text,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
      ],
    );
  }
}
