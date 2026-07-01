import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

/// Bottom sheet para agregar propina opcional al prestador después de que
/// un servicio se marca como completado. Sugerencias del 10%, 15%, 20% o
/// monto personalizado. Se guarda en `bookings.tip_amount`.
class TipSelectorSheet extends StatefulWidget {
  final String bookingId;
  final double serviceAmount;
  final String providerName;

  const TipSelectorSheet({
    super.key,
    required this.bookingId,
    required this.serviceAmount,
    required this.providerName,
  });

  static Future<double?> show(
    BuildContext context, {
    required String bookingId,
    required double serviceAmount,
    required String providerName,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TipSelectorSheet(
        bookingId: bookingId,
        serviceAmount: serviceAmount,
        providerName: providerName,
      ),
    );
  }

  @override
  State<TipSelectorSheet> createState() => _TipSelectorSheetState();
}

class _TipSelectorSheetState extends State<TipSelectorSheet> {
  double? _selectedPct;
  final _customCtrl = TextEditingController();
  bool _saving = false;

  static const _percentages = [0.10, 0.15, 0.20];

  double get _tipAmount {
    if (_selectedPct != null) {
      return (widget.serviceAmount * _selectedPct!).roundToDouble();
    }
    return double.tryParse(_customCtrl.text.replaceAll(',', '')) ?? 0;
  }

  Future<void> _save() async {
    final amount = _tipAmount;
    if (amount <= 0) {
      Navigator.of(context).pop(0.0);
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('bookings').update({
        'tip_amount': amount,
        'tip_added_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.bookingId);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(amount);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos registrar la propina.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  String _fmt(double v) =>
      'RD\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('💜 ', style: TextStyle(fontSize: 22)),
                Text('¿Dejar propina?',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.providerName} hizo un buen trabajo. Una propina llega directo a su bolsillo, sin comisión.',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 20),

            // Chips % sugeridos
            Row(
              children: _percentages.map((pct) {
                final selected = _selectedPct == pct;
                final amount = (widget.serviceAmount * pct).roundToDouble();
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: pct == _percentages.last ? 0 : 8),
                    child: Material(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primaryLighter,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedPct = pct;
                          _customCtrl.clear();
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _fmt(amount),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Custom
            TextField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _selectedPct = null),
              decoration: const InputDecoration(
                labelText: 'Otro monto (RD\$)',
                hintText: 'Ej: 250',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Ahora no'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_tipAmount > 0
                            ? 'Dejar ${_fmt(_tipAmount)}'
                            : 'Dejar propina'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
