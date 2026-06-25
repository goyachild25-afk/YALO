import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String emoji;
  final Color color;
  final Color backgroundColor;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.backgroundColor,
  });
}

// ── 8 categorías principales ──────────────────────────────────────────────────
final List<ServiceCategory> serviceCategories = [
  ServiceCategory(
    id: 'cleaning',
    name: 'Limpieza',
    description: 'Hogar, oficinas, limpieza profunda y piscinas',
    icon: Icons.cleaning_services_outlined,
    emoji: '🧹',
    color: const Color(0xFF0D9488),
    backgroundColor: const Color(0xFFCCFBF1),
  ),
  ServiceCategory(
    id: 'garden',
    name: 'Jardín',
    description: 'Poda, siembra, mantenimiento y exteriores',
    icon: Icons.grass_outlined,
    emoji: '🌿',
    color: const Color(0xFF16A34A),
    backgroundColor: const Color(0xFFDCFCE7),
  ),
  ServiceCategory(
    id: 'pets',
    name: 'Mascotas',
    description: 'Baño, paseo, grooming y guardería',
    icon: Icons.pets_outlined,
    emoji: '🐾',
    color: const Color(0xFFD97706),
    backgroundColor: const Color(0xFFFEF3C7),
  ),
  ServiceCategory(
    id: 'vehicles',
    name: 'Vehículos',
    description: 'Lavado exterior, interior y detailing',
    icon: Icons.directions_car_outlined,
    emoji: '🚗',
    color: const Color(0xFF7C3AED),
    backgroundColor: const Color(0xFFEDE9FE),
  ),
  ServiceCategory(
    id: 'maintenance',
    name: 'Mantenimiento',
    description: 'Plomería, electricidad, pintura, A/C y más',
    icon: Icons.handyman_outlined,
    emoji: '🔧',
    color: const Color(0xFF0F766E),
    backgroundColor: const Color(0xFFCCFBF1),
  ),
  ServiceCategory(
    id: 'caregiving',
    name: 'Cuidado',
    description: 'Adultos mayores, niños y acompañamiento',
    icon: Icons.favorite_outline,
    emoji: '❤️',
    color: const Color(0xFFDB2777),
    backgroundColor: const Color(0xFFFCE7F3),
  ),
  ServiceCategory(
    id: 'cooking',
    name: 'Cocina',
    description: 'Cocinero a domicilio, catering y dietas',
    icon: Icons.restaurant_outlined,
    emoji: '🍳',
    color: const Color(0xFFEF4444),
    backgroundColor: const Color(0xFFFEE2E2),
  ),
  ServiceCategory(
    id: 'moving',
    name: 'Mudanzas',
    description: 'Carga, traslado y mudanzas locales o provinciales',
    icon: Icons.local_shipping_outlined,
    emoji: '📦',
    color: const Color(0xFF1D4ED8),
    backgroundColor: const Color(0xFFDBEAFE),
  ),
];

// ── Mapeo categoría amplia (navegación del cliente) → categorías granulares
//    (las que usan los prestadores en provider_services.category_id) ─────────
// El cliente navega/solicita por estas 8 categorías amplias, pero cada
// prestador define sus servicios con las categorías granulares de
// kServiceCategories (ver onboarding_provider.dart). Sin este mapeo, una
// solicitud de "Mantenimiento" o "Jardín" nunca encuentra prestadores
// elegibles, porque los IDs no coinciden directamente.
const Map<String, List<String>> broadToGranularCategoryIds = {
  'cleaning': ['home_cleaning', 'office_cleaning'],
  'garden': ['gardening'],
  'pets': ['pet_care'],
  'vehicles': ['car_wash'],
  'maintenance': [
    'plumbing',
    'electrical',
    'painting',
    'carpentry',
    'ac_service',
    'pest_control',
    'appliance_repair',
  ],
  'caregiving': ['elderly_care', 'babysitting'],
  'cooking': ['cooking'],
  'moving': ['moving'],
};
