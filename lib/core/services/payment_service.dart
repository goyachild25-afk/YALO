import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
  /// Inicializar Stripe — llamar en main.dart
  static void initialize() {
    Stripe.publishableKey = AppConstants.stripePublishableKey;
    Stripe.merchantIdentifier = 'ServiciosYa';
  }

  /// Procesar pago completo con el Payment Sheet de Stripe
  ///
  /// [amount]      Monto en centavos (ej: 250000 = RD$2,500)
  /// [currency]    'dop' para pesos dominicanos, 'usd' para dólares
  /// [description] Descripción del pago
  /// [bookingId]   ID de la reserva para asociar el pago
  static Future<PaymentResult> processPayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required String description,
    required String bookingId,
  }) async {
    try {
      // 1. Crear Payment Intent en el servidor (Supabase Edge Function)
      final response = await SupabaseService.client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': amount,
          'currency': currency,
          'description': description,
          'booking_id': bookingId,
          'metadata': {
            'booking_id': bookingId,
            'platform_fee_percent': AppConstants.platformCommission * 100,
          },
        },
      );

      if (response.data == null) {
        return PaymentResult.failure('No se pudo iniciar el pago');
      }

      final clientSecret = response.data['client_secret'] as String?;
      if (clientSecret == null) {
        return PaymentResult.failure('Error al obtener la sesión de pago');
      }

      // 2. Inicializar el Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ServiciosYa',
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: const Color(0xFF0077B6),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      // 3. Mostrar el Payment Sheet al usuario
      await Stripe.instance.presentPaymentSheet();

      // 4. Pago exitoso
      final paymentIntentId = response.data['payment_intent_id'] as String? ?? '';
      return PaymentResult.success(paymentIntentId);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentResult.cancelled();
      }
      return PaymentResult.failure(
          e.error.localizedMessage ?? 'Error en el pago');
    } catch (e) {
      return PaymentResult.failure('Error inesperado: $e');
    }
  }

  /// Calcular el monto de la plataforma (15%)
  static double platformFee(double totalAmount) {
    return totalAmount * AppConstants.platformCommission;
  }

  /// Calcular lo que recibe el prestador (85%)
  static double providerAmount(double totalAmount) {
    return totalAmount * (1 - AppConstants.platformCommission);
  }

  /// Convertir pesos dominicanos a centavos para Stripe
  static int pesosToCentavos(double pesos) {
    return (pesos * 100).round();
  }

  /// Formatear precio en pesos dominicanos
  static String formatPesos(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'RD\$$formatted';
  }

  /// Formatear precio en dólares
  static String formatDollars(double amount) {
    return 'US\$${amount.toStringAsFixed(2)}';
  }

  /// @deprecated — usar formatPesos
  static String formatColones(double amount) => formatPesos(amount);
  /// @deprecated — usar pesosToCentavos
  static int colonesToCentavos(double v) => pesosToCentavos(v);
}
