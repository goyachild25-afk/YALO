import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;
  bool _done = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final isDemo = ref.read(demoModeProvider);
      if (isDemo) {
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() => _done = true);
        return;
      }

      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _newCtrl.text),
      );
      setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _done ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 38,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Nueva contraseña',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Elige una contraseña segura de al menos 8 caracteres.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AppTextField(
            label: 'Nueva contraseña',
            controller: _newCtrl,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (v.length < 8) return 'Mínimo 8 caracteres';
              if (!v.contains(RegExp(r'[A-Z]'))) {
                return 'Debe incluir al menos una mayúscula';
              }
              if (!v.contains(RegExp(r'[0-9]'))) {
                return 'Debe incluir al menos un número';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirmar contraseña',
            controller: _confirmCtrl,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (v != _newCtrl.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Indicador de seguridad
          _PasswordStrengthBar(password: _newCtrl.text),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Cambiar contraseña',
            onPressed: _save,
            isLoading: _isSaving,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Cancelar',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.successLight,
            child: Icon(Icons.check_circle_outline,
                size: 56, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '¡Contraseña actualizada!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Tu contraseña fue cambiada con éxito.\nUsa la nueva la próxima vez que inicies sesión.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Listo',
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

// ── Barra de fortaleza de contraseña ─────────────────────────────────────────
class _PasswordStrengthBar extends StatefulWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  @override
  State<_PasswordStrengthBar> createState() => _PasswordStrengthBarState();
}

class _PasswordStrengthBarState extends State<_PasswordStrengthBar> {
  @override
  Widget build(BuildContext context) {
    final p = widget.password;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) score++;

    Color barColor;
    String label;
    switch (score) {
      case 0:
      case 1:
        barColor = AppColors.error;
        label = 'Débil';
      case 2:
        barColor = AppColors.warning;
        label = 'Regular';
      case 3:
        barColor = AppColors.info;
        label = 'Buena';
      default:
        barColor = AppColors.success;
        label = 'Excelente';
    }

    if (p.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fortaleza:',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: barColor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < score ? barColor : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
