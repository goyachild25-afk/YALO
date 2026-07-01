import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/photo_picker_grid.dart';
import '../../../shared/models/service_category_model.dart';

class ServiceRequestScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? filterNotes;

  const ServiceRequestScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.filterNotes,
  });

  @override
  ConsumerState<ServiceRequestScreen> createState() =>
      _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends ConsumerState<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;
  List<String> _servicePhotoUrls = [];
  // ID temporal para agrupar las fotos por reserva antes de que la reserva
  // tenga un ID real. Al insertar la fila hacemos referencia a estas URLs
  // (que ya están en el bucket), así que aunque la reserva se abandone las
  // fotos quedan huérfanas pero no bloquean el flujo. Un cleanup nocturno
  // podría purgar carpetas sin booking en el futuro.
  late final String _draftId =
      'draft-${DateTime.now().millisecondsSinceEpoch}';

  ServiceCategory? get _category => serviceCategories.firstWhere(
        (c) => c.id == widget.categoryId,
        orElse: () => serviceCategories.first,
      );

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // ── Modo demo ─────────────────────────────────────────────────────────────
    if (ref.read(demoModeProvider)) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _isLoading = false);
        context.push(
            '/searching/book-${DateTime.now().millisecondsSinceEpoch}');
      }
      return;
    }

    // ── Supabase real ─────────────────────────────────────────────────────────
    try {
      final user = SupabaseService.currentUser!;

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, province')
          .eq('id', user.id)
          .maybeSingle();

      final inserted = await SupabaseService.client
          .from('bookings')
          .insert({
            'client_id': user.id,
            'client_name': profile?['full_name'] as String? ??
                user.email?.split('@').first ??
                'Cliente',
            'client_province': profile?['province'] as String? ?? '',
            'provider_id': null,
            'provider_name': null,
            'service_id': null,
            'service_name': widget.categoryName,
            'category_id': widget.categoryId,
            'status': 'pending',
            'payment_status': 'pending',
            'scheduled_date': DateTime.now().toIso8601String(),
            'notes': _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            'form_answers':
                widget.filterNotes != null && widget.filterNotes!.isNotEmpty
                    ? {'filter_notes': widget.filterNotes}
                    : null,
            'service_photos':
                _servicePhotoUrls.isEmpty ? null : _servicePhotoUrls,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      if (mounted) {
        context.push('/searching/${inserted['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al crear la solicitud: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (cat?.color ?? AppColors.primary).withValues(alpha: 0.15),
                      (cat?.color ?? AppColors.primary).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        (cat?.color ?? AppColors.primary).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(cat?.emoji ?? '🔧',
                        style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'El prestador llega lo antes posible',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // "Ahora" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Ya',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Resumen del filtro ───────────────────────────────────────────
              if (widget.filterNotes != null &&
                  widget.filterNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu solicitud incluye:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.filterNotes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Dirección ────────────────────────────────────────────────────
              const Text(
                '¿Dónde necesitas el servicio?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'El prestador irá directamente a esta dirección',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Dirección completa',
                hint: 'Calle, número, barrio...',
                controller: _addressCtrl,
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingresa la dirección' : null,
              ),

              const SizedBox(height: 24),

              // ── Notas ────────────────────────────────────────────────────────
              AppTextField(
                label: 'Describe el problema (opcional)',
                hint: 'Ej: El grifo del baño está goteando...',
                controller: _notesCtrl,
                maxLines: 3,
                prefixIcon: Icons.note_outlined,
              ),

              const SizedBox(height: 20),

              // ── Fotos del problema ────────────────────────────────────────
              const Text(
                'Añade fotos del problema (opcional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'El prestador podrá cotizar con más precisión sin visita previa.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              PhotoPickerGrid(
                bucket: 'booking-photos',
                folder: _draftId,
                maxPhotos: 4,
                initialUrls: _servicePhotoUrls,
                addLabel: 'Añadir\nfoto',
                onChange: (urls) => setState(() => _servicePhotoUrls = urls),
              ),

              const SizedBox(height: 20),

              // ── Aviso de inmediatez ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 20, color: AppColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El prestador se desplazará de inmediato. Pagas solo cuando el servicio quede completado.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              PrimaryButton(
                label: '⚡ Solicitar ahora',
                onPressed: _submit,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
