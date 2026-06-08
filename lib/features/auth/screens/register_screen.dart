import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

const List<String> _provinces = [
  'Distrito Nacional',
  'Azua',
  'Baoruco',
  'Barahona',
  'Dajabón',
  'Duarte',
  'Elías Piña',
  'El Seibo',
  'Espaillat',
  'Hato Mayor',
  'Hermanas Mirabal',
  'Independencia',
  'La Altagracia',
  'La Romana',
  'La Vega',
  'María Trinidad Sánchez',
  'Monseñor Nouel',
  'Monte Cristi',
  'Monte Plata',
  'Pedernales',
  'Peravia',
  'Puerto Plata',
  'Samaná',
  'Sánchez Ramírez',
  'San Cristóbal',
  'San José de Ocoa',
  'San Juan',
  'San Pedro de Macorís',
  'Santiago',
  'Santiago Rodríguez',
  'Santo Domingo',
  'Valverde',
];

class RegisterScreen extends ConsumerStatefulWidget {
  final String role;

  const RegisterScreen({super.key, required this.role});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _selectedProvince;
  final _cityCtrl = TextEditingController();
  bool _acceptedTerms = false;

  UserRole get _role =>
      widget.role == 'provider' ? UserRole.provider : UserRole.client;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    await controller.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      role: _role,
      province: _selectedProvince ?? '',
      city: _cityCtrl.text.trim(),
    );

    if (mounted) {
      final state = ref.read(authControllerProvider);
      state.whenOrNull(
        error: (e, _) => _showError(e.toString()),
        data: (_) {
          // If the user got an immediate session (email confirmation off),
          // go directly to the onboarding setup screen.
          // Otherwise, show the "check your email" message and go to login.
          final sessionUser = SupabaseService.currentUser;
          if (sessionUser != null) {
            final dest = _role == UserRole.provider
                ? '/setup-provider'
                : '/setup-client';
            context.go(dest);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '¡Cuenta creada! Revisa tu correo para confirmarla.'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go('/login');
          }
        },
      );
    }
  }

  void _showError(String msg) {
    final e = msg.toLowerCase();
    String message;
    if (e.contains('already registered') || e.contains('user_already_exists')) {
      message = 'Este correo ya tiene una cuenta registrada';
    } else if (e.contains('password') && e.contains('weak')) {
      message = 'La contraseña es muy débil. Usa letras, números y símbolos';
    } else if (e.contains('network') || e.contains('socketexception')) {
      message = 'Sin conexión a internet. Verifica tu red';
    } else if (e.contains('invalid email') || e.contains('invalid_email')) {
      message = 'El formato del correo no es válido';
    } else {
      message = 'Error al crear la cuenta. Inténtalo de nuevo.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final isProvider = _role == UserRole.provider;

    return Scaffold(
      appBar: AppBar(
        title: Text(isProvider ? 'Registro como prestador' : 'Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isProvider) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Como prestador podrás recibir solicitudes de servicio y generar ingresos.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Datos personales',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Nombre completo',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (v) => v == null || v.length < 3
                    ? 'Ingresa tu nombre completo'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Correo electrónico',
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
              const SizedBox(height: 12),
              AppTextField(
                label: 'Teléfono',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length < 8
                    ? 'Número inválido'
                    : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Ubicación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              AppDropdown<String>(
                label: 'Provincia',
                value: _selectedProvince,
                prefixIcon: Icons.location_on_outlined,
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProvince = v),
                validator: (v) => v == null ? 'Selecciona tu provincia' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Ciudad / Cantón',
                controller: _cityCtrl,
                prefixIcon: Icons.location_city_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Seguridad',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Contraseña',
                controller: _passwordCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Mínimo 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirmar contraseña',
                controller: _confirmCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
                validator: (v) {
                  if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // ── Aviso de datos personales ──────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppColors.info, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tus datos personales (cédula, foto, teléfono) son usados únicamente para verificar tu identidad y garantizar la seguridad de todos los usuarios, conforme a la Ley 172-13 de la República Dominicana.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Checkbox T&C ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) =>
                        setState(() => _acceptedTerms = v ?? false),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Acepto los ',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                        children: [
                          TextSpan(
                            text: 'Términos y Condiciones',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final accepted = await context
                                    .push<bool>('/terms?accept=true');
                                if (accepted == true && mounted) {
                                  setState(() => _acceptedTerms = true);
                                }
                              },
                          ),
                          const TextSpan(text: ' y la '),
                          TextSpan(
                            text: 'Política de Privacidad',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.push('/terms'),
                          ),
                          const TextSpan(text: ' de ServiciosYa.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: isProvider
                    ? 'Crear cuenta de prestador'
                    : 'Crear mi cuenta',
                onPressed: _register,
                isLoading: isLoading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes cuenta? ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextLinkButton(
                    label: 'Iniciar sesión',
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
