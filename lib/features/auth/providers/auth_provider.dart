import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';

// ─── Stream de sesión real ────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.authStateChanges.map((s) => s.session?.user);
});

// ─── Perfil del usuario actual ────────────────────────────────────────────────
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Modo demo: devuelve el usuario demo sin tocar Supabase
  final demoUser = ref.watch(demoUserProvider);
  if (demoUser != null) return demoUser;

  final user = SupabaseService.currentUser;
  if (user == null) return null;

  try {
    // maybeSingle() devuelve null en lugar de lanzar si no hay fila
    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserModel.fromJson(data);
  } catch (_) {
    // Perfil aún no disponible (confirmación de email pendiente, etc.)
    return null;
  }
});

// ─── Controlador de auth ──────────────────────────────────────────────────────
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  // ── Registro ────────────────────────────────────────────────────────────────
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    required String province,
    required String city,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Pasar todos los datos como metadata para que el trigger de DB
      // los use al crear el perfil automáticamente en auth.users
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role.name,
          'province': province,
          'city': city,
        },
      );

      if (response.user != null) {
        if (response.session != null) {
          // Email confirmation desactivada → sesión inmediata.
          // Creamos el perfil directamente con las credenciales del usuario.
          await _createProfile(
            userId: response.user!.id,
            email: email,
            fullName: fullName,
            phone: phone,
            role: role,
            province: province,
            city: city,
          );
        }
        // Si session == null: confirmación de email pendiente.
        // El trigger on_auth_user_created (ver SQL abajo) crea el perfil
        // en auth.users automáticamente. En el primer login se completa el resto.
      }

      _clearDemo();
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Login ───────────────────────────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response =
          await SupabaseService.signIn(email: email, password: password);

      // Si el perfil no existe aún (flujo email-confirmation: trigger no corrió
      // o creación manual falló), lo creamos ahora con los datos del metadata
      if (response.user != null) {
        final existing = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (existing == null) {
          final meta = response.user!.userMetadata ?? {};
          await _createProfile(
            userId: response.user!.id,
            email: email,
            fullName: meta['full_name'] as String? ??
                email.split('@').first,
            phone: meta['phone'] as String? ?? '',
            role: UserRole.values.firstWhere(
              (r) => r.name == (meta['role'] as String? ?? 'client'),
              orElse: () => UserRole.client,
            ),
            province: meta['province'] as String? ?? '',
            city: meta['city'] as String? ?? '',
          );
        }
      }

      _clearDemo(); // salir del modo demo al hacer login real
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      _clearDemo(); // limpiar demo antes de cerrar sesión
      await SupabaseService.signOut();
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Recuperar contraseña ─────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Helpers privados ─────────────────────────────────────────────────────────

  /// Crea (o actualiza si ya existe) el registro en profiles y,
  /// si es prestador, también en provider_profiles.
  /// Usa upsert para ser idempotente.
  Future<void> _createProfile({
    required String userId,
    required String email,
    required String fullName,
    required String phone,
    required UserRole role,
    required String province,
    required String city,
  }) async {
    final now = DateTime.now().toIso8601String();

    await SupabaseService.client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role.name,
      'province': province,
      'city': city,
      'is_verified': false,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    });

    if (role == UserRole.provider) {
      await SupabaseService.client.from('provider_profiles').upsert({
        'user_id': userId,
        'full_name': fullName,
        'bio': '',
        'province': province,
        'city': city,
        'is_available': true,
        'is_verified': false,
        'rating': 0.0,
        'review_count': 0,
        'completed_jobs': 0,
        'photo_urls': <String>[],
        'member_since': now,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Limpia el modo demo para que el usuario real tome el control.
  void _clearDemo() {
    _ref.read(demoModeProvider.notifier).state = false;
    _ref.read(demoUserProvider.notifier).state = null;
  }
}
