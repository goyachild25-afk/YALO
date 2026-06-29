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
  final int completedBookings;
  final int cancelledOrRejectedBookings;

  const AdminStats({
    required this.totalUsers,
    required this.activeProviders,
    required this.totalBookings,
    required this.pendingBookings,
    required this.pendingVerifications,
    required this.openDisputes,
    required this.monthlyRevenue,
    this.completedBookings = 0,
    this.cancelledOrRejectedBookings = 0,
  });

  /// % de reservas completadas sobre el total (eficiencia operativa).
  double get completionRate =>
      totalBookings == 0 ? 0 : completedBookings / totalBookings;

  /// % de reservas canceladas o rechazadas sobre el total.
  double get cancellationRate =>
      totalBookings == 0 ? 0 : cancelledOrRejectedBookings / totalBookings;

  static const demo = AdminStats(
    totalUsers: 247,
    activeProviders: 58,
    totalBookings: 312,
    pendingBookings: 23,
    pendingVerifications: 4,
    openDisputes: 2,
    monthlyRevenue: 4725000.0,
    completedBookings: 248,
    cancelledOrRejectedBookings: 19,
  );
}

class ServiceRevenue {
  final String name;
  final double total;
  final int count;
  const ServiceRevenue({required this.name, required this.total, required this.count});
}

class WeeklyRevenue {
  final DateTime weekStart;
  final double total;
  const WeeklyRevenue({required this.weekStart, required this.total});
}

class ProviderRevenue {
  final String name;
  final double total;
  final int jobs;
  const ProviderRevenue({required this.name, required this.total, required this.jobs});
}

class AdminFinanceData {
  final List<ServiceRevenue> byService;
  final List<WeeklyRevenue> weeklyTrend;
  final List<ProviderRevenue> topProviders;

  const AdminFinanceData({
    required this.byService,
    required this.weeklyTrend,
    required this.topProviders,
  });

  static const empty = AdminFinanceData(byService: [], weeklyTrend: [], topProviders: []);

  static final demo = AdminFinanceData(
    byService: [
      const ServiceRevenue(name: 'Limpieza del hogar', total: 185000, count: 62),
      const ServiceRevenue(name: 'Cuidado de mascotas', total: 96000, count: 38),
      const ServiceRevenue(name: 'Jardinería', total: 71500, count: 29),
      const ServiceRevenue(name: 'Plomería básica', total: 54000, count: 17),
      const ServiceRevenue(name: 'Lavado de vehículos', total: 38500, count: 21),
    ],
    weeklyTrend: List.generate(8, (i) {
      final weekStart = DateTime.now().subtract(Duration(days: (7 - i) * 7));
      return WeeklyRevenue(weekStart: weekStart, total: 38000 + (i * 5400) - (i % 3 == 0 ? 9000 : 0));
    }),
    topProviders: [
      const ProviderRevenue(name: 'Carlos Méndez', total: 62000, jobs: 24),
      const ProviderRevenue(name: 'María González', total: 54500, jobs: 21),
      const ProviderRevenue(name: 'Luis Vargas', total: 41000, jobs: 16),
      const ProviderRevenue(name: 'Rosa Jiménez', total: 33500, jobs: 14),
      const ProviderRevenue(name: 'Pedro Familia', total: 28000, jobs: 11),
    ],
  );
}

class _Acc {
  double total = 0;
  int count = 0;
}

DateTime _startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

