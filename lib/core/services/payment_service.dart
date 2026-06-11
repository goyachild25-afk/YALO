import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';

/// Resultado de un intento de pago
class PaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String? error;

  const PaymentResult._({
    required this.success,
    this.paymentIntentId,
    this.error,
  });

  factory PaymentResult.success(String paymentIntentId) =>
      PaymentResult._(success: true, paymentIntentId: paymentIntentId);

  factory PaymentResult.failure(String error) =>
      PaymentResult._(success: false, error: error);

  factory PaymentResult.cancelled() =>
      PaymentResult._(success: false, error: 'cancelled');

  bool get isCancelled => error == 'cancelled';
}

class PaymentService {
  /// Sin-op: no hay proveedor de pago activo todavía.
  static void initialize() {}

  /// Registra la intención de pago en Supabase y devuelve éxito.
  /// El cobro real se coordinará manualmente o via PayPal (próxima integración).
  static Future<PaymentResult> processPayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required String description,
    required String bookingId,
  }) async {
    try {
      await SupabaseService.client.from('bookings').update({
        'payment_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      return PaymentResult.success(bookingId);
    } catch (e) {
      return PaymentResult.failure('Error al confirmar la reserva: $e');
    }
  }

  /// Alias para compatibilidad
  static Future<PaymentResult> authorizePayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required String description,
    required String bookingId,
  }) =>
      processPayment(
        context: context,
        amount: amount,
        currency: currency,
        description: description,
        bookingId: bookingId,
      );

  /// Marcar reserva como completada (pago capturado manualmente).
  static Future<bool> capturePayment({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    try {
      await SupabaseService.client.from('bookings').update({
        'payment_status': 'released',
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Modelo de comisión 5% + 5% ──────────────────────────────────────────────
  static double clientTotal(double basePrice) =>
      basePrice * (1 + AppConstants.clientFee);

  static double providerAmount(double basePrice) =>
      basePrice * (1 - AppConstants.providerFee);

  static double platformFee(double basePrice) =>
      basePrice * AppConstants.clientFee + basePrice * AppConstants.providerFee;

  static double clientGuaranteeFee(double basePrice) =>
      basePrice * AppConstants.clientFee;

  static double providerVisibilityFee(double basePrice) =>
      basePrice * AppConstants.providerFee;

  static int pesosToCentavos(double pesos) => (pesos * 100).round();

  static String formatPesos(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'RD\$$formatted';
  }

  static String formatDollars(double amount) =>
      'US\$${amount.toStringAsFixed(2)}';

  /// @deprecated — usar formatPesos
  static String formatColones(double amount) => formatPesos(amount);

  /// @deprecated — usar pesosToCentavos
  static int colonesToCentavos(double v) => pesosToCentavos(v);
}
