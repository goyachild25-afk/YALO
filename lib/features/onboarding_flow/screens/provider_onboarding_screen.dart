import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/onboarding_provider.dart';

// ── Modelo local de configuración de precio por categoría ────────────────────
class _ServiceConfig {
  String pricingType = 'fixed'; // 'fixed' | 'quote'
  String price = '';
  String description = '';
}

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  ConsumerState<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState
    extends ConsumerState<ProviderOnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // ── Paso 0 — Información personal ────────────────────────────────────────────
  final _formKey0 = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _province;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _uploadedAvatarUrl;

  // ── Paso 1 — Verificación de identidad ──────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>();
  final _idNumberCtrl = TextEditingController();
  Uint8List? _frontBytes;
  String? _frontExt;
  Uint8List? _backBytes;
  String? _backExt;
  Uint8List? _selfieBytes;
  String? _selfieExt;

  // ── Paso 2 — Cuestionario de servicios ──────────────────────────────────────
  // { categoryId → { questionKey → bool } }
  final Map<String, Map<String, bool>> _questAnswers = {};
  final _otherDescCtrl = TextEditingController();

  // ── Paso 3 — Configuración de precios ────────────────────────────────────────
  // Solo muestra las categorías habilitadas en el paso 2
  final Map<String, _ServiceConfig> _serviceConfigs = {};

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS — tipos de pregunta 2 por categoría
  // ─────────────────────────────────────────────────────────────────────────────
  static const _withTools = {
    'plumbing', 'electrical', 'painting', 'carpentry',
    'pest_control', 'ac_service', 'appliance_repair',
  };
  static const _withMaterials = {
    'home_cleaning', 'office_cleaning', 'laundry',
  };
  static const _withReferences = {
    'pet_care', 'babysitting', 'elderly_care',
  };

  static String _q2Label(String catId) {
    if (_withTools.contains(catId)) return '¿Tienes herramientas y equipos propios?';
    if (_withMaterials.contains(catId)) return '¿Tienes materiales y productos de limpieza?';
    if (_withReferences.contains(catId)) return '¿Tienes referencias o formación verificable?';
    return '¿Puedes brindar este servicio de forma independiente?';
  }

  static String _q2Key(String catId) {
    if (_withTools.contains(catId)) return 'herramientas';
    if (_withMaterials.contains(catId)) return 'materiales';
    if (_withReferences.contains(catId)) return 'referencias';
    return 'independiente';
  }

  /// Categorías habilitadas (≥1 respuesta "Sí" en sus preguntas)
  Set<String> get _enabledCategories {
    final enabled = <String>{};
    for (final cat in kServiceCategories) {
      final id = cat['id']!;
      if (_questAnswers[id]?.values.any((v) => v) ?? false) {
        enabled.add(id);
      }
    }
    if (_questAnswers['other']?['independiente'] == true) {
      enabled.add('other');
    }
    return enabled;
  }

  /// Construye el JSON de respuestas para provider_profiles.onboarding_answers
  Map<String, dynamic> _buildAnswersJson() {
    final result = <String, dynamic>{};
    for (final cat in kServiceCategories) {
      final id = cat['id']!;
      final answers = _questAnswers[id];
      if (answers != null && answers.isNotEmpty) {
        final q2 = _q2Key(id);
        result[id] = {
          'experiencia': answers['experiencia'] ?? false,
          q2: answers[q2] ?? false,
          'enabled': answers.values.any((v) => v),
        };
      }
    }
    final otherAnswers = _questAnswers['other'];
    final otherDesc = _otherDescCtrl.text.trim();
    if (otherAnswers != null || otherDesc.isNotEmpty) {
      result['other'] = {
        'independiente': otherAnswers?['independiente'] ?? false,
        'description': otherDesc,
        'enabled': otherAnswers?['independiente'] == true,
      };
    }
    return result;
  }

  /// Sincroniza _serviceConfigs con las categorías habilitadas actuales
  void _initServiceConfigs() {
    final enabled = _enabledCategories;
    _serviceConfigs.removeWhere((id, _) => !enabled.contains(id));
    for (final id in enabled) {
      _serviceConfigs.putIfAbsent(id, () => _ServiceConfig());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    _idNumberCtrl.dispose();
    _otherDescCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    ref.read(currentUserProvider).whenData((user) {
      if (user == null) return;
      if (_fullNameCtrl.text.isEmpty) _fullNameCtrl.text = user.fullName;
      if (user.phone != null) _phoneCtrl.text = user.phone!;
      if (user.city != null) _cityCtrl.text = user.city!;
      if (user.province != null && user.province!.isNotEmpty) {
        setState(() => _province = user.province);
      }
    });
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

  // ── Guardar Paso 0 — Información personal ────────────────────────────────────
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

      final fullName = _fullNameCtrl.text.trim();

      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'phone': _phoneCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await SupabaseService.client.from('provider_profiles').upsert({
        'user_id': user.id,
        'full_name': fullName,
        'bio': _bioCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

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
    if (_frontBytes == null || _backBytes == null || _selfieBytes == null) {
      _showError('Sube las 3 fotos requeridas para continuar');
      return;
    }

    // Modo demo: avanzar sin tocar Supabase
    if (ref.read(demoModeProvider)) {
      _goToStep(2);
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
      final backUrl = await _uploadBytes(
        bucket: 'verification-docs',
        path: '${user.id}/id_back.${_backExt ?? 'jpg'}',
        bytes: _backBytes!,
        ext: _backExt ?? 'jpg',
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

      try {
        await SupabaseService.client.from('verification_requests').upsert({
          'user_id': user.id,
          'full_name': profile?['full_name'] as String? ?? _fullNameCtrl.text.trim(),
          'id_number': _idNumberCtrl.text.trim(),
          'id_front_url': frontUrl,
          'id_back_url': backUrl,
          'selfie_url': selfieUrl,
          'status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (_) {
        // Columnas pueden tener nombres legacy (cedula_*) — ignorar y continuar
      }

      if (mounted) _goToStep(2);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar Paso 2 — Cuestionario ────────────────────────────────────────────
  Future<void> _saveStep2() async {
    if (_enabledCategories.isEmpty) {
      _showError('Responde "Sí" a al menos una pregunta para habilitar categorías');
      return;
    }

    // Modo demo: avanzar sin tocar Supabase
    if (ref.read(demoModeProvider)) {
      setState(() => _initServiceConfigs());
      _goToStep(3);
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      // Guardar respuestas del cuestionario en provider_profiles
      try {
        await SupabaseService.client.from('provider_profiles').upsert({
          'user_id': user.id,
          'onboarding_answers': _buildAnswersJson(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (_) {
        // Columna onboarding_answers no existe si migration_v2 no se ejecutó
      }

      if (mounted) {
        setState(() => _initServiceConfigs());
        _goToStep(3);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar Paso 3 — Configuración de precios ─────────────────────────────────
  Future<void> _saveStep3() async {
    // Validar que todos los servicios fijos tengan precio
    for (final id in _enabledCategories) {
      final cfg = _serviceConfigs[id] ?? _ServiceConfig();
      if (cfg.pricingType == 'fixed') {
        final p = double.tryParse(cfg.price);
        if (p == null || p <= 0) {
          _showError('Ingresa un precio válido para todos los servicios de precio fijo');
          return;
        }
      }
    }

    // Modo demo: finalizar sin tocar Supabase
    if (ref.read(demoModeProvider)) {
      if (mounted) context.go('/dashboard');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      final profileRow = await SupabaseService.client
          .from('provider_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRow == null) {
        _showError('No se encontró tu perfil de prestador');
        return;
      }
      final providerId = profileRow['id'] as String;

      // Eliminar servicios anteriores
      await SupabaseService.client
          .from('provider_services')
          .delete()
          .eq('provider_id', providerId);

      // Construir filas para las categorías estándar habilitadas
      const uuid = Uuid();
      final rows = <Map<String, dynamic>>[];

      for (final id in _enabledCategories) {
        final cfg = _serviceConfigs[id] ?? _ServiceConfig();

        if (id == 'other') {
          // Categoría "Otro" — nombre libre desde el cuestionario
          rows.add({
            'id': uuid.v4(),
            'provider_id': providerId,
            'category_id': 'other',
            'category_name': _otherDescCtrl.text.trim().isNotEmpty
                ? _otherDescCtrl.text.trim()
                : 'Otro servicio',
            'pricing_type': cfg.pricingType,
            'fixed_price': cfg.pricingType == 'fixed'
                ? double.tryParse(cfg.price) ?? 0.0
                : null,
            'price_description': cfg.description.trim(),
            'form_fields': <dynamic>[],
          });
        } else {
          final cat = kServiceCategories.firstWhere((c) => c['id'] == id);
          rows.add({
            'id': uuid.v4(),
            'provider_id': providerId,
            'category_id': id,
            'category_name': cat['name'],
            'pricing_type': cfg.pricingType,
            'fixed_price': cfg.pricingType == 'fixed'
                ? double.tryParse(cfg.price) ?? 0.0
                : null,
            'price_description': cfg.description.trim(),
            'form_fields': <dynamic>[],
          });
        }
      }

      if (rows.isNotEmpty) {
        await SupabaseService.client.from('provider_services').insert(rows);
      }

      await markVerificationSubmitted(user.id);
      await markOnboardingComplete(user.id);
      ref.invalidate(currentUserProvider);

      if (mounted) context.go('/dashboard');
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProviderHeader(currentStep: _step),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // PASO 1: Información personal
                  _Step0PersonalInfo(
                    formKey: _formKey0,
                    fullNameCtrl: _fullNameCtrl,
                    phoneCtrl: _phoneCtrl,
                    cityCtrl: _cityCtrl,
                    bioCtrl: _bioCtrl,
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
                  ),

                  // PASO 2: Verificación de identidad
                  _Step1Verification(
                    formKey: _formKey1,
                    idNumberCtrl: _idNumberCtrl,
                    frontBytes: _frontBytes,
                    backBytes: _backBytes,
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
                    onPickBack: () async {
                      final (bytes, ext) = await _pickImage();
                      if (bytes != null) {
                        setState(() {
                          _backBytes = bytes;
                          _backExt = ext;
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
                    onNext: _saveStep1,
                  ),

                  // PASO 3: Cuestionario de servicios
                  _Step2Questionnaire(
                    questAnswers: _questAnswers,
                    otherDescCtrl: _otherDescCtrl,
                    enabledCount: _enabledCategories.length,
                    saving: _saving,
                    q2Label: _q2Label,
                    q2Key: _q2Key,
                    onAnswerChanged: (catId, qKey, value) {
                      setState(() {
                        _questAnswers.putIfAbsent(catId, () => {});
                        _questAnswers[catId]![qKey] = value;
                      });
                    },
                    onBack: () => _goToStep(1),
                    onNext: _saveStep2,
                  ),

                  // PASO 4: Configuración de precios
                  _Step3Pricing(
                    enabledCategories: _enabledCategories,
                    serviceConfigs: _serviceConfigs,
                    otherDesc: _otherDescCtrl.text.trim(),
                    saving: _saving,
                    onConfigChanged: (id, cfg) {
                      setState(() => _serviceConfigs[id] = cfg);
                    },
                    onBack: () => _goToStep(2),
                    onFinish: _saveStep3,
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
// HEADER — 4 pasos
// ═════════════════════════════════════════════════════════════════════════════
class _ProviderHeader extends StatelessWidget {
  final int currentStep;
  const _ProviderHeader({required this.currentStep});

  static const _titles = [
    'Información personal',
    'Verificación de identidad',
    'Cuestionario de servicios',
    'Configuración de precios',
  ];
  static const _subtitles = [
    'Paso 1 de 4',
    'Paso 2 de 4',
    'Paso 3 de 4',
    'Paso 4 de 4',
  ];

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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
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
// PASO 1 — INFORMACIÓN PERSONAL
// ═════════════════════════════════════════════════════════════════════════════
class _Step0PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController bioCtrl;
  final String? province;
  final Uint8List? avatarBytes;
  final bool saving;
  final ValueChanged<String?> onProvinceChanged;
  final VoidCallback onPickAvatar;
  final VoidCallback onNext;

  const _Step0PersonalInfo({
    required this.formKey,
    required this.fullNameCtrl,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.bioCtrl,
    required this.province,
    required this.avatarBytes,
    required this.saving,
    required this.onProvinceChanged,
    required this.onPickAvatar,
    required this.onNext,
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
                      radius: 50,
                      backgroundColor: AppColors.primaryLighter,
                      backgroundImage: avatarBytes != null
                          ? MemoryImage(avatarBytes!)
                          : null,
                      child: avatarBytes == null
                          ? const Icon(Icons.person_outline,
                              size: 48, color: AppColors.primary)
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
                            size: 16, color: Colors.white),
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

            AppTextField(
              label: 'Nombre completo',
              hint: 'Tu nombre como aparecerá en la app',
              controller: fullNameCtrl,
              prefixIcon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
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
              label: 'Descripción personal / Bio',
              hint:
                  'Cuéntanos sobre ti, tu experiencia y por qué los clientes deberían contratarte...',
              controller: bioCtrl,
              maxLines: 4,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (v.trim().length < 80) {
                  return 'Mínimo 80 caracteres (${v.trim().length}/80)';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: bioCtrl,
              builder: (_, val, __) {
                final count = val.text.trim().length;
                return Text(
                  '$count caracteres',
                  style: TextStyle(
                    fontSize: 11,
                    color: count >= 80 ? AppColors.success : AppColors.textHint,
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Continuar',
              onPressed: onNext,
              isLoading: saving,
              icon: Icons.arrow_forward_rounded,
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
class _Step1Verification extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController idNumberCtrl;
  final Uint8List? frontBytes;
  final Uint8List? backBytes;
  final Uint8List? selfieBytes;
  final bool saving;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onPickSelfie;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step1Verification({
    required this.formKey,
    required this.idNumberCtrl,
    required this.frontBytes,
    required this.backBytes,
    required this.selfieBytes,
    required this.saving,
    required this.onPickFront,
    required this.onPickBack,
    required this.onPickSelfie,
    required this.onBack,
    required this.onNext,
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu identidad es verificada por nuestro equipo en 24-48 h hábiles. Esto protege a toda la comunidad ServiciosYa.',
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
              'Fotos de identificación',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las fotos deben ser claras, bien iluminadas y legibles.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            _PhotoTile(
              label: 'Foto frontal de la cédula',
              sublabel: 'La cara con tu foto y datos personales',
              icon: Icons.credit_card_outlined,
              bytes: frontBytes,
              onPick: onPickFront,
            ),
            const SizedBox(height: 10),
            _PhotoTile(
              label: 'Foto trasera de la cédula',
              sublabel: 'La cara con el código de barras',
              icon: Icons.credit_card,
              bytes: backBytes,
              onPick: onPickBack,
            ),
            const SizedBox(height: 10),
            _PhotoTile(
              label: 'Selfie sosteniendo la cédula',
              sublabel: 'Tú con la cédula visible en mano',
              icon: Icons.face_outlined,
              bytes: selfieBytes,
              onPick: onPickSelfie,
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
                    label: 'Continuar',
                    onPressed: onNext,
                    isLoading: saving,
                    icon: Icons.arrow_forward_rounded,
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
// PASO 3 — CUESTIONARIO DE SERVICIOS
// ═════════════════════════════════════════════════════════════════════════════
class _Step2Questionnaire extends StatelessWidget {
  final Map<String, Map<String, bool>> questAnswers;
  final TextEditingController otherDescCtrl;
  final int enabledCount;
  final bool saving;
  final String Function(String catId) q2Label;
  final String Function(String catId) q2Key;
  final void Function(String catId, String qKey, bool value) onAnswerChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2Questionnaire({
    required this.questAnswers,
    required this.otherDescCtrl,
    required this.enabledCount,
    required this.saving,
    required this.q2Label,
    required this.q2Key,
    required this.onAnswerChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de progreso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: enabledCount > 0
                  ? AppColors.successLight
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabledCount > 0 ? AppColors.success : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  enabledCount > 0
                      ? Icons.check_circle_outline
                      : Icons.quiz_outlined,
                  color: enabledCount > 0 ? AppColors.success : AppColors.textHint,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabledCount > 0
                        ? '$enabledCount ${enabledCount == 1 ? "servicio habilitado" : "servicios habilitados"}'
                        : 'Responde las preguntas para habilitar categorías',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: enabledCount > 0
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo podrás ofrecer servicios en las categorías donde respondas "Sí" a al menos una pregunta.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Tarjetas por categoría
          ...kServiceCategories.map((cat) {
            final id = cat['id']!;
            final answers = questAnswers[id] ?? {};
            final isEnabled = answers.values.any((v) => v);
            return _CategoryQuestionCard(
              emoji: cat['emoji']!,
              name: cat['name']!,
              isEnabled: isEnabled,
              q1Answer: answers['experiencia'],
              q2Answer: answers[q2Key(id)],
              q2LabelText: q2Label(id),
              onQ1Changed: (v) => onAnswerChanged(id, 'experiencia', v),
              onQ2Changed: (v) => onAnswerChanged(id, q2Key(id), v),
            );
          }),

          // Categoría especial "Otro"
          _OtherServiceCard(
            answers: questAnswers['other'] ?? {},
            descCtrl: otherDescCtrl,
            isEnabled: questAnswers['other']?['independiente'] == true,
            onAnswerChanged: (v) =>
                onAnswerChanged('other', 'independiente', v),
          ),

          // Resumen de habilitados
          if (enabledCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habilitaste $enabledCount ${enabledCount == 1 ? "servicio" : "servicios"}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...kServiceCategories.where((c) {
                        final answers = questAnswers[c['id']!] ?? {};
                        return answers.values.any((v) => v);
                      }).map((c) => Text(c['emoji']!,
                          style: const TextStyle(fontSize: 20))),
                      if (questAnswers['other']?['independiente'] == true)
                        const Text('🔧', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
          ],

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
                  label: 'Continuar',
                  onPressed: onNext,
                  isLoading: saving,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Tarjeta de preguntas por categoría ──────────────────────────────────────
class _CategoryQuestionCard extends StatelessWidget {
  final String emoji;
  final String name;
  final bool isEnabled;
  final bool? q1Answer;
  final bool? q2Answer;
  final String q2LabelText;
  final ValueChanged<bool> onQ1Changed;
  final ValueChanged<bool> onQ2Changed;

  const _CategoryQuestionCard({
    required this.emoji,
    required this.name,
    required this.isEnabled,
    required this.q1Answer,
    required this.q2Answer,
    required this.q2LabelText,
    required this.onQ1Changed,
    required this.onQ2Changed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.successLight.withValues(alpha: 0.3)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled ? AppColors.success : AppColors.divider,
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (isEnabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('✓ Habilitado',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          _QuestionRow(
            text: '¿Tienes experiencia comprobable en este servicio?',
            answer: q1Answer,
            onChanged: onQ1Changed,
          ),
          const SizedBox(height: 8),
          _QuestionRow(
            text: q2LabelText,
            answer: q2Answer,
            onChanged: onQ2Changed,
          ),
        ],
      ),
    );
  }
}

// ─── Categoría especial "Otro" ────────────────────────────────────────────────
class _OtherServiceCard extends StatelessWidget {
  final Map<String, bool> answers;
  final TextEditingController descCtrl;
  final bool isEnabled;
  final ValueChanged<bool> onAnswerChanged;

  const _OtherServiceCard({
    required this.answers,
    required this.descCtrl,
    required this.isEnabled,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.successLight.withValues(alpha: 0.3)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled ? AppColors.success : AppColors.divider,
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔧', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Otro servicio',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (isEnabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('✓ Habilitado',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Describe el servicio que ofreces',
              hintText: 'Ej: Diseño de interiores, fotografía de eventos...',
              hintStyle: const TextStyle(fontSize: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          _QuestionRow(
            text: '¿Puedes brindar este servicio de forma profesional?',
            answer: answers['independiente'],
            onChanged: onAnswerChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Fila de pregunta con chips Sí/No ────────────────────────────────────────
class _QuestionRow extends StatelessWidget {
  final String text;
  final bool? answer;
  final ValueChanged<bool> onChanged;

  const _QuestionRow({
    required this.text,
    required this.answer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
        const SizedBox(height: 6),
        Row(
          children: [
            _YesNoChip(
              label: 'Sí',
              selected: answer == true,
              isYes: true,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 8),
            _YesNoChip(
              label: 'No',
              selected: answer == false,
              isYes: false,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Chip Sí / No ─────────────────────────────────────────────────────────────
class _YesNoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isYes;
  final VoidCallback onTap;

  const _YesNoChip({
    required this.label,
    required this.selected,
    required this.isYes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isYes ? AppColors.success : AppColors.error;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PASO 4 — CONFIGURACIÓN DE PRECIOS
// ═════════════════════════════════════════════════════════════════════════════
class _Step3Pricing extends StatelessWidget {
  final Set<String> enabledCategories;
  final Map<String, _ServiceConfig> serviceConfigs;
  final String otherDesc;
  final bool saving;
  final void Function(String id, _ServiceConfig cfg) onConfigChanged;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _Step3Pricing({
    required this.enabledCategories,
    required this.serviceConfigs,
    required this.otherDesc,
    required this.saving,
    required this.onConfigChanged,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configura el precio de cada servicio que vas a ofrecer.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),

          // Tarjetas de configuración para categorías habilitadas
          ...enabledCategories.map((id) {
            String emoji, name;
            if (id == 'other') {
              emoji = '🔧';
              name = otherDesc.isNotEmpty ? otherDesc : 'Otro servicio';
            } else {
              final cat = kServiceCategories.firstWhere((c) => c['id'] == id);
              emoji = cat['emoji']!;
              name = cat['name']!;
            }
            final cfg = serviceConfigs[id] ?? _ServiceConfig();
            return _ServiceConfigCard(
              emoji: emoji,
              categoryName: name,
              config: cfg,
              onChanged: (updated) => onConfigChanged(id, updated),
            );
          }),

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
    );
  }
}

// ─── Tarjeta de configuración por servicio ────────────────────────────────────
class _ServiceConfigCard extends StatefulWidget {
  final String emoji;
  final String categoryName;
  final _ServiceConfig config;
  final ValueChanged<_ServiceConfig> onChanged;

  const _ServiceConfigCard({
    required this.emoji,
    required this.categoryName,
    required this.config,
    required this.onChanged,
  });

  @override
  State<_ServiceConfigCard> createState() => _ServiceConfigCardState();
}

class _ServiceConfigCardState extends State<_ServiceConfigCard> {
  late _ServiceConfig _cfg;
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config;
    _priceCtrl = TextEditingController(text: _cfg.price);
    _descCtrl = TextEditingController(text: _cfg.description);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(_cfg);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.categoryName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tipo de precio',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              _PriceTypeChip(
                label: 'Precio fijo',
                selected: _cfg.pricingType == 'fixed',
                onTap: () {
                  setState(() => _cfg.pricingType = 'fixed');
                  _notify();
                },
              ),
              const SizedBox(width: 8),
              _PriceTypeChip(
                label: 'Por cotización',
                selected: _cfg.pricingType == 'quote',
                onTap: () {
                  setState(() => _cfg.pricingType = 'quote');
                  _notify();
                },
              ),
            ],
          ),
          if (_cfg.pricingType == 'fixed') ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (v) {
                _cfg.price = v;
                _notify();
              },
              decoration: InputDecoration(
                labelText: 'Precio (RD\$)',
                prefixIcon:
                    const Icon(Icons.attach_money, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            maxLength: 200,
            onChanged: (v) {
              _cfg.description = v;
              _notify();
            },
            decoration: InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Ej: incluye materiales, horario, condiciones...',
              hintStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de tipo de precio ────────────────────────────────────────────────────
class _PriceTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriceTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGET COMPARTIDO — Tile para subir foto
// ═════════════════════════════════════════════════════════════════════════════
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
          color: bytes != null
              ? AppColors.successLight
              : AppColors.surfaceVariant,
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
