import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_provider_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/demo_data.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final locationFilterProvider =
    StateProvider<LocationFilter>((ref) => const LocationFilter());

// Bookings creados durante la sesión demo (se acumulan en memoria)
final demoCreatedBookingsProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

class LocationFilter {
  final String? province;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  const LocationFilter({
    this.province,
    this.city,
    this.latitude,
    this.longitude,
    this.radiusKm = 50.0,
  });

  LocationFilter copyWith({
    String? province,
    String? city,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return LocationFilter(
      province: province ?? this.province,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}

// ─── Lista de prestadores ─────────────────────────────────────────────────────
//
// SQL equivalente:
//   SELECT pp.*, ps.*
//   FROM provider_profiles pp
//   LEFT JOIN provider_services ps ON ps.provider_id = pp.id
//   WHERE pp.is_available = true
//   [AND pp.province = $province]
//   [AND pp.city = $city]
//   ORDER BY pp.rating DESC
//
final providersListProvider =
    FutureProvider.family<List<ServiceProviderModel>, String?>(
        (ref, categoryId) async {
  // ── Modo demo ────────────────────────────────────────────────────────────────
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 600));
    var list = [...DemoData.providers];
    if (categoryId != null && categoryId.isNotEmpty) {
      list = list
          .where((p) => p.services.any((s) => s.categoryId == categoryId))
          .toList();
    }
    return list;
  }

  // ── Supabase real ────────────────────────────────────────────────────────────
  final locationFilter = ref.watch(locationFilterProvider);

  try {
    var query = SupabaseService.client
        .from('provider_profiles')
        .select('''
          id,
          user_id,
          full_name,
          bio,
          province,
          city,
          latitude,
          longitude,
          is_available,
          is_verified,
          rating,
          review_count,
          completed_jobs,
          photo_urls,
          avatar_url,
          member_since,
          level,
          provider_services (
            id,
            category_id,
            category_name,
            pricing_type,
            fixed_price,
            price_description,
            form_fields
          )
        ''')
        .eq('is_available', true);

    if (locationFilter.province != null &&
        locationFilter.province!.isNotEmpty) {
      query = query.eq('province', locationFilter.province!);
    }
    if (locationFilter.city != null && locationFilter.city!.isNotEmpty) {
      query = query.eq('city', locationFilter.city!);
    }

    final data = await query.order('rating', ascending: false);

    List<ServiceProviderModel> providers = (data as List<dynamic>)
        .map((json) => _parseProvider(json as Map<String, dynamic>))
        .toList();

    // Filtro por categoría en cliente (más flexible que un JOIN WHERE)
    if (categoryId != null && categoryId.isNotEmpty) {
      providers = providers
          .where((p) => p.services.any((s) => s.categoryId == categoryId))
          .toList();
    }

    return providers;
  } catch (e) {
    // Si Supabase falla (RLS, red, etc.) devuelve lista vacía en vez de crash
    return [];
  }
});

// ─── Detalle de un prestador ──────────────────────────────────────────────────
//
// SQL equivalente:
//   SELECT pp.*, ps.*
//   FROM provider_profiles pp
//   LEFT JOIN provider_services ps ON ps.provider_id = pp.id
//   WHERE pp.id = $providerId
//   LIMIT 1
//
final providerDetailProvider =
    FutureProvider.family<ServiceProviderModel?, String>((ref, providerId) async {
  // ── Modo demo ────────────────────────────────────────────────────────────────
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      return DemoData.providers.firstWhere((p) => p.id == providerId);
    } catch (_) {
      return DemoData.providers.isNotEmpty ? DemoData.providers.first : null;
    }
  }

  // ── Supabase real ────────────────────────────────────────────────────────────
  try {
    final data = await SupabaseService.client
        .from('provider_profiles')
        .select('''
          id,
          user_id,
          full_name,
          bio,
          province,
          city,
          latitude,
          longitude,
          is_available,
          is_verified,
          rating,
          review_count,
          completed_jobs,
          photo_urls,
          avatar_url,
          member_since,
          level,
          provider_services (
            id,
            category_id,
            category_name,
            pricing_type,
            fixed_price,
            price_description,
            form_fields
          )
        ''')
        .eq('id', providerId)
        .maybeSingle(); // maybeSingle → null si no existe, no lanza excepción

    if (data == null) return null;
    return _parseProvider(data);
  } catch (e) {
    return null;
  }
});

