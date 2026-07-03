class AppConstants {
  AppConstants._();

  // ⚠️ Reemplaza con tus credenciales reales de supabase.com
  static const String supabaseUrl = 'https://ivexcnunszcqoqzzdlfz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2ZXhjbnVuc3pjcW9xenpkbGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5MDg4MzksImV4cCI6MjA5NTQ4NDgzOX0.q-65Ncoe7GAU3TvUSQg_nWD0j-jRzPmB8vbEH-kft9A';
  static const String googleMapsApiKey = 'AIzaSyAl7co1z59RELF4bZDO2HCRcWDtINPh560';
  // Reservado para futura integración de pagos (PayPal / AZUL)
  static const String paymentGatewayKey = '';
  // Clave pública VAPID para Web Push (la privada vive en app_secrets,
  // solo la lee la Edge Function notify-new-request con service role).
  static const String vapidPublicKey =
      'BFAqBBJbBSSS2TQewkQNZsB4PRMypNG9Txie9VHD8ZfvjAzJ9IvljtnALRrkJRsQCNipc_r65WgvTeNbhhfxwJQ';

  static const double defaultRadius = 50.0; // km
  static const int maxPhotosPerProfile = 6;
  // ── Modelo de comisión 5% + 5% ───────────────────────────────────────────
  // clientFee   → "Garantía YALO"      (se añade al precio base; lo paga el cliente)
  // providerFee → "Membresía de Visibilidad"   (se descuenta del cobro; lo paga el prestador)
  static const double clientFee  = 0.05; // 5% — Garantía YALO
  static const double providerFee = 0.05; // 5% — Membresía de Visibilidad
  // Referencia de comisión total (compatible con código existente)
  static const double platformCommission = clientFee + providerFee; // 10%

  static const List<String> serviceCategories = [
    'Limpieza del hogar',
    'Mantenimiento de patios',
    'Cuidado de mascotas',
    'Lavado de vehículos',
    'Limpieza de oficinas',
    'Mudanzas y carga',
    'Plomería básica',
    'Electricidad básica',
  ];
}
