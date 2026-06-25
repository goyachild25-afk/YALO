import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../providers_list/models/service_provider_model.dart';
import '../../providers_list/providers/providers_list_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String providerId;

  const BookingScreen({super.key, required this.providerId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  ProviderService? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, dynamic> _formAnswers = {};
  bool _isLoading = false;

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

  Future<void> _submit(ServiceProviderModel provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      _showSnack('Selecciona un servicio', AppColors.warning);
      return;
    }

    setState(() => _isLoading = true);

    // Scheduled now (or future if user selected date/time)
    final scheduledDateTime = (_selectedDate != null && _selectedTime != null)
        ? DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          )
        : DateTime.now();

    // ── Modo demo ──────────────────────────────────────────────────
    final isDemo = ref.read(demoModeProvider);
    if (isDemo) {
      await Future.delayed(const Duration(milliseconds: 600));
      final demoUser = ref.read(demoUserProvider);
      final newBooking = <String, dynamic>{
        'id': 'book-${DateTime.now().millisecondsSinceEpoch}',
        'client_id': demoUser?.id ?? 'demo-client',
        'client_name': demoUser?.fullName ?? 'Cliente Demo',
        'provider_id': provider.id,
        'provider_name': provider.fullName,
        'provider_avatar_url': provider.avatarUrl,
        'service_id': _selectedService!.id,
        'service_name': _selectedService!.categoryName,
        'status': 'pending',
        'payment_status': 'pending',
        'scheduled_date': scheduledDateTime.toIso8601String(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'agreed_price': _selectedService!.pricingType == PricingType.fixed
            ? _selectedService!.fixedPrice
            : null,
        'created_at': DateTime.now().toIso8601String(),
      };
      ref.read(demoCreatedBookingsProvider.notifier).update(
            (list) => [newBooking, ...list],
          );
      if (mounted) {
        setState(() => _isLoading = false);
        // El pago se realiza DESPUÉS de que el prestador complete el servicio
        context.push('/booking-confirmation');
      }
      return;
    }

    // ── Modo real (Supabase) ───────────────────────────────────────
    try {
      final user = SupabaseService.currentUser!;

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      final inserted = await SupabaseService.client
          .from('bookings')
          .insert({
            'client_id': user.id,
            'client_name': profile['full_name'],
            'provider_id': provider.id,
            'provider_name': provider.fullName,
            'provider_avatar_url': provider.avatarUrl,
            'service_id': _selectedService!.id,
            'service_name': _selectedService!.categoryName,
            'status': 'pending',
            'payment_status': 'pending',
            'scheduled_date': scheduledDateTime.toIso8601String(),
            'notes': _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            'agreed_price': _selectedService!.pricingType == PricingType.fixed
                ? _selectedService!.fixedPrice
                : null,
            'form_answers': _formAnswers.isNotEmpty ? _formAnswers : null,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      // ── Enviar email de confirmación (fire-and-forget) ─────────────
      try {
        await SupabaseService.client.functions.invoke(
          'send-booking-email',
          body: {
            'bookingId': inserted['id'],
            'clientId': user.id,
            'providerName': provider.fullName,
            'serviceName': _selectedService!.categoryName,
            'scheduledDate': scheduledDateTime.toIso8601String(),
            'address': _addressCtrl.text.trim(),
            'price': _selectedService!.pricingType == PricingType.fixed
                ? _selectedService!.fixedPrice
                : null,
          },
        );
      } catch (_) {
        // Email failure never blocks the booking flow
      }

      if (mounted) {
        // El pago se realiza DESPUÉS de que el prestador complete el servicio
        context.push('/booking-confirmation');
      }
    } catch (e) {
      _showSnack('Error al crear la solicitud: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(providerDetailProvider(widget.providerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar servicio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: providerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (provider) {
          if (provider == null) {
            return const Center(child: Text('Prestador no encontrado'));
          }
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProviderSummary(provider),
                  const SizedBox(height: 24),
                  _buildServiceSelection(provider),
                  const SizedBox(height: 24),
                  _buildDateTime(),
                  const SizedBox(height: 24),
                  _buildAddress(),
                  if (_selectedService?.pricingType == PricingType.quote &&
                      _selectedService?.formFields != null) ...[
                    const SizedBox(height: 24),
                    _buildDynamicForm(),
                  ],
                  const SizedBox(height: 24),
                  _buildNotes(),
                  if (_selectedService != null) ...[
                    const SizedBox(height: 20),
                    _buildPriceSummary(),
                  ],
                  const SizedBox(height: 20),
                  // Garantía de pago post-servicio
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
                        Icon(Icons.task_alt_rounded,
                            size: 20, color: AppColors.primaryDark),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No se realiza ningún pago ahora. Pagas solo cuando el servicio esté completado.',
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
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: '⚡ Solicitar ahora',
                    onPressed: () => _submit(provider),
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProviderSummary(ServiceProviderModel provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryLighter,
            backgroundImage: provider.avatarUrl != null
                ? CachedNetworkImageProvider(provider.avatarUrl!)
                : null,
            child: provider.avatarUrl == null
                ? Text(
                    provider.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                provider.locationLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection(ServiceProviderModel provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona el servicio',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (provider.services.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este prestador todavía no ha configurado sus servicios. '
                    'Intenta con otro prestador o vuelve más tarde.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ...provider.services.map(
          (service) => GestureDetector(
            onTap: () => setState(() => _selectedService = service),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedService?.id == service.id
                    ? AppColors.primaryLighter.withValues(alpha: 0.3)
                    : AppColors.surface,
                border: Border.all(
                  color: _selectedService?.id == service.id
                      ? AppColors.primary
                      : AppColors.divider,
                  width: _selectedService?.id == service.id ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: service.id,
                    groupValue: _selectedService?.id, // ignore: deprecated_member_use
                    onChanged: (_) => setState(() => _selectedService = service), // ignore: deprecated_member_use
                    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return AppColors.primary.withValues(alpha: 0.4);
                    }),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (service.priceDescription != null)
                          Text(
                            service.priceDescription!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: service.pricingType == PricingType.fixed
                          ? AppColors.successLight
                          : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      service.priceLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: service.pricingType == PricingType.fixed
                            ? AppColors.success
                            : AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha y hora',
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
      ],
    );
  }

  Widget _buildAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildDynamicForm() {
    final fields = _selectedService!.formFields!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalles del servicio',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'El prestador necesita esta información para darte una cotización.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ...fields.map(
          (field) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: field.type == FormFieldType.select
                ? AppDropdown<String>(
                    label: field.label,
                    value: _formAnswers[field.id] as String?,
                    items: field.options
                            ?.map((o) =>
                                DropdownMenuItem(value: o, child: Text(o)))
                            .toList() ??
                        [],
                    onChanged: (v) =>
                        setState(() => _formAnswers[field.id] = v),
                    validator: field.required
                        ? (v) => v == null ? 'Campo requerido' : null
                        : null,
                  )
                : AppTextField(
                    label: field.label,
                    hint: field.hint,
                    keyboardType: field.type == FormFieldType.number
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: (v) => _formAnswers[field.id] = v,
                    validator: field.required
                        ? (v) => v == null || v.isEmpty
                            ? 'Campo requerido'
                            : null
                        : null,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotes() {
    return AppTextField(
      label: 'Notas adicionales (opcional)',
      hint: 'Instrucciones especiales, preferencias...',
      controller: _notesCtrl,
      maxLines: 3,
      prefixIcon: Icons.note_outlined,
    );
  }

  Widget _buildPriceSummary() {
    final isFixed = _selectedService!.pricingType == PricingType.fixed;
    final basePrice = isFixed ? (_selectedService!.fixedPrice ?? 0.0) : null;
    // Comisión 5%+5%: el precio mostrado al cliente incluye la Garantía ServiciosYa
    final clientTotal = basePrice != null ? basePrice * 1.05 : null;
    final providerNet  = basePrice != null ? basePrice * 0.95 : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Servicio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Servicio', style: TextStyle(fontSize: 13)),
              Text(
                _selectedService!.categoryName,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ),
          if (isFixed && basePrice != null) ...[
            const Divider(height: 16),
            // Precio base
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Precio del servicio',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('RD\$${basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            // Garantía ServiciosYa (5%)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Garantía ServiciosYa',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('5%',
                          style: TextStyle(fontSize: 10, color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text('+RD\$${(basePrice * 0.05).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const Divider(height: 16),
            // Total cliente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total a pagar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  'RD\$${clientTotal!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Nota al prestador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prestador recibirá',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                Text(
                  'RD\$${providerNet!.toStringAsFixed(0)} (−5% Membresía)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ] else ...[
            // Servicio de cotización: precio se negocia en chat
            const Divider(height: 16),
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.info),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El precio se negocia directamente con el prestador vía chat tras aceptar la solicitud.',
                    style: TextStyle(fontSize: 12, color: AppColors.info, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Garantía ServiciosYa',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('5% sobre precio acordado',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
