// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen — ServiciosYa
// Animaciones Lottie en assets/animations/ (generadas con colores de la app)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

// Colores de acento por página
const _kColorPage1 = AppColors.primary;
const _kColorPage2 = AppColors.success; // Verde verificado
const _kColorPage3 = AppColors.accent;  // Naranja pago

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  Color get _activeColor => switch (_currentPage) {
        0 => _kColorPage1,
        1 => _kColorPage2,
        _ => _kColorPage3,
      };

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header marca ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ServiciosYa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Omitir',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),

            // ── Páginas ───────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  _Page1(),
                  _Page2(),
                  _Page3(),
                ],
              ),
            ),

            // ── Controles ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Column(
                children: [
                  // Indicador de página
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: _activeColor,
                      dotColor: AppColors.border,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botones — distintos por página
                  if (!isLast)
                    PrimaryButton(
                      label: _currentPage == 0
                          ? 'Comenzar'
                          : 'Ver prestadores',
                      onPressed: _nextPage,
                    )
                  else ...[
                    PrimaryButton(
                      label: 'Crear cuenta gratis',
                      onPressed: () => context.go('/register?role=client'),
                      icon: Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Entrar como cliente',
                      onPressed: () => context.go('/login'),
                      icon: Icons.login_rounded,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Footer legal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      const Text(
                        'Datos protegidos · Ley 172-13 · Rep. Dominicana',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                    ],
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

// ═════════════════════════════════════════════════════════════════════════════
// PÁGINA 1 — Servicios del hogar
// Lottie sugerido: "Home Service" o "House Cleaning"
//   https://lottiefiles.com/search?q=home+cleaning
//   Guardar como: assets/animations/home_service.json
// ═════════════════════════════════════════════════════════════════════════════
class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final lottieSz = h < 700 ? 150.0 : 190.0;
    final gap1 = h < 700 ? 16.0 : 28.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/home_service.json',
            width: lottieSz,
            height: lottieSz,
            fit: BoxFit.contain,
            repeat: true,
          ),
          SizedBox(height: gap1),

          // Badge — país
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _kColorPage1.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'República Dominicana 🇩🇴',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kColorPage1,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Servicios del hogar,\nal alcance de tu mano',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Encuentra prestadores verificados en tu zona,\ncuando los necesitas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PÁGINA 2 — Prestadores calificados
// Lottie sugerido: "Team Work" o "People Rating"
//   https://lottiefiles.com/search?q=team+verified
//   Guardar como: assets/animations/team_verified.json
// ═════════════════════════════════════════════════════════════════════════════
class _Page2 extends StatelessWidget {
  const _Page2();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final lottieSz = h < 700 ? 150.0 : 190.0;
    final gap1 = h < 700 ? 16.0 : 28.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/team_verified.json',
            width: lottieSz,
            height: lottieSz,
            fit: BoxFit.contain,
            repeat: true,
          ),
          SizedBox(height: gap1),

          const Text(
            'Prestadores reales,\ncalificados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cada perfil con foto, reseñas y\ntrayectoria verificada.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Chips de confianza
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _TrustChip(
                icon: Icons.badge_outlined,
                label: 'Cédula verificada',
                color: _kColorPage2,
              ),
              SizedBox(width: 10),
              _TrustChip(
                icon: Icons.star_rounded,
                label: 'Reseñas reales',
                color: AppColors.star,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _TrustChip(
                icon: Icons.photo_camera_outlined,
                label: 'Foto de perfil',
                color: AppColors.secondary,
              ),
              SizedBox(width: 10),
              _TrustChip(
                icon: Icons.check_circle_outline,
                label: '500+ activos',
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PÁGINA 3 — Tu pago, protegido
// Lottie sugerido: "Shield Security" o "Payment Protection"
//   https://lottiefiles.com/search?q=shield+security
//   Guardar como: assets/animations/shield_security.json
// ═════════════════════════════════════════════════════════════════════════════
class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          Lottie.asset(
            'assets/animations/shield_security.json',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            repeat: true,
          ),
          const SizedBox(height: 28),

          const Text(
            'Tu pago, protegido',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Solo pagas cuando el servicio está terminado\ny eres tú quien lo confirma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),

          // ── 3 pasos del proceso de pago ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              children: [
                _PaymentStep(
                  number: '1',
                  label: 'Reserva y acuerda el precio',
                  icon: Icons.handshake_outlined,
                  color: _kColorPage1,
                  isLast: false,
                ),
                _PaymentStep(
                  number: '2',
                  label: 'El prestador realiza el trabajo',
                  icon: Icons.home_repair_service_outlined,
                  color: _kColorPage2,
                  isLast: false,
                ),
                _PaymentStep(
                  number: '3',
                  label: 'Tú confirmas y el pago se libera',
                  icon: Icons.task_alt_rounded,
                  color: _kColorPage3,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═════════════════════════════════════════════════════════════════════════════

/// Chip pequeño con ícono y etiqueta para la página 2.
class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrustChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un paso del flujo de pago en la página 3.
class _PaymentStep extends StatelessWidget {
  final String number;
  final String label;
  final IconData icon;
  final Color color;
  final bool isLast;

  const _PaymentStep({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Número + línea vertical
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 22,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: AppColors.divider,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Contenido
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
