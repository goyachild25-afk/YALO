import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/onboarding_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SQL ADICIONAL — ejecutar en Supabase SQL Editor si la tabla usa nombres legacy:
//
//   ALTER TABLE verification_requests RENAME COLUMN cedula_number    TO id_number;
//   ALTER TABLE verification_requests RENAME COLUMN cedula_front_url TO id_front_url;
//   ALTER TABLE verification_requests RENAME COLUMN cedula_back_url  TO id_back_url;
//
//   -- Los clientes no proveen foto trasera; hacer nullable:
//   ALTER TABLE verification_requests ALTER COLUMN id_back_url DROP NOT NULL;
// ──────────────────────────────────────────────────────────────────────────────

class ClientOnboardingScreen extends ConsumerStatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  ConsumerState<ClientOnboardingScreen> createState() =>
      _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState
    extends ConsumerState<ClientOnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // ── Paso 0 — Contacto y ubicación ────────────────────────────────────────────
  final _formKey0 = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _province;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _uploadedAvatarUrl;

  // ── Paso 1 — Verificación de identidad ──────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>();
  final _idNumberCtrl = TextEditingController();
  Uint8List? _frontBytes;
  String? _frontExt;
  Uint8List? _selfieBytes;
  String? _selfieExt;

  @override
  void initState() {
    super.initState();
    // Diferir hasta el primer frame para que currentUserProvider tenga tiempo de cargar
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    ref.read(currentUserProvider).whenData(_applyPrefill);
  }

  void _applyPrefill(UserModel? user) {
    if (user == null || !mounted) return;
    bool needsSetState = false;
    // Solo rellenar si el campo está vacío (no pisar lo que el usuario ya escribió)
    if (_phoneCtrl.text.isEmpty && user.phone != null) {
      _phoneCtrl.text = user.phone!;
    }
    if (_cityCtrl.text.isEmpty && user.city != null) {
      _cityCtrl.text = user.city!;
    }
    if (_addressCtrl.text.isEmpty && user.address != null) {
      _addressCtrl.text = user.address!;
    }
    if (_province == null && user.province != null && user.province!.isNotEmpty) {
      _province = user.province;
      needsSetState = true;
    }
    if (needsSetState) setState(() {});
  }

  Future<(Uint8List?, String?)> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return (null, null);
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    return (bytes, ext.isEmpty ? 'jpg' : ext);
  }

  Future<String?> _uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String ext,
  }) async {
    try {
      await SupabaseService.client.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );
      return SupabaseService.client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  // ── Guardar Paso 0 — Contacto y ubicación ────────────────────────────────────
  Future<void> _saveStep0() async {
    if (!_formKey0.currentState!.validate()) return;

    // Modo demo: avanzar sin tocar Supabase
    if (ref.read(demoModeProvider)) {
      _goToStep(1);
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      if (_avatarBytes != null) {
        final ext = _avatarExt ?? 'jpg';
        _uploadedAvatarUrl = await _uploadBytes(
          bucket: 'avatars',
          path: '${user.id}_avatar.$ext',
          bytes: _avatarBytes!,
          ext: ext,
        );
      }

      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',   // CRÍTICO: profiles.email NOT NULL — viene del auth, no del form
        'phone': _phoneCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(currentUserProvider);
      if (mounted) _goToStep(1);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar Paso 1 — Verificación de identidad ───────────────────────────────
  Future<void> _saveStep1() async {
    if (!_formKey1.currentState!.validate()) return;
    if (_frontBytes == null || _selfieBytes == null) {
      _showError('Sube la foto de tu cédula y la selfie para continuar');
      return;
    }

    // Modo demo: completar sin tocar Supabase
    if (ref.read(demoModeProvider)) {
      if (mounted) context.go('/home');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      final frontUrl = await _uploadBytes(
        bucket: 'verification-docs',
        path: '${user.id}/id_front.${_frontExt ?? 'jpg'}',
        bytes: _frontBytes!,
        ext: _frontExt ?? 'jpg',
      );
      final selfieUrl = await _uploadBytes(
        bucket: 'verification-docs',
        path: '${user.id}/selfie.${_selfieExt ?? 'jpg'}',
        bytes: _selfieBytes!,
        ext: _selfieExt ?? 'jpg',
      );

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      // Para clientes: id_back_url = misma foto frontal (no se requiere trasera)
      try {
        await SupabaseService.client.from('verification_requests').upsert({
          'user_id': user.id,
          'full_name': profile?['full_name'] as String? ?? '',
          'id_number': _idNumberCtrl.text.trim(),
          'id_front_url': frontUrl,
          'id_back_url': frontUrl,
          'selfie_url': selfieUrl,
          'status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (_) {
        // Columnas pueden tener nombres legacy (cedula_*) — ignorar y continuar
      }

      await markVerificationSubmitted(user.id);
      await markOnboardingComplete(user.id);
      ref.invalidate(currentUserProvider);

      if (mounted) context.go('/home');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rellenar campos cuando currentUserProvider carga (puede llegar después del primer frame)
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      next.whenData(_applyPrefill);
    });
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ClientHeader(currentStep: _step),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // PASO 1: Contacto y ubicación
                  _ClientStep0(
                    formKey: _formKey0,
                    phoneCtrl: _phoneCtrl,
                    cityCtrl: _cityCtrl,
                    addressCtrl: _addressCtrl,
                    province: _province,
                    avatarBytes: _avatarBytes,
                    saving: _saving,
                    onProvinceChanged: (v) => setState(() => _province = v),
                    onPickAvatar: () async {
                      final (bytes, ext) = await _pickImage();
                      if (bytes != null) {
                        setState(() {
                          _avatarBytes = bytes;
                          _avatarExt = ext;
                        });
                      }
                    },
                    onNext: _saveStep0,
                    // "Completar más tarde" solo aparece en el paso 1
                    onSkip: () async {
                      if (!ref.read(demoModeProvider)) {
                        final user = SupabaseService.currentUser;
                        if (user != null) await markOnboardingComplete(user.id);
                      }
                      if (mounted) context.go('/home'); // ignore: use_build_context_synchronously
                    },
                  ),

                  // PASO 2: Verificación de identidad
                  _ClientStep1(
                    formKey: _formKey1,
                    idNumberCtrl: _idNumberCtrl,
                    frontBytes: _frontBytes,
                    selfieBytes: _selfieBytes,
                    saving: _saving,
                    onPickFront: () async {
                      final (bytes, ext) = await _pickImage();
                      if (bytes != null) {
                        setState(() {
                          _frontBytes = bytes;
                          _frontExt = ext;
                        });
                      }
                    },
                    onPickSelfie: () async {
                      final (bytes, ext) = await _pickImage();
                      if (bytes != null) {
                        setState(() {
                          _selfieBytes = bytes;
                          _selfieExt = ext;
                        });
                      }
                    },
                    onBack: () => _goToStep(0),
                    onFinish: _saveStep1,
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
// HEADER (2 pasos)
// ═════════════════════════════════════════════════════════════════════════════
class _ClientHeader extends StatelessWidget {
  final int currentStep;
  const _ClientHeader({required this.currentStep});

  static const _titles = ['Tu perfil', 'Verificación de identidad'];
  static const _subtitles = ['Paso 1 de 2', 'Paso 2 de 2'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _subtitles[currentStep],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _titles[currentStep],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(2, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= currentStep
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PASO 1 — CONTACTO Y UBICACIÓN
// ═════════════════════════════════════════════════════════════════════════════
class _ClientStep0 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController addressCtrl;
  final String? province;
  final Uint8List? avatarBytes;
  final bool saving;
  final ValueChanged<String?> onProvinceChanged;
  final VoidCallback onPickAvatar;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _ClientStep0({
    required this.formKey,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.addressCtrl,
    required this.province,
    required this.avatarBytes,
    required this.saving,
    required this.onProvinceChanged,
    required this.onPickAvatar,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (opcional)
            Center(
              child: GestureDetector(
                onTap: onPickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primaryLighter,
                      backgroundImage:
                          avatarBytes != null ? MemoryImage(avatarBytes!) : null,
                      child: avatarBytes == null
                          ? const Icon(Icons.person_outline,
                              size: 46, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: onPickAvatar,
                child: const Text('Subir foto de perfil (opcional)',
                    style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),
            const _SectionLabel(label: 'Contacto', icon: Icons.phone_outlined),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Teléfono',
              hint: '8095550000',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.length < 10) ? 'Ingresa 10 dígitos' : null,
            ),
            const SizedBox(height: 20),
            const _SectionLabel(
                label: 'Ubicación', icon: Icons.location_on_outlined),
            const SizedBox(height: 12),
            AppDropdown<String>(
              label: 'Provincia',
              value: province,
              prefixIcon: Icons.map_outlined,
              items: kProvinciasRD
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: onProvinceChanged,
              validator: (v) => v == null ? 'Selecciona tu provincia' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Ciudad / Municipio',
              hint: 'Ej: Piantini, Naco...',
              controller: cityCtrl,
              prefixIcon: Icons.location_city_outlined,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Dirección principal',
              hint: 'Calle, número, sector...',
              controller: addressCtrl,
              prefixIcon: Icons.home_outlined,
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Continuar',
              onPressed: onNext,
              isLoading: saving,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Completar más tarde',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PASO 2 — VERIFICACIÓN DE IDENTIDAD
// ═════════════════════════════════════════════════════════════════════════════
class _ClientStep1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController idNumberCtrl;
  final Uint8List? frontBytes;
  final Uint8List? selfieBytes;
  final bool saving;
  final VoidCallback onPickFront;
  final VoidCallback onPickSelfie;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _ClientStep1({
    required this.formKey,
    required this.idNumberCtrl,
    required this.frontBytes,
    required this.selfieBytes,
    required this.saving,
    required this.onPickFront,
    required this.onPickSelfie,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aviso de seguridad
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Para garantizar la seguridad de los prestadores y cumplir con nuestras políticas, todos los usuarios deben verificar su identidad.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.info, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            AppTextField(
              label: 'Número de cédula dominicana',
              hint: '00000000000 (11 dígitos)',
              controller: idNumberCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.badge_outlined,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v.length != 11) return 'La cédula debe tener 11 dígitos';
                return null;
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'Fotos requeridas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las fotos deben ser claras y legibles.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            _PhotoTile(
              label: 'Foto frontal de la cédula',
              sublabel: 'La cara con tu foto y datos',
              icon: Icons.credit_card_outlined,
              bytes: frontBytes,
              onPick: onPickFront,
            ),
            const SizedBox(height: 10),
            _PhotoTile(
              label: 'Selfie sosteniendo la cédula',
              sublabel: 'Tú con la cédula visible en mano',
              icon: Icons.face_outlined,
              bytes: selfieBytes,
              onPick: onPickSelfie,
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu identidad es verificada por nuestro equipo en 24-48 h hábiles. Esto protege a toda la comunidad ServiciosYa.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Atrás',
                    onPressed: onBack,
                    icon: Icons.arrow_back_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Finalizar',
                    onPressed: onFinish,
                    isLoading: saving,
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS COMPARTIDOS
// ═════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Uint8List? bytes;
  final VoidCallback onPick;

  const _PhotoTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.bytes,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bytes != null ? AppColors.successLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: bytes != null ? AppColors.success : AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: bytes != null
                  ? Image.memory(bytes!, width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56,
                      height: 56,
                      color: AppColors.border,
                      child: Icon(icon, color: AppColors.textHint, size: 26),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              bytes != null ? Icons.check_circle : Icons.upload_rounded,
              color: bytes != null ? AppColors.success : AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
