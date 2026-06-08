import 'package:shared_preferences/shared_preferences.dart';

// ─── Provincias de República Dominicana (32) ──────────────────────────────────
const List<String> kProvinciasRD = [
  'Distrito Nacional',
  'Azua',
  'Baoruco',
  'Barahona',
  'Dajabón',
  'Duarte',
  'Elías Piña',
  'El Seibo',
  'Espaillat',
  'Hato Mayor',
  'Hermanas Mirabal',
  'Independencia',
  'La Altagracia',
  'La Romana',
  'La Vega',
  'María Trinidad Sánchez',
  'Monseñor Nouel',
  'Monte Cristi',
  'Monte Plata',
  'Pedernales',
  'Peravia',
  'Puerto Plata',
  'Samaná',
  'Sánchez Ramírez',
  'San Cristóbal',
  'San José de Ocoa',
  'San Juan',
  'San Pedro de Macorís',
  'Santiago',
  'Santiago Rodríguez',
  'Santo Domingo',
  'Valverde',
];

// ─── Categorías de servicios (17) ─────────────────────────────────────────────
const List<Map<String, String>> kServiceCategories = [
  {'id': 'home_cleaning',    'name': 'Limpieza del hogar',               'emoji': '🏠'},
  {'id': 'office_cleaning',  'name': 'Limpieza de oficinas',             'emoji': '🏢'},
  {'id': 'pet_care',         'name': 'Cuidado de mascotas',              'emoji': '🐾'},
  {'id': 'plumbing',         'name': 'Plomería',                         'emoji': '🔧'},
  {'id': 'electrical',       'name': 'Electricidad',                     'emoji': '⚡'},
  {'id': 'painting',         'name': 'Pintura',                          'emoji': '🎨'},
  {'id': 'carpentry',        'name': 'Carpintería',                      'emoji': '🪚'},
  {'id': 'gardening',        'name': 'Jardinería',                       'emoji': '🌿'},
  {'id': 'moving',           'name': 'Mudanzas',                         'emoji': '📦'},
  {'id': 'pest_control',     'name': 'Fumigación',                       'emoji': '🪲'},
  {'id': 'laundry',          'name': 'Lavandería',                       'emoji': '👕'},
  {'id': 'cooking',          'name': 'Cocina / Chef',                    'emoji': '👨‍🍳'},
  {'id': 'babysitting',      'name': 'Cuidado de niños',                 'emoji': '👶'},
  {'id': 'elderly_care',     'name': 'Cuidado de adultos mayores',       'emoji': '👴'},
  {'id': 'appliance_repair', 'name': 'Reparación de electrodomésticos',  'emoji': '🔌'},
  {'id': 'ac_service',       'name': 'Aire acondicionado',               'emoji': '❄️'},
  {'id': 'security',         'name': 'Seguridad y vigilancia',           'emoji': '🔒'},
];

// ─── SharedPreferences helpers ────────────────────────────────────────────────
const String _kOnboardingDonePrefix = 'onboarding_done_';
const String _kVerificationSubmittedPrefix = 'verification_submitted_';

Future<bool> isOnboardingComplete(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_kOnboardingDonePrefix$userId') ?? false;
}

Future<void> markOnboardingComplete(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('$_kOnboardingDonePrefix$userId', true);
}

Future<bool> isVerificationSubmitted(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_kVerificationSubmittedPrefix$userId') ?? false;
}

Future<void> markVerificationSubmitted(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('$_kVerificationSubmittedPrefix$userId', true);
}
