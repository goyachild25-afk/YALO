import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../models/dispute_model.dart';

class ReportDisputeScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String reportedUserId;
  final String reportedUserName;
  final String serviceName;

  const ReportDisputeScreen({
    super.key,
    required this.bookingId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.serviceName,
  });

  @override
  ConsumerState<ReportDisputeScreen> createState() =>
      _ReportDisputeScreenState();
}

class _ReportDisputeScreenState extends ConsumerState<ReportDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  DisputeType? _selectedType;
  bool _isSending = false;
  bool _sent = false;
  String _caseNumber = '';

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el tipo de problema')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final isDemo = ref.read(demoModeProvider);

      if (!isDemo) {
        final user = SupabaseService.currentUser!;
        final profile = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();

        final inserted = await SupabaseService.client
            .from('disputes')
            .insert({
              'booking_id': widget.bookingId,
              'reporter_id': user.id,
              'reporter_name': profile['full_name'],
              'reported_id': widget.reportedUserId,
              'reported_name': widget.reportedUserName,
              'type': _selectedType!.name,
              'description': _descCtrl.text.trim(),
              'status': DisputeStatus.open.name,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        // Generate case number from DB id (first 8 chars of UUID)
        final id = inserted['id'] as String;
        _caseNumber = '#SY-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}';
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
        _caseNumber = '#SY-DEMO0001';
      }

      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar problema'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _sent ? _buildSuccess() : _buildForm(),
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
          // ── Aviso legal ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu reporte es confidencial. Nuestro equipo lo revisará en un plazo de 24-48 horas. '
                    'Las disputas fraudulentas pueden resultar en la suspensión de tu cuenta.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.info, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Info del servicio ────────────────────────────────
          _InfoRow(label: 'Servicio', value: widget.serviceName),
          const SizedBox(height: 8),
          _InfoRow(label: 'Reportado', value: widget.reportedUserName),
          const SizedBox(height: 24),

          // ── Tipo de problema ─────────────────────────────────
          const Text(
            'Tipo de problema *',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...DisputeType.values.map((type) {
            final selected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.errorLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.error
                        : AppColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.error
                          : AppColors.textHint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _disputeLabel(type),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // ── Descripción ──────────────────────────────────────
          AppTextField(
            label: 'Describe el problema *',
            hint:
                'Explica con detalle qué ocurrió, cuándo y cómo te afectó...',
            controller: _descCtrl,
            maxLines: 5,
            prefixIcon: Icons.description_outlined,
            validator: (v) {
              if (v == null || v.trim().length < 20) {
                return 'Describe el problema con al menos 20 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ── Aviso evidencia ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.photo_camera_outlined,
                    color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Puedes adjuntar evidencias (fotos/videos) enviándolas al chat de soporte tras abrir la disputa.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Botón enviar ─────────────────────────────────────
          PrimaryButton(
            label: 'Enviar reporte',
            onPressed: _submit,
            isLoading: _isSending,
            icon: Icons.send_outlined,
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
                size: 60, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Reporte enviado',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Nuestro equipo revisará tu caso en 24-48 horas.\n'
          'Te notificaremos sobre el resultado a través de la app.',
          style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📋 Número de caso',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text(
                _caseNumber,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary),
              ),
              SizedBox(height: 4),
              Text(
                'Guarda este número para dar seguimiento.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        PrimaryButton(
          label: 'Volver',
          onPressed: () => context.go('/bookings'),
        ),
      ],
    );
  }

  String _disputeLabel(DisputeType type) {
    switch (type) {
      case DisputeType.serviceNotCompleted:
        return '❌  El servicio no fue completado';
      case DisputeType.fraudOrScam:
        return '🚨  Fraude o estafa';
      case DisputeType.propertyDamage:
        return '🏚️  Daño a la propiedad';
      case DisputeType.inappropriateBehavior:
        return '⚠️  Conducta inapropiada';
      case DisputeType.noShow:
        return '🚫  No se presentó';
      case DisputeType.paymentIssue:
        return '💳  Problema con el pago';
      case DisputeType.other:
        return '📝  Otro motivo';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
