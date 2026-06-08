import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class AdminStats {
  final int totalUsers;
  final int activeProviders;
  final int totalBookings;
  final int pendingBookings;
  final int pendingVerifications;
  final int openDisputes;
  final double monthlyRevenue;

  const AdminStats({
    required this.totalUsers,
    required this.activeProviders,
    required this.totalBookings,
    required this.pendingBookings,
    required this.pendingVerifications,
    required this.openDisputes,
    required this.monthlyRevenue,
  });

  static const demo = AdminStats(
    totalUsers: 247,
    activeProviders: 58,
    totalBookings: 312,
    pendingBookings: 23,
    pendingVerifications: 4,
    openDisputes: 2,
    monthlyRevenue: 4725000.0,
  );
}

// ─── Demo datasets ────────────────────────────────────────────────────────────
final _demoVerifications = <Map<String, dynamic>>[
  {
    'id': 'vreq-001', 'user_id': 'user-new-001',
    'cedula_number': '031-0345678-9', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
    'cedula_front_url': null, 'cedula_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'José Hernández', 'province': 'Santiago', 'city': 'Santiago de los Caballeros', 'email': 'jose.h@mail.com'},
  },
  {
    'id': 'vreq-002', 'user_id': 'user-new-002',
    'cedula_number': '011-0987654-3', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
    'cedula_front_url': null, 'cedula_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'Daniela Rojas', 'province': 'La Altagracia', 'city': 'Higüey', 'email': 'daniela@mail.com'},
  },
  {
    'id': 'vreq-003', 'user_id': 'user-new-003',
    'cedula_number': '018-1234567-8', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'cedula_front_url': null, 'cedula_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'Marco Solano', 'province': 'Puerto Plata', 'city': 'Puerto Plata', 'email': 'marco@mail.com'},
  },
  {
    'id': 'vreq-004', 'user_id': 'user-new-004',
    'cedula_number': '023-9876543-2', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    'cedula_front_url': null, 'cedula_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'Paola Arias', 'province': 'San Pedro de Macorís', 'city': 'San Pedro de Macorís', 'email': 'paola@mail.com'},
  },
];

final _demoDisputes = <Map<String, dynamic>>[
  {
    'id': 'disp-001', 'booking_id': 'bk-101',
    'type': 'serviceNotCompleted', 'status': 'open',
    'description': 'El prestador no terminó la limpieza de la sala y cobró el precio completo.',
    'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    'admin_notes': null, 'resolution': null,
    'reporter': {'full_name': 'Ana Rodríguez'},
    'reported': {'full_name': 'Carlos Méndez'},
  },
  {
    'id': 'disp-002', 'booking_id': 'bk-098',
    'type': 'propertyDamage', 'status': 'inReview',
    'description': 'El prestador rompió un florero de valor sentimental durante el servicio.',
    'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'admin_notes': 'Esperando respuesta del prestador.',
    'resolution': null,
    'reporter': {'full_name': 'Pedro Castillo'},
    'reported': {'full_name': 'María González'},
  },
];

