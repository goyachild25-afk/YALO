import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/onboarding_provider.dart';

// ─── Modelo local de configuración de servicio ────────────────────────────────
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

  // ── Paso 0 — Cuestionario ────────────────────────────────────────────────────
  // { categoryId → { questionId → answer (true=Sí / false=No) } }
  final Map<String, Map<String, bool>> _questAnswers = {};

  /// Categorías habilitadas: al menos una pregunta respondida con "Sí"
  Set<String> get _enabledCategories => Set<String>.from(
        kServiceCategories
            .map((c) => c['id']!)
            .where((id) =>
                _questAnswers[id]?.values.any((v) => v) ?? false),
      );

  // ── Paso 1 — Perfil personal ─────────────────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _province;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _uploadedAvatarUrl;

  // ── Paso 2 — Selección de servicios ─────────────────────────────────────────
  final Set<String> _selectedIds = {};
  final Map<String, _ServiceConfig> _serviceConfigs = {};

  // ── Paso 3 — Verificación de identidad ──────────────────────────────────────
  final _formKey3 = GlobalKey<FormState>();
  final _cedulaCtrl = TextEditingController();
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  Uint8List? _selfieBytes;
  String? _frontExt, _backExt, _selfieExt;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    _cedulaCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    ref.read(currentUserProvider).whenData((user) {
      if (user == null) return;
      if (user.phone != null) _phoneCtrl.text = user.phone!;
      if (user.city != null) _cityCtrl.text = user.city!;
      if (user.province != null && user.province!.isNotEmpty) {
        setState(() => _province = user.province);
      }
    });
  }

  // ── Helpers de imagen ────────────────────────────────────────────────────────
  Future<(Uint8List?, String?)> _pickImage({bool camera = false}) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
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
      return null; // bucket puede no existir aún
    }
  }

  // ── Navegación entre pasos ───────────────────────────────────────────────────
  void _goToStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ── Guardar paso 0 — Cuestionario ────────────────────────────────────────────
  Future<void> _saveStep0() async {
    if (_enabledCategories.isEmpty) {
      _showError(
          'Responde "Sí" a al menos una pregunta para habilitar alguna categoría');
      return;
    }
    // Las respuestas se guardan en DB junto al perfil en _saveStep1
    _goToStep(1);
  }

  // ── Guardar paso 1 — Perfil personal ─────────────────────────────────────────
  Future<void> _saveStep1() async {
    if (!_formKey1.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      // Subir avatar si se seleccionó
      if (_avatarBytes != null) {
        final ext = _avatarExt ?? 'jpg';
        final path = '${user.id}_avatar.$ext';
        _uploadedAvatarUrl = await _uploadBytes(
          bucket: 'avatars',
          path: path,
          bytes: _avatarBytes!,
          ext: ext,
        );
      }

      // Construir JSON de respuestas del cuestionario
      final answersJson = <String, dynamic>{};
      for (final entry in _questAnswers.entries) {
        final catAnswers = entry.value;
        answersJson[entry.key] = <String, dynamic>{
          ...catAnswers,
          'enabled': catAnswers.values.any((v) => v),
        };
      }

      // Actualizar profiles
      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'phone': _phoneCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Actualizar provider_profiles (incluye onboarding_answers del cuestionario)
      await SupabaseService.client.from('provider_profiles').upsert({
        'user_id': user.id,
        'full_name': (await SupabaseService.client
                    .from('profiles')
                    .select('full_name')
                    .eq('id', user.id)
                    .maybeSingle())
                ?['full_name'] as String? ??
            '',
        'bio': _bioCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
        if (answersJson.isNotEmpty) 'onboarding_answers': answersJson,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      ref.invalidate(currentUserProvider);
      if (mounted) _goToStep(2);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar paso 2 — Servicios ───────────────────────────────────────────────
  Future<void> _saveStep2() async {
    if (_selectedIds.isEmpty) {
      _showError('Selecciona al menos un servicio');
      return;
    }
    for (final id in _selectedIds) {
      final cfg = _serviceConfigs[id]!;
      if (cfg.pricingType == 'fixed') {
        final p = double.tryParse(cfg.price);
        if (p == null || p <= 0) {
          _showError('Ingresa un precio válido para todos los servicios fijos');
          return;
        }
      }
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

      await SupabaseService.client
          .from('provider_services')
          .delete()
          .eq('provider_id', providerId);

      const uuid = Uuid();
      final rows = _selectedIds.map((catId) {
        final cat = kServiceCategories.firstWhere((c) => c['id'] == catId);
        final cfg = _serviceConfigs[catId]!;
        return {
          'id': uuid.v4(),
          'provider_id': providerId,
          'category_id': catId,
          'category_name': cat['name'],
          'pricing_type': cfg.pricingType,
          'fixed_price': cfg.pricingType == 'fixed'
              ? double.tryParse(cfg.price) ?? 0.0
              : null,
          'price_description': cfg.description.trim(),
          'form_fields': <dynamic>[],
        };
      }).toList();

      await SupabaseService.client.from('provider_services').insert(rows);

      if (mounted) _goToStep(3);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar paso 3 — Verificación ────────────────────────────────────────────
  Future<void> _saveStep3() async {
    if (!_formKey3.currentState!.validate()) return;
    if (_frontBytes == null || _backBytes == null || _selfieBytes == null) {
      _showError('Sube las 3 fotos requeridas (frontal, trasera y selfie)');
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
        path: '${user.id}/cedula_front.${_frontExt ?? 'jpg'}',
        bytes: _frontBytes!,
        ext: _frontExt ?? 'jpg',
      );
      final backUrl = await _uploadBytes(
        bucket: 'verification-docs',
        path: '${user.id}/cedula_back.${_backExt ?? 'jpg'}',
        bytes: _backBytes!,
        ext: _backExt ?? 'jpg',
      );
      final selfieUrl = await _uploadBytes(
        bucket: 'verification-docs',
        path: '${user.id}/selfie.${_selfieExt ?? 'jpg'}',
        bytes: _selfieBytes!,
        ext: _selfieExt ?? 'jpg',
      );

      try {
        await SupabaseService.client
            .from('provider_profiles')
            .update({
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', user.id);
      } catch (_) {}

      try {
        await SupabaseService.client.from('verification_requests').upsert({
          'user_id': user.id,
          'cedula_number': _cedulaCtrl.text.trim(),
          'cedula_front_url': frontUrl,
          'cedula_back_url': backUrl,
          'selfie_url': selfieUrl,
          'status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (_) {}

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
            _OnboardingHeader(currentStep: _step),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // PASO 0: Cuestionario de habilitación
                  _Step0Questionnaire(
                    questAnswers: _questAnswers,
                    enabledCount: _enabledCategories.length,
                    saving: _saving,
                    onAnswerChanged: (catId, qId, value) {
                      setState(() {
                        _questAnswers.putIfAbsent(catId, () => {});
                        _questAnswers[catId]![qId] = value;
                      });
                    },
                    onNext: _saveStep0,
                  ),

                  // PASO 1: Perfil personal
                  _Step1PersonalInfo(
                    formKey: _formKey1,
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
                    onBack: () => _goToStep(0),
                    onNext: _saveStep1,
                  ),

                  // PASO 2: Servicios
                  _Step2Services(
                    selectedIds: _selectedIds,
                    serviceConfigs: _serviceConfigs,
                    enabledCategoryIds: _enabledCategories,
                    saving: _saving,
                    onToggleCategory: (id) {
                      setState(() {
                        if (_selectedIds.contains(id)) {
                          _selectedIds.remove(id);
                          _serviceConfigs.remove(id);
                        } else {
                          _selectedIds.add(id);
                          _serviceConfigs[id] = _ServiceConfig();
                        }
                      });
                    },
                    onConfigChanged: (id, cfg) {
                      setState(() => _serviceConfigs[id] = cfg);
                    },
                    onBack: () => _goToStep(1),
                    onNext: _saveStep2,
                  ),

                  // PASO 3: Verificación
                  _Step3Verification(
                    formKey: _formKey3,
                    cedulaCtrl: _cedulaCtrl,
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
// HEADER CON BARRA DE PROGRESO (4 pasos)
// ═════════════════════════════════════════════════════════════════════════════
class _OnboardingHeader extends StatelessWidget {
  final int currentStep;
  const _OnboardingHeader({required this.currentStep});

  static const _titles = [
    'Cuestionario',
    'Perfil personal',
    'Mis servicios',
    'Verificación',
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
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          // 4 barras de progreso
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
// PASO 0 — CUESTIONARIO DE HABILITACIÓN
// ═════════════════════════════════════════════════════════════════════════════
class _Step0Questionnaire extends StatelessWidget {
  final Map<String, Map<String, bool>> questAnswers;
  final int enabledCount;
  final bool saving;
  final void Function(String catId, String qId, bool value) onAnswerChanged;
  final VoidCallback onNext;

  const _Step0Questionnaire({
    required this.questAnswers,
    required this.enabledCount,
    required this.saving,
    required this.onAnswerChanged,
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
                color: enabledCount > 0
                    ? AppColors.success
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  enabledCount > 0
                      ? Icons.check_circle_outline
                      : Icons.quiz_outlined,
                  color: enabledCount > 0
                      ? AppColors.success
                      : AppColors.textHint,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabledCount > 0
                        ? '$enabledCount de ${kServiceCategories.length} categorías habilitadas'
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
          const SizedBox(height: 10),
          const Text(
            'Solo podrás ofrecer servicios en las categorías que habilites respondiendo "Sí" a las preguntas.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4),
          ),
          const SizedBox(height: 16),

          // Tarjeta por cada categoría
          ...kServiceCategories.map((cat) {
            final catId = cat['id']!;
            final questions = kCategoryQuestions[catId] ?? [];
            final answers = questAnswers[catId] ?? {};
            final isEnabled = answers.values.any((v) => v);
            return _CategoryQuestionCard(
              category: cat,
              questions: questions,
              answers: answers,
              isEnabled: isEnabled,
              onAnswerChanged: (qId, value) =>
                  onAnswerChanged(catId, qId, value),
            );
          }),

          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continuar',
            onPressed: onNext,
            isLoading: saving,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Tarjeta de preguntas por categoría ──────────────────────────────────────
class _CategoryQuestionCard extends StatelessWidget {
  final Map<String, String> category;
  final List<Map<String, String>> questions;
  final Map<String, bool> answers;
  final bool isEnabled;
  final void Function(String qId, bool value) onAnswerChanged;

  const _CategoryQuestionCard({
    required this.category,
    required this.questions,
    required this.answers,
    required this.isEnabled,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.successLight.withValues(alpha: 0.25)
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
          // Encabezado
          Row(
            children: [
              Text(category['emoji']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category['name']!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (isEnabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✓ Habilitado',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Preguntas con chips Sí/No
          ...questions.map((q) {
            final qId = q['id']!;
            final answer = answers[qId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q['text']!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _YesNoChip(
                        label: 'Sí',
                        selected: answer == true,
                        isYes: true,
                        onTap: () => onAnswerChanged(qId, true),
                      ),
                      const SizedBox(width: 8),
                      _YesNoChip(
                        label: 'No',
                        selected: answer == false,
                        isYes: false,
                        onTap: () => onAnswerChanged(qId, false),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
// PASO 1 — PERFIL PERSONAL
// ═════════════════════════════════════════════════════════════════════════════
class _Step1PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController bioCtrl;
  final String? province;
  final Uint8List? avatarBytes;
  final bool saving;
  final ValueChanged<String?> onProvinceChanged;
  final VoidCallback onPickAvatar;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step1PersonalInfo({
    required this.formKey,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.bioCtrl,
    required this.province,
    required this.avatarBytes,
    required this.saving,
    required this.onProvinceChanged,
    required this.onPickAvatar,
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
            // Avatar picker
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
                child: const Text('Subir foto de perfil',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 8),

            AppTextField(
              label: 'Teléfono',
              hint: '809-555-0000',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  v == null || v.length < 8 ? 'Número inválido' : null,
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
                  v == null || v.isEmpty ? 'Campo requerido' : null,
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
                if (v.trim().length < 50) {
                  return 'Mínimo 50 caracteres (${v.trim().length}/50)';
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
                    color:
                        count >= 50 ? AppColors.success : AppColors.textHint,
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
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
// PASO 2 — SELECCIÓN DE SERVICIOS
// ═════════════════════════════════════════════════════════════════════════════
class _Step2Services extends StatelessWidget {
  final Set<String> selectedIds;
  final Map<String, _ServiceConfig> serviceConfigs;
  final Set<String> enabledCategoryIds;
  final bool saving;
  final ValueChanged<String> onToggleCategory;
  final void Function(String id, _ServiceConfig cfg) onConfigChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2Services({
    required this.selectedIds,
    required this.serviceConfigs,
    required this.enabledCategoryIds,
    required this.saving,
    required this.onToggleCategory,
    required this.onConfigChanged,
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
          const Text(
            'Selecciona los servicios que ofreces y configura tus precios.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          if (enabledCategoryIds.isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay categorías habilitadas. Vuelve al paso anterior.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Grid de categorías
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: kServiceCategories.length,
            itemBuilder: (_, i) {
              final cat = kServiceCategories[i];
              final id = cat['id']!;
              final isSelected = selectedIds.contains(id);
              final isEnabled = enabledCategoryIds.contains(id);
              return GestureDetector(
                onTap: () {
                  if (!isEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Esta categoría no fue habilitada en el cuestionario. '
                            'Vuelve al paso 1 para habilitarla.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  onToggleCategory(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLighter
                        : isEnabled
                            ? AppColors.surfaceVariant
                            : AppColors.surfaceVariant
                                .withValues(alpha: 0.5),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : isEnabled
                              ? AppColors.divider
                              : AppColors.divider.withValues(alpha: 0.4),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Opacity(
                    opacity: isEnabled ? 1.0 : 0.4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat['emoji']!,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          cat['name']!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Configuración de servicios seleccionados
          if (selectedIds.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Configura tus servicios',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...selectedIds.map((id) {
              final cat =
                  kServiceCategories.firstWhere((c) => c['id'] == id);
              final cfg = serviceConfigs[id]!;
              return _ServiceConfigCard(
                categoryName: cat['name']!,
                emoji: cat['emoji']!,
                config: cfg,
                onChanged: (updated) => onConfigChanged(id, updated),
              );
            }),
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

// ─── Tarjeta de configuración de servicio ─────────────────────────────────────
class _ServiceConfigCard extends StatefulWidget {
  final String categoryName;
  final String emoji;
  final _ServiceConfig config;
  final ValueChanged<_ServiceConfig> onChanged;

  const _ServiceConfigCard({
    required this.categoryName,
    required this.emoji,
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
                child: Text(
                  widget.categoryName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tipo de precio',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
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
                label: 'Cotización',
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
                prefixIcon: const Icon(Icons.attach_money,
                    color: AppColors.primary),
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
            onChanged: (v) {
              _cfg.description = v;
              _notify();
            },
            decoration: InputDecoration(
              labelText: 'Descripción del servicio',
              hintText: 'Ej: Incluye materiales, horario, condiciones...',
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
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
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
// PASO 3 — VERIFICACIÓN DE IDENTIDAD
// ═════════════════════════════════════════════════════════════════════════════
class _Step3Verification extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController cedulaCtrl;
  final Uint8List? frontBytes;
  final Uint8List? backBytes;
  final Uint8List? selfieBytes;
  final bool saving;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onPickSelfie;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _Step3Verification({
    required this.formKey,
    required this.cedulaCtrl,
    required this.frontBytes,
    required this.backBytes,
    required this.selfieBytes,
    required this.saving,
    required this.onPickFront,
    required this.onPickBack,
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
            // Aviso de privacidad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tus documentos son cifrados y solo usados para verificar tu identidad conforme a la Ley 172-13.',
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
              hint: '000-0000000-0',
              controller: cedulaCtrl,
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
              'Las fotos deben ser claras y legibles.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            _DocPhotoTile(
              label: 'Foto frontal de la cédula',
              sublabel: 'Cara con tu foto y datos',
              icon: Icons.credit_card_outlined,
              bytes: frontBytes,
              onPick: onPickFront,
            ),
            const SizedBox(height: 10),
            _DocPhotoTile(
              label: 'Foto trasera de la cédula',
              sublabel: 'Cara con el código de barras',
              icon: Icons.credit_card,
              bytes: backBytes,
              onPick: onPickBack,
            ),
            const SizedBox(height: 10),
            _DocPhotoTile(
              label: 'Selfie sosteniendo la cédula',
              sublabel: 'Tú con la cédula en mano',
              icon: Icons.face_outlined,
              bytes: selfieBytes,
              onPick: onPickSelfie,
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verificación pendiente',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nuestro equipo revisará tus documentos en 24-48 h hábiles.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              height: 1.4),
                        ),
                      ],
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
                    label: 'Enviar y finalizar',
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

// ─── Tile de foto de documento ────────────────────────────────────────────────
class _DocPhotoTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Uint8List? bytes;
  final VoidCallback onPick;

  const _DocPhotoTile({
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
                  ? Image.memory(bytes!,
                      width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56,
                      height: 56,
                      color: AppColors.border,
                      child: Icon(icon,
                          color: AppColors.textHint, size: 28),
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
                          fontSize: 11,
                          color: AppColors.textSecondary)),
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
