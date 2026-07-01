import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/help_fab.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    // Vibración doble de éxito. Adultos mayores confirman con el tacto sin
    // necesidad de leer el mensaje, incluso si la pantalla se cargó rápido.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => confirmHaptic());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Ícono de éxito ───────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 72,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 28),

              // ── Título ───────────────────────────────────────────────────
              const Text(
                '¡Solicitud enviada!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Estamos contactando a un prestador disponible en tu área. Te notificaremos en cuanto uno acepte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // ── Pasos siguientes ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Próximos pasos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NextStep(
                      step: 1,
                      icon: Icons.bolt_rounded,
                      title: 'Prestador en camino',
                      subtitle: 'Acepta y se dirige a tu dirección ahora',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    _NextStep(
                      step: 2,
                      icon: Icons.home_work_outlined,
                      title: 'Recibe el servicio',
                      subtitle: 'El profesional llega lo antes posible',
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                    _NextStep(
                      step: 3,
                      icon: Icons.task_alt_rounded,
                      title: 'Paga al finalizar',
                      subtitle: 'Solo cuando el trabajo esté completo',
                      color: AppColors.accent,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Banner de garantía ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 20, color: AppColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu pago está protegido. No se realiza ningún cobro hasta que el servicio sea completado satisfactoriamente.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Acciones ─────────────────────────────────────────────────
              PrimaryButton(
                label: 'Ver mis servicios',
                onPressed: () => context.go('/bookings'),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Volver al inicio',
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _NextStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
