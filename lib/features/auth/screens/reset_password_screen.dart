import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

/// Pantalla destino del enlace "olvidé mi contraseña" del correo.
///
/// Supabase entrega la sesión de recuperación directamente en la URL antes de
/// que esta pantalla se muestre (el SDK la captura sola al inicializar, vía
/// `detectSessionInUri`). Aquí solo verificamos que esa sesión exista — si el
/// usuario llegó a esta ruta sin pasar por un enlace de recuperación válido
/// (link vencido, reabierto en otro navegador, etc.), se lo indicamos en vez
/// de mostrar un formulario que fallaría al guardar.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;
  bool _done = false;
  bool _hasRecoverySession = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() {
    final isDemo = ref.read(demoModeProvider);
    setState(() {
      _hasRecoverySession = isDemo || SupabaseService.currentUser != null;
      _checked = true;
    });
  }

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
      // Cierra la sesión de recuperación: el usuario debe entrar de nuevo
      // con su contraseña nueva, como cualquier login normal.
      await SupabaseService.signOut();
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
        title: const Text('Restablecer contraseña'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: !_checked
              ? const Center(child: CircularProgressIndicator())
              : _done
                  ? _buildSuccess()
                  : _hasRecoverySession
                      ? _buildForm()
                      : _buildInvalidLink(),
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
                Icons.lock_reset_outlined,
                size: 38,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Crea tu nueva contraseña',
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
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Guardar nueva contraseña',
            onPressed: _save,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidLink() {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.warningLight,
            child: Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.warning),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Enlace vencido o inválido',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Este enlace de recuperación ya fue usado o expiró.\n'
          'Solicita uno nuevo desde la pantalla de inicio de sesión.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Solicitar nuevo enlace',
          onPressed: () => context.go('/forgot-password'),
        ),
      ],
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
          'Ya puedes iniciar sesión con tu nueva contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Ir a iniciar sesión',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
