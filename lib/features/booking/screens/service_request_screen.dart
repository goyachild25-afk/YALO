import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
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
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Selecciona fecha y hora', AppColors.warning);
      return;
    }

    setState(() => _isLoading = true);

    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // ── Modo demo ─────────────────────────────────────────────────────────────
    if (ref.read(demoModeProvider)) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _isLoading = false);
        final demoId = 'book-${DateTime.now().millisecondsSinceEpoch}';
        context.pushReplacement('/searching/$demoId');
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
            'client_name': profile?['full_name'] as String? ?? user.email?.split('@').first ?? 'Cliente',
            'client_province': profile?['province'] as String? ?? '',
            'provider_id': null,
            'provider_name': null,
            'service_id': null,
            'service_name': widget.categoryName,
            'category_id': widget.categoryId,
            'status': 'pending',
            'payment_status': 'pending',
            'scheduled_date': scheduledDateTime.toIso8601String(),
            'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            'form_answers': widget.filterNotes != null && widget.filterNotes!.isNotEmpty
                ? {'filter_notes': widget.filterNotes}
                : null,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      if (mounted) {
        context.pushReplacement('/searching/${inserted['id']}');
      }
    } catch (e) {
      _showSnack('Error al crear la solicitud: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, [Color color = AppColors.error]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
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
              // ── Encabezado de categoría ──────────────────────────────────────
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
                    color: (cat?.color ?? AppColors.primary).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(cat?.emoji ?? '🔧', style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Vamos a encontrarte un prestador disponible',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Resumen del filtro ───────────────────────────────────────────
              if (widget.filterNotes != null && widget.filterNotes!.isNotEmpty) ...[
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

              // ── Fecha y hora ─────────────────────────────────────────────────
              const Text(
                'Fecha y hora preferida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _DateTimeBox(
                        icon: Icons.calendar_today_outlined,
                        label: 'Fecha',
                        value: _selectedDate != null
                            ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: _DateTimeBox(
                        icon: Icons.access_time,
                        label: 'Hora',
                        value: _selectedTime?.format(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Dirección ────────────────────────────────────────────────────
              const Text(
                'Dirección del servicio',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

              // ── Notas adicionales ────────────────────────────────────────────
              AppTextField(
                label: 'Detalles adicionales (opcional)',
                hint: 'Instrucciones, preferencias...',
                controller: _notesCtrl,
                maxLines: 3,
                prefixIcon: Icons.note_outlined,
              ),

              const SizedBox(height: 20),

              // ── Garantía ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.task_alt_rounded,
                        size: 20, color: AppColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No se realiza ningún pago ahora. Solo pagas cuando el servicio esté completado.',
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
                label: 'Buscar prestador',
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

// ── Widgets internos ──────────────────────────────────────────────────────────

class _DateTimeBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _DateTimeBox({
    required this.icon,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null ? AppColors.primary : AppColors.border,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value != null ? AppColors.primary : AppColors.textHint,
            size: 18,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value ?? 'Seleccionar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
