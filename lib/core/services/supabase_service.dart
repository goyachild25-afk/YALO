import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // Auth
  static User? get currentUser => client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    return client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    // Sin esto, Supabase usa el "Site URL" del dashboard como destino del
    // enlace de recuperación, que normalmente no incluye ninguna ruta de la
    // app — el resultado es una URL sin hash que go_router no puede
    // resolver (404 "Página no encontrada"). Construirlo a partir de
    // Uri.base evita hardcodear el dominio y funciona igual en local y prod.
    final redirectTo = '${Uri.base.origin}${Uri.base.path}#/reset-password';
    await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  // Storage
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    await client.storage.from(bucket).uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: contentType),
    );
    return client.storage.from(bucket).getPublicUrl(path);
  }
}