// ─── Demo datasets ────────────────────────────────────────────────────────────
final _demoVerifications = <Map<String, dynamic>>[
  {
    'id': 'vreq-001', 'user_id': 'user-new-001',
    'id_number': '031-0345678-9', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
    'id_front_url': null, 'id_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'José Hernández', 'province': 'Santiago', 'city': 'Santiago de los Caballeros', 'email': 'jose.h@mail.com'},
  },
  {
    'id': 'vreq-002', 'user_id': 'user-new-002',
    'id_number': '011-0987654-3', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
    'id_front_url': null, 'id_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'Daniela Rojas', 'province': 'La Altagracia', 'city': 'Higüey', 'email': 'daniela@mail.com'},
  },
  {
    'id': 'vreq-003', 'user_id': 'user-new-003',
    'id_number': '018-1234567-8', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'id_front_url': null, 'id_back_url': null, 'selfie_url': null,
    'profile': {'full_name': 'Marco Solano', 'province': 'Puerto Plata', 'city': 'Puerto Plata', 'email': 'marco@mail.com'},
  },
  {
    'id': 'vreq-004', 'user_id': 'user-new-004',
    'id_number': '023-9876543-2', 'status': 'pending',
    'submitted_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    'id_front_url': null, 'id_back_url': null, 'selfie_url': null,
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
  {'id': 'bk-101', 'status': 'pending', 'agreed_price': 2500.0, 'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'service_name': 'Limpieza del hogar', 'client': {'full_name': 'Ana Rodríguez'}, 'provider': {'full_name': 'Carlos Méndez'}},
  {'id': 'bk-100', 'status': 'completed', 'agreed_price': 4500.0, 'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'service_name': 'Cuidado de mascotas', 'client': {'full_name': 'Pedro Castillo'}, 'provider': {'full_name': 'María González'}},
  {'id': 'bk-099', 'status': 'accepted', 'agreed_price': 1800.0, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'service_name': 'Jardinería', 'client': {'full_name': 'Valeria Soto'}, 'provider': {'full_name': 'Luis Vargas'}},
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
      pendingBookings = 0, pendingVerifications = 0, openDisputes = 0,
      completedBookings = 0, cancelledOrRejectedBookings = 0;
  double monthlyRevenue = 0;

  await Future.wait([
    // Total users
    SupabaseService.client
        .from('profiles')
        .select()
        .count(CountOption.exact)
        .then((r) => totalUsers = r.count)
        .catchError((_) => totalUsers = 0),

    // Active providers
    SupabaseService.client
        .from('provider_profiles')
        .select()
        .eq('is_available', true)
        .count(CountOption.exact)
        .then((r) => activeProviders = r.count)
        .catchError((_) => activeProviders = 0),

    // Total bookings
    SupabaseService.client
        .from('bookings')
        .select()
        .count(CountOption.exact)
        .then((r) => totalBookings = r.count)
        .catchError((_) => totalBookings = 0),

    // Pending bookings
    SupabaseService.client
        .from('bookings')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact)
        .then((r) => pendingBookings = r.count)
        .catchError((_) => pendingBookings = 0),

    // Pending verifications
    SupabaseService.client
        .from('verification_requests')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact)
        .then((r) => pendingVerifications = r.count)
        .catchError((_) => pendingVerifications = 0),

    // Open disputes
    SupabaseService.client
        .from('disputes')
        .select()
        .eq('status', 'open')
        .count(CountOption.exact)
        .then((r) => openDisputes = r.count)
        .catchError((_) => openDisputes = 0),

    // Completed bookings (tasa de finalización)
    SupabaseService.client
        .from('bookings')
        .select()
        .eq('status', 'completed')
        .count(CountOption.exact)
        .then((r) => completedBookings = r.count)
        .catchError((_) => completedBookings = 0),

    // Cancelled or rejected bookings (tasa de cancelación)
    SupabaseService.client
        .from('bookings')
        .select()
        .inFilter('status', ['cancelled', 'rejected'])
        .count(CountOption.exact)
        .then((r) => cancelledOrRejectedBookings = r.count)
        .catchError((_) => cancelledOrRejectedBookings = 0),

    // Monthly revenue from completed bookings
    () async {
      try {
        final start = DateTime(DateTime.now().year, DateTime.now().month, 1)
            .toIso8601String();
        final rows = await SupabaseService.client
            .from('bookings')
            .select('agreed_price')
            .eq('status', 'completed')
            .gte('created_at', start);
        monthlyRevenue = (rows as List<dynamic>).fold<double>(
          0, (s, b) => s + ((b['agreed_price'] as num?) ?? 0).toDouble(),
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
    completedBookings: completedBookings,
    cancelledOrRejectedBookings: cancelledOrRejectedBookings,
  );
});

/// Datos financieros agregados: ingresos por servicio, tendencia semanal y
/// top prestadores por ingresos generados (últimos 90 días, bookings completed).
final adminFinanceDataProvider =
    FutureProvider.autoDispose<AdminFinanceData>((ref) async {
  if (ref.watch(demoModeProvider)) return AdminFinanceData.demo;

  List<Map<String, dynamic>> list;
  try {
    final since = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    final rows = await SupabaseService.client
        .from('bookings')
        .select(
            'service_name, agreed_price, created_at, provider:provider_profiles!provider_id(full_name)')
        .eq('status', 'completed')
        .gte('created_at', since);
    list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    try {
      final since = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      final rows = await SupabaseService.client
          .from('bookings')
          .select('service_name, agreed_price, created_at')
          .eq('status', 'completed')
          .gte('created_at', since);
      list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return AdminFinanceData.empty;
    }
  }

  // ── Ingresos por servicio ──────────────────────────────────────────────
  final byServiceMap = <String, _Acc>{};
  for (final b in list) {
    final name = b['service_name'] as String? ?? 'Otro';
    final price = (b['agreed_price'] as num?)?.toDouble() ?? 0;
    final acc = byServiceMap.putIfAbsent(name, () => _Acc());
    acc.total += price;
    acc.count++;
  }
  final byService = byServiceMap.entries
      .map((e) => ServiceRevenue(name: e.key, total: e.value.total, count: e.value.count))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  // ── Tendencia semanal (últimas 8 semanas) ──────────────────────────────
  final now = DateTime.now();
  final weekBuckets = <DateTime, double>{};
  for (int i = 7; i >= 0; i--) {
    weekBuckets[_startOfWeek(now.subtract(Duration(days: i * 7)))] = 0;
  }
  for (final b in list) {
    final created = DateTime.tryParse(b['created_at'] as String? ?? '');
    if (created == null) continue;
    final weekStart = _startOfWeek(created);
    if (weekBuckets.containsKey(weekStart)) {
      weekBuckets[weekStart] =
          weekBuckets[weekStart]! + ((b['agreed_price'] as num?)?.toDouble() ?? 0);
    }
  }
  final weeklyTrend = weekBuckets.entries
      .map((e) => WeeklyRevenue(weekStart: e.key, total: e.value))
      .toList()
    ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

  // ── Top prestadores por ingresos ───────────────────────────────────────
  final providerMap = <String, _Acc>{};
  for (final b in list) {
    final provider = (b['provider'] as Map?)?.cast<String, dynamic>();
    final name = provider?['full_name'] as String? ?? 'Sin asignar';
    final price = (b['agreed_price'] as num?)?.toDouble() ?? 0;
    final acc = providerMap.putIfAbsent(name, () => _Acc());
    acc.total += price;
    acc.count++;
  }
  final topProviders = providerMap.entries
      .map((e) => ProviderRevenue(name: e.key, total: e.value.total, jobs: e.value.count))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return AdminFinanceData(
    byService: byService.take(8).toList(),
    weeklyTrend: weeklyTrend,
    topProviders: topProviders.take(5).toList(),
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

/// Todas las categorías de servicio (para activar/desactivar desde el panel)
final adminServiceCategoriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    return [
      {'id': 'home_cleaning', 'name': 'Limpieza del hogar', 'emoji': '🏠', 'is_active': true, 'sort_order': 1},
      {'id': 'pet_care', 'name': 'Cuidado de mascotas', 'emoji': '🐾', 'is_active': true, 'sort_order': 3},
      {'id': 'plumbing', 'name': 'Plomería básica', 'emoji': '🔧', 'is_active': true, 'sort_order': 7},
      {'id': 'styling', 'name': 'Estilismo a domicilio', 'emoji': '💈', 'is_active': false, 'sort_order': 25},
    ];
  }
  try {
    final data = await SupabaseService.client
        .from('service_categories')
        .select('id, name, emoji, is_active, sort_order')
        .order('sort_order');
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
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
