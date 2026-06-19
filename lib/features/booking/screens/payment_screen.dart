import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String serviceName;
  final String providerName;
  final String currency; // 'dop' o 'usd'

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.serviceName,
    required this.providerName,
    this.currency = 'dop',
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;

  double get _platformFee => PaymentService.platformFee(widget.amount);
  double get _providerAmount => PaymentService.providerAmount(widget.amount);

  String _format(double v) => widget.currency == 'dop'
      ? PaymentService.formatPesos(v)
      : PaymentService.formatDollars(v);

  Future<void> _pay() async {
    setState(() => _isProcessing = true);

    final isDemo = ref.read(demoModeProvider);

    if (isDemo) {
      // Simular pago exitoso en modo demo
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSuccess();
      }
      return;
    }

    final result = await PaymentService.processPayment(
      context: context,
      amount: PaymentService.pesosToCentavos(widget.amount),
      currency: widget.currency,
      description: '${widget.serviceName} — ${widget.providerName}',
      bookingId: widget.bookingId,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.success) {
      _showSuccess();
    } else if (!result.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Error al procesar el pago'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccess() {
    context.push('/booking-confirmation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garantizar el pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resumen del servicio ─────────────────────────────
            _SectionTitle('Resumen del servicio'),
            const SizedBox(height: 12),
            _SummaryCard(
              serviceName: widget.serviceName,
              providerName: widget.providerName,
            ),
            const SizedBox(height: 24),

            // ── Desglose de precios ──────────────────────────────
            _SectionTitle('Detalle del pago'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Precio del servicio',
                    value: _format(widget.amount),
                  ),
                  const Divider(height: 20),
                  _PriceRow(
                    label:
                        'Comisión plataforma (${(AppConstants.platformCommission * 100).toStringAsFixed(0)}%)',
                    value: _format(_platformFee),
                    isSubtle: true,
                  ),
                  _PriceRow(
                    label: 'Pago al prestador',
                    value: _format(_providerAmount),
                    isSubtle: true,
                  ),
                  const Divider(height: 20),
                  _PriceRow(
                    label: 'Total a pagar',
                    value: _format(widget.amount),
                    isBold: true,
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Métodos de pago ──────────────────────────────────
            _SectionTitle('Método de pago'),
            const SizedBox(height: 12),
            _PaymentMethodSelector(),
            const SizedBox(height: 24),

            // ── Cómo funciona el escrow ───────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '¿Cómo funciona la garantía?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _EscrowStep(
                    icon: Icons.credit_card_outlined,
                    text:
                        'Tu tarjeta se reserva HOY. No se cobra ningún dinero.',
                  ),
                  _EscrowStep(
                    icon: Icons.handyman_outlined,
                    text: 'El prestador realiza el servicio con total confianza.',
                  ),
                  _EscrowStep(
                    icon: Icons.check_circle_outline,
                    text:
                        'Al marcar el servicio como completado, el cobro se realiza automáticamente.',
                  ),
                  _EscrowStep(
                    icon: Icons.security_outlined,
                    text:
                        'Si el servicio no se realiza, tu dinero está 100% protegido.',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Seguridad Stripe ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reserva 100% segura. Nunca almacenamos tus datos de pago.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Botón garantizar ─────────────────────────────────
            PrimaryButton(
              label: 'Garantizar ${_format(widget.amount)} 🔒',
              onPressed: _pay,
              isLoading: _isProcessing,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Cancelar',
              onPressed: () => context.pop(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String serviceName;
  final String providerName;
  const _SummaryCard(
      {required this.serviceName, required this.providerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cleaning_services_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'con $providerName',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSubtle;
  final bool isBold;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isSubtle = false,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSubtle ? 13 : 14,
            color: isSubtle ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ??
                (isSubtle ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodSelector extends StatefulWidget {
  @override
  State<_PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<_PaymentMethodSelector> {
  int _selected = 0; // 0 = tarjeta, 1 = PayPal (próximamente)

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MethodTile(
          icon: Icons.credit_card,
          label: 'Tarjeta de crédito / débito',
          subtitle: 'Visa, Mastercard, American Express',
          selected: _selected == 0,
          onTap: () => setState(() => _selected = 0),
        ),
        const SizedBox(height: 8),
        _MethodTile(
          icon: Icons.phone_android,
          label: 'PayPal',
          subtitle: 'Próximamente disponible',
          selected: _selected == 1,
          onTap: null, // deshabilitado por ahora
          disabled: true,
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool disabled;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLighter.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: disabled
                  ? AppColors.textHint
                  : (selected ? AppColors.primary : AppColors.textSecondary),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: disabled
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textHint,
                size: 20,
              ),
            if (disabled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Próximo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Paso del flujo de escrow ──────────────────────────────────────────────────
class _EscrowStep extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLast;

  const _EscrowStep({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
