import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/onboarding_flow/providers/onboarding_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

/// Controla si los botones de Modo Demo son visibles.
/// En producción: false (valor por defecto).
/// Para la demo de inversores: flutter build web --dart-define=SHOW_DEMO=true
const bool kShowDemoButtons =
    bool.fromEnvironment('SHOW_DEMO', defaultValue: false);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (mounted) {
      final state = ref.read(authControllerProvider);
      state.whenOrNull(
        error: (e, _) => _showError(e.toString()),
        data: (_) => _navigateAfterLogin(),
      );
    }
  }

  Future<void> _navigateAfterLogin() async {
    if (!mounted) return;
    final user = SupabaseService.currentUser;
    if (user == null) {
      context.go('/home');
      return;
    }
    // Check if onboarding has been completed
    final done = await isOnboardingComplete(user.id);
    if (!mounted) return;
    if (done) {
      context.go('/home');
      return;
    }
    // Determine role from profiles table
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'] as String? ?? 'client';
      if (!mounted) return;
      if (role == 'provider') {
        context.go('/setup-provider');
      } else {
        context.go('/setup-client');
      }
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_mapError(msg)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _mapError(String error) {
    final e = error.toLowerCase();
    if (e.contains('invalid login credentials') ||
        e.contains('invalid_credentials') ||
        e.contains('wrong password')) {
      return 'Correo o contraseña incorrectos';
    }
    if (e.contains('email not confirmed') || e.contains('email_not_confirmed')) {
      return 'Confirma tu correo electrónico antes de entrar';
    }
    if (e.contains('too many requests') || e.contains('rate_limit')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo';
    }
    if (e.contains('user not found') || e.contains('user_not_found')) {
      return 'No existe una cuenta con ese correo';
    }
    if (e.contains('network') || e.contains('socketexception') ||
        e.contains('connection')) {
      return 'Sin conexión a internet. Verifica tu red';
    }
    return 'Error al iniciar sesión. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SvgPicture.asset(
                        'assets/images/logo.svg',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ServiciosYa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Bienvenido de nuevo',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresa con tu cuenta para continuar',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Correo electrónico',
                      hint: 'tu@correo.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Contraseña',
                      controller: _passwordCtrl,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextLinkButton(
                        label: '¿Olvidaste tu contraseña?',
                        onPressed: () => context.push('/forgot-password'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Iniciar sesión',
                      onPressed: _login,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '¿No tienes cuenta?',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                label: 'Crear cuenta como cliente',
                onPressed: () => context.push('/register?role=client'),
                icon: Icons.person_outlined,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Registrarme como prestador',
                onPressed: () => context.push('/register?role=provider'),
                icon: Icons.work_outline,
              ),
              if (kShowDemoButtons) ...[
                const SizedBox(height: 28),
                _DemoSection(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sección de acceso demo ─────────────────────────────────────
class _DemoSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text(
                  '🎯 Modo Demo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Explora la app sin crear cuenta',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DemoButton(
                label: 'Ver como\nCliente',
                icon: Icons.person,
                color: AppColors.primary,
                onTap: () {
                  enterDemoAsClient(ref);
                  context.go('/home');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DemoButton(
                label: 'Ver como\nPrestador',
                icon: Icons.work,
                color: const Color(0xFF7C3AED),
                onTap: () {
                  enterDemoAsProvider(ref);
                  context.go('/dashboard');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DemoButton(
                label: 'Panel\nAdmin',
                icon: Icons.admin_panel_settings,
                color: AppColors.error,
                onTap: () {
                  enterDemoAsClient(ref);
                  context.go('/admin');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DemoButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