// ─── Reseñas de un prestador ──────────────────────────────────────────────────
//
// SQL equivalente:
//   SELECT r.id, r.client_id, r.rating, r.comment, r.created_at,
//          p.full_name, p.avatar_url
//   FROM reviews r
//   LEFT JOIN profiles p ON p.id = r.client_id
//   WHERE r.provider_id = $providerId
//   ORDER BY r.created_at DESC
//   LIMIT 20
//
final providerReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, providerId) async {
  // ── Modo demo ────────────────────────────────────────────────────────────────
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 300));
    return providerId == 'prov-001' ? DemoData.reviewsForProv001 : [];
  }

  // ── Supabase real ────────────────────────────────────────────────────────────
  try {
    final data = await SupabaseService.client
        .from('reviews')
        .select('''
          id,
          client_id,
          rating,
          comment,
          created_at,
          profiles:client_id (
            full_name,
            avatar_url
          )
        ''')
        .eq('provider_id', providerId)
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List<dynamic>).map((json) {
      // Supabase devuelve el join bajo la clave del nombre de tabla ("profiles")
      // o como objeto anidado según la sintaxis usada.
      final profile = (json['profiles'] is Map)
          ? json['profiles'] as Map<String, dynamic>
          : null;

      return ReviewModel(
        id: json['id'] as String,
        clientId: json['client_id'] as String,
        clientName: profile?['full_name'] as String? ?? 'Cliente Verificado',
        clientAvatarUrl: profile?['avatar_url'] as String?,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

// ─── Booking individual — tiempo real (para pantalla de búsqueda) ────────────
final singleBookingProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, bookingId) {
  if (bookingId.isEmpty) return Stream.value(null);
  return SupabaseService.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('id', bookingId)
      .map<Map<String, dynamic>?>((rows) =>
          rows.isNotEmpty ? rows.first : null);
});

// ─── Solicitudes abiertas — para prestadores (broadcast sin provider_id) ─────
final openRequestsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, province) {
  return SupabaseService.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .map<List<Map<String, dynamic>>>((rows) => rows
          .where((r) =>
              r['provider_id'] == null &&
              (province.isEmpty || r['client_province'] == province))
          .toList());
});

// ─── Reservas del cliente — tiempo real ──────────────────────────────────────
//
// SQL equivalente:
//   SELECT * FROM bookings
//   WHERE client_id = $userId
//   ORDER BY created_at DESC
//
final myBookingsProvider = StreamProvider<List<dynamic>>((ref) async* {
  final isDemo = ref.watch(demoModeProvider);

  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 500));
    final created = ref.watch(demoCreatedBookingsProvider);
    yield [...created, ...DemoData.clientBookings];
    return;
  }

  final user = SupabaseService.currentUser;
  if (user == null) {
    yield [];
    return;
  }

  yield* SupabaseService.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('client_id', user.id)
      .order('created_at', ascending: false)
      .map((rows) => rows as List<dynamic>);
});

// ─── Reservas del prestador — tiempo real ────────────────────────────────────
//
// SQL equivalente:
//   SELECT * FROM bookings
//   WHERE provider_id = $providerProfileId
//   ORDER BY created_at DESC
//
final providerBookingsProvider = StreamProvider<List<dynamic>>((ref) async* {
  final isDemo = ref.watch(demoModeProvider);

  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 500));
    yield DemoData.providerBookings;
    return;
  }

  final user = SupabaseService.currentUser;
  if (user == null) {
    yield [];
    return;
  }

  final profile = await SupabaseService.client
      .from('provider_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (profile == null) {
    yield [];
    return;
  }

  final providerId = profile['id'] as String;

  yield* SupabaseService.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('provider_id', providerId)
      .order('created_at', ascending: false)
      .map((rows) => rows as List<dynamic>);
});

// ─── Parser interno ───────────────────────────────────────────────────────────
ServiceProviderModel _parseProvider(Map<String, dynamic> json) {
  final services = (json['provider_services'] as List<dynamic>?)
          ?.map((s) => ProviderService.fromJson(s as Map<String, dynamic>))
          .toList() ??
      [];

  return ServiceProviderModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    fullName: json['full_name'] as String? ?? 'Sin nombre',
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: json['review_count'] as int? ?? 0,
    completedJobs: json['completed_jobs'] as int? ?? 0,
    services: services,
    province: json['province'] as String? ?? '',
    city: json['city'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    isAvailable: json['is_available'] as bool? ?? true,
    isVerified: json['is_verified'] as bool? ?? false,
    photoUrls: (json['photo_urls'] as List<dynamic>?)
            ?.map((p) => p as String)
            .toList() ??
        [],
    memberSince: _parseDate(json['member_since'] ?? json['created_at']),
  );
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  try {
    return DateTime.parse(value as String);
  } catch (_) {
    return DateTime.now();
  }
}
