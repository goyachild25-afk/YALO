class AppConstants {
  AppConstants._();

  // ⚠️ Reemplaza con tus credenciales reales de supabase.com
  static const String supabaseUrl = 'https://ivexcnunszcqoqzzdlfz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2ZXhjbnVuc3pjcW9xenpkbGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5MDg4MzksImV4cCI6MjA5NTQ4NDgzOX0.q-65Ncoe7GAU3TvUSQg_nWD0j-jRzPmB8vbEH-kft9A';
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String stripePublishableKey = 'YOUR_STRIPE_PUBLISHABLE_KEY';

  static const double defaultRadius = 50.0; // km
  static const int maxPhotosPerProfile = 6;
  static const double platformCommission = 0.15; // 15%

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
