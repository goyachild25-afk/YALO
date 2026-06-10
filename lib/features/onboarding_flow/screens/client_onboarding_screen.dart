import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/onboarding_provider.dart';

class ClientOnboardingScreen extends ConsumerStatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  ConsumerState<ClientOnboardingScreen> createState() =>
      _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState
    extends ConsumerState<ClientOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _province;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _prefillFromProfile() {
    // Prefill from cached profile if available
    final userAsync = ref.read(currentUserProvider);
    userAsync.whenData((user) {
      if (user != null) {
        if (user.phone != null) _phoneCtrl.text = user.phone!;
        if (user.city != null) _cityCtrl.text = user.city!;
        if (user.address != null) _addressCtrl.text = user.address!;
        if (user.province != null && user.province!.isNotEmpty) {
          setState(() => _province = user.province);
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // En modo demo no se toca la base de datos real
    if (ref.read(demoModeProvider)) {
      if (mounted) context.go('/home');
      return;
    }

    setState(() => _saving = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      // Update profiles table
      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'phone': _phoneCtrl.text.trim(),
        'province': _province ?? '',
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await markOnboardingComplete(user.id);
      ref.invalidate(currentUserProvider);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '¡Ya casi terminamos!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Completa tu perfil',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Necesitamos un poco más de información\npara brindarte el mejor servicio.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Form ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teléfono
                      _SectionLabel(label: 'Contacto', icon: Icons.phone_outlined),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Teléfono',
                        hint: '809-555-0000',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) =>
                            v == null || v.length < 8 ? 'Número inválido' : null,
                      ),
                      const SizedBox(height: 24),

                      // Ubicación
                      _SectionLabel(
                          label: 'Ubicación', icon: Icons.location_on_outlined),
                      const SizedBox(height: 12),
                      AppDropdown<String>(
                        label: 'Provincia',
                        value: _province,
                        prefixIcon: Icons.map_outlined,
                        items: kProvinciasRD
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() => _province = v),
                        validator: (v) =>
                            v == null ? 'Selecciona tu provincia' : null,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Ciudad / Municipio',
                        hint: 'Ej: Piantini, Naco...',
                        controller: _cityCtrl,
                        prefixIcon: Icons.location_city_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Dirección principal',
                        hint: 'Calle, número, sector...',
                        controller: _addressCtrl,
                        prefixIcon: Icons.home_outlined,
                        maxLines: 2,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 32),

                      // CTA
                      PrimaryButton(
                        label: 'Guardar y continuar',
                        onPressed: _save,
                        isLoading: _saving,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 16),

                      // Skip (completar después)
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            // En modo demo no hay usuario real en Supabase
                            if (!ref.read(demoModeProvider)) {
                              final user = SupabaseService.currentUser;
                              if (user != null) await markOnboardingComplete(user.id);
                            }
                            if (!mounted) return;
                            context.go('/home'); // ignore: use_build_context_synchronously
                          },
                          child: const Text(
                            'Completar más tarde',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget auxiliar ──────────────────────────────────────────────────────────
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