final _demoUsers = <Map<String, dynamic>>[
  {'id': '1', 'full_name': 'Ana Rodríguez', 'email': 'ana@demo.com', 'role': 'client', 'province': 'Distrito Nacional', 'city': 'Piantini', 'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'is_verified': true, 'is_active': true},
  {'id': '2', 'full_name': 'Carlos Méndez', 'email': 'carlos@demo.com', 'role': 'provider', 'province': 'Distrito Nacional', 'city': 'Naco', 'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(), 'is_verified': true, 'is_active': true},
  {'id': '3', 'full_name': 'María González', 'email': 'maria@demo.com', 'role': 'provider', 'province': 'Distrito Nacional', 'city': 'Bella Vista', 'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(), 'is_verified': true, 'is_active': true},
  {'id': '4', 'full_name': 'Luis Vargas', 'email': 'luis@demo.com', 'role': 'provider', 'province': 'Santiago', 'city': 'Santiago', 'created_at': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(), 'is_verified': false, 'is_active': true},
  {'id': '5', 'full_name': 'Pedro Castillo', 'email': 'pedro@demo.com', 'role': 'client', 'province': 'San Cristóbal', 'city': 'San Cristóbal', 'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(), 'is_verified': false, 'is_active': true},
];

final _demoBookings = <Map<String, dynamic>>[
  {'id': 'bk-101', 'status': 'pending', 'amount': 2500.0, 'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'service_name': 'Limpieza del hogar', 'client': {'full_name': 'Ana Rodríguez'}, 'provider': {'full_name': 'Carlos Méndez'}},
  {'id': 'bk-100', 'status': 'completed', 'amount': 4500.0, 'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'service_name': 'Cuidado de mascotas', 'client': {'full_name': 'Pedro Castillo'}, 'provider': {'full_name': 'María González'}},
  {'id': 'bk-099', 'status': 'accepted', 'amount': 1800.0, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'service_name': 'Jardinería', 'client': {'full_name': 'Valeria Soto'}, 'provider': {'full_name': 'Luis Vargas'}},
];

// ─── Providers ────────────────────────────────────────────────────────────────

/// Check if current user has admin role
final adminAccessProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(demoModeProvider)) return true;
  final user = SupabaseService.currentUser;
  if (user == null) return false;
  try {
    final data = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return (data?['role'] as String?) == 'admin';
  } catch (_) {
    return false;
  }
});

/// Aggregate stats — parallel count queries with per-query error isolation
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  if (ref.watch(demoModeProvider)) return AdminStats.demo;

  int totalUsers = 0, activeProviders = 0, totalBookings = 0,
      pendingBookings = 0, pendingVerifications = 0, openDisputes = 0;
  double monthlyRevenue = 0;

  await Future.wait([
    // Total users
    SupabaseService.client
        .from('profiles')
        .select()
        .count(CountOption.exact)
        .then((r) => totalUsers = r.count ?? 0)
        .catchError((_) => totalUsers = 0),

    // Active providers
    SupabaseService.client
        .from('provider_profiles')
        .select()
        .eq('is_available', true)
        .count(CountOption.exact)
        .then((r) => activeProviders = r.count ?? 0)
        .catchError((_) => activeProviders = 0),

    // Total bookings
    SupabaseService.client
        .from('bookings')
        .select()
        .count(CountOption.exact)
        .then((r) => totalBookings = r.count ?? 0)
        .catchError((_) => totalBookings = 0),

    // Pending bookings
    SupabaseService.client
        .from('bookings')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact)
        .then((r) => pendingBookings = r.count ?? 0)
        .catchError((_) => pendingBookings = 0),

    // Pending verifications
    SupabaseService.client
        .from('verification_requests')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact)
        .then((r) => pendingVerifications = r.count ?? 0)
        .catchError((_) => pendingVerifications = 0),

    // Open disputes
    SupabaseService.client
        .from('disputes')
        .select()
        .eq('status', 'open')
        .count(CountOption.exact)
        .then((r) => openDisputes = r.count ?? 0)
        .catchError((_) => openDisputes = 0),

    // Monthly revenue from completed bookings
    () async {
      try {
        final start = DateTime(DateTime.now().year, DateTime.now().month, 1)
            .toIso8601String();
        final rows = await SupabaseService.client
            .from('bookings')
            .select('amount')
            .eq('status', 'completed')
            .gte('created_at', start);
        monthlyRevenue = (rows as List<dynamic>).fold<double>(
          0, (s, b) => s + ((b['amount'] as num?) ?? 0).toDouble(),
        );
      } catch (_) {}
    }(),
  ]);

  return AdminStats(
    totalUsers: totalUsers,
    activeProviders: activeProviders,
    totalBookings: totalBookings,
    pendingBookings: pendingBookings,
    pendingVerifications: pendingVerifications,
    openDisputes: openDisputes,
    monthlyRevenue: monthlyRevenue,
  );
});

/// Pending verification requests
final adminVerificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(demoModeProvider)) return List.of(_demoVerifications);
  try {
    final data = await SupabaseService.client
        .from('verification_requests')
        .select('*, profile:profiles!user_id(full_name, province, city, email)')
        .eq('status', 'pending')
        .order('submitted_at', ascending: false);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

/// Open + inReview disputes
final adminDisputesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(demoModeProvider)) return List.of(_demoDisputes);
  try {
    final data = await SupabaseService.client
        .from('disputes')
        .select(
            '*, reporter:profiles!reporter_id(full_name), reported:profiles!reported_id(full_name)')
        .inFilter('status', ['open', 'inReview'])
        .order('created_at', ascending: false);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    // Fallback: query without FK joins
    try {
      final data = await SupabaseService.client
          .from('disputes')
          .select()
          .inFilter('status', ['open', 'inReview'])
          .order('created_at', ascending: false);
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
});

/// Last 10 registered users
final adminRecentUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(demoModeProvider)) return List.of(_demoUsers);
  try {
    final data = await SupabaseService.client
        .from('profiles')
        .select('id, full_name, email, role, province, city, created_at, is_verified, is_active')
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

/// Last 10 bookings with client + provider names
final adminRecentBookingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(demoModeProvider)) return List.of(_demoBookings);
  try {
    final data = await SupabaseService.client
        .from('bookings')
        .select(
            '*, client:profiles!client_id(full_name), provider:provider_profiles!provider_id(full_name)')
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    // Fallback without joins
    try {
      final data = await SupabaseService.client
          .from('bookings')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
});
