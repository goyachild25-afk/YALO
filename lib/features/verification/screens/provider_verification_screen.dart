import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class ProviderVerificationScreen extends ConsumerStatefulWidget {
  const ProviderVerificationScreen({super.key});

  @override
  ConsumerState<ProviderVerificationScreen> createState() =>
      _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState
    extends ConsumerState<ProviderVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  XFile? _idFrontPhoto;
  XFile? _idBackPhoto;
  XFile? _selfiePhoto;
  bool _isSaving = false;

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String type) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() {
      if (type == 'front') _idFrontPhoto = file;
      if (type == 'back') _idBackPhoto = file;
      if (type == 'selfie') _selfiePhoto = file;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idFrontPhoto == null || _idBackPhoto == null || _selfiePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube las 3 fotos requeridas'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final isDemo = ref.read(demoModeProvider);
    if (isDemo) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showSuccessDialog();
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      final user = SupabaseService.currentUser!;

      // Subir fotos a Supabase Storage
      final frontBytes = await _idFrontPhoto!.readAsBytes();
      final backBytes = await _idBackPhoto!.readAsBytes();
      final selfieBytes = await _selfiePhoto!.readAsBytes();

      final frontUrl = await SupabaseService.uploadFile(
        bucket: 'verification-docs',
        path: '${user.id}/id_front.jpg',
        bytes: frontBytes,
      );
      final backUrl = await SupabaseService.uploadFile(
        bucket: 'verification-docs',
        path: '${user.id}/id_back.jpg',
        bytes: backBytes,
      );
      final selfieUrl = await SupabaseService.uploadFile(
        bucket: 'verification-docs',
        path: '${user.id}/selfie.jpg',
        bytes: selfieBytes,
      );

      // Guardar en base de datos
      await SupabaseService.client.from('verification_requests').upsert({
        'user_id': user.id,
        'id_number': _idNumberCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'id_front_url': frontUrl,
        'id_back_url': backUrl,
        'selfie_url': selfieUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      await SupabaseService.client
          .from('provider_profiles')
          .update({'bio': _bioCtrl.text.trim()}).eq('user_id', user.id);

      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Solicitud enviada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu documentación fue enviada. El equipo de ServiciosYa la revisará en 24-48 horas. Te notificaremos por correo cuando tu cuenta esté verificada.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/dashboard');
              },
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar mi identidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner explicativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Por qué verificamos tu identidad?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Para proteger a los clientes y darte el badge "Verificado" que aumenta tus solicitudes.',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pasos
              _StepLabel(number: '1', label: 'Información básica'),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Número de cédula',
                hint: '0-0000-0000',
                controller: _idNumberCtrl,
                prefixIcon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Cuéntanos sobre ti',
                hint: 'Experiencia, especialidades, por qué confiar en ti...',
                controller: _bioCtrl,
                maxLines: 4,
                prefixIcon: Icons.person_outline,
                validator: (v) => v == null || v.length < 20
                    ? 'Escribe al menos 20 caracteres'
                    : null,
              ),
              const SizedBox(height: 24),

              _StepLabel(number: '2', label: 'Foto de tu cédula'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoPicker(
                      label: 'Frente',
                      icon: Icons.credit_card,
                      file: _idFrontPhoto,
                      onTap: () => _pickPhoto('front'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoPicker(
                      label: 'Reverso',
                      icon: Icons.credit_card_outlined,
                      file: _idBackPhoto,
                      onTap: () => _pickPhoto('back'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _StepLabel(number: '3', label: 'Selfie sosteniendo tu cédula'),
              const SizedBox(height: 4),
              const Text(
                'Toma una foto tuya sosteniendo tu cédula para confirmar que eres tú.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _PhotoPicker(
                label: 'Selfie con cédula',
                icon: Icons.face_outlined,
                file: _selfiePhoto,
                onTap: () => _pickPhoto('selfie'),
                fullWidth: true,
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Enviar verificación',
                onPressed: _submit,
                isLoading: _isSaving,
                icon: Icons.send_outlined,
              ),
              const SizedBox(height: 12),
              const Text(
                '🔒 Tus documentos están protegidos y solo son accesibles por el equipo de ServiciosYa.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String label;
  const _StepLabel({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final XFile? file;
  final VoidCallback onTap;
  final bool fullWidth;

  const _PhotoPicker({
    required this.label,
    required this.icon,
    this.file,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: fullWidth ? 120 : 110,
        width: fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: picked ? AppColors.successLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: picked ? AppColors.success : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              picked ? Icons.check_circle : icon,
              size: 32,
              color: picked ? AppColors.success : AppColors.textHint,
            ),
            const SizedBox(height: 6),
            Text(
              picked ? 'Foto cargada ✓' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: picked ? AppColors.success : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!picked)
              const Text(
                'Toca para subir',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}
