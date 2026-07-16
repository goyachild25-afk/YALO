import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/models/user_model.dart';
import '../../core/services/demo_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/search_screen.dart';
import '../../features/providers_list/screens/providers_list_screen.dart';
import '../../features/providers_list/screens/provider_profile_screen.dart';
import '../../features/booking/screens/booking_screen.dart';
import '../../features/booking/screens/booking_confirmation_screen.dart';
import '../../features/booking/screens/payment_screen.dart';
import '../../features/provider_dashboard/screens/provider_dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/client_bookings_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/verification/screens/provider_verification_screen.dart';
import '../../features/provider_dashboard/screens/provider_services_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/profile/screens/help_screen.dart';
import '../../features/profile/screens/accessibility_screen.dart';
import '../../features/profile/screens/privacy_screen.dart';
import '../../features/profile/screens/referrals_screen.dart';
import '../../features/profile/screens/favorites_screen.dart';
import '../../features/maintenance/screens/maintenance_screen.dart';
import '../services/maintenance_service.dart';
import '../../features/safety/screens/terms_screen.dart';
import '../../features/safety/screens/report_dispute_screen.dart';
import '../../features/provider_dashboard/screens/rate_client_screen.dart';
import '../../features/home/screens/category_filter_screen.dart';
import '../../features/onboarding_flow/screens/client_onboarding_screen.dart';
import '../../features/onboarding_flow/screens/provider_onboarding_screen.dart';
import '../../features/booking/screens/service_request_screen.dart';
import '../../features/booking/screens/searching_provider_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';

// ── Transition helpers ────────────────────────────────────────────────────────

/// Fade suave para pantallas raíz (splash, home, dashboard, login).
CustomTransitionPage<void> _fadePage(LocalKey key, Widget child) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

/// Slide-fade lateral para pantallas de detalle (push hacia adelante).
CustomTransitionPage<void> _slidePage(LocalKey key, Widget child) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 270),
      transitionsBuilder: (_, animation, __, child) {
        final slide = animation.drive(
          Tween(begin: const Offset(0.05, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        );
        final fade =
            CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );

/// Slide-up para modales/pantallas de fondo (payment, report, terms).
CustomTransitionPage<void> _slideUpPage(LocalKey key, Widget child) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutQuart)),
        ),
        child: child,
      ),
    );

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  // El GoRouter debe construirse UNA sola vez por sesión. Antes este
  // provider hacía ref.watch de authState/userRole/maintenance: cualquier
  // cambio (p. ej. completar un registro) recreaba el router entero y la
  // app "olvidaba" dónde estaba, reseteando a '/' (splash) — así un
  // prestador recién registrado se saltaba /verify-email y el onboarding y
  // aterrizaba directo en el dashboard. Ahora esos cambios solo disparan
  // una reevaluación del redirect (refreshListenable) leyendo los valores
  // frescos con ref.read, sin perder la ubicación actual.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.listen(userRoleProvider, (_, __) => refresh.value++);
  ref.listen(isActiveProvider, (_, __) => refresh.value++);
  // Mantenimiento: lo lee en Realtime, así que activar el toggle desde el
  // panel admin bloquea a los usuarios no-admin en la próxima navegación
  // sin desplegar código.
  ref.listen(maintenanceModeProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).value != null;
      final userRole = ref.read(userRoleProvider);
      final maintenance =
          ref.read(maintenanceModeProvider).valueOrNull ?? false;
      final isDemo = ref.read(demoModeProvider);
      final path = state.matchedLocation;

      // ── Modo mantenimiento ─────────────────────────────────────────────
      // Admins (y sesiones demo) siempre pueden usar la app para diagnosticar
      // el incidente. El resto ve una pantalla estática que se auto-desbloquea
      // en cuanto el admin apague el toggle (el provider es Realtime).
      if (maintenance &&
          !isDemo &&
          userRole != UserRole.admin &&
          path != '/maintenance' &&
          path != '/reset-password') {
        return '/maintenance';
      }
      // Si el modo mantenimiento se desactivó, sacar al usuario de esa pantalla
      if (!maintenance && path == '/maintenance') {
        return '/';
      }

      // ── Cuenta suspendida mientras la sesión ya estaba abierta ────────
      // El login bloquea cuentas suspendidas (AuthController.signIn), pero
      // si un admin suspende a alguien que ya está adentro, esto lo saca
      // en la próxima navegación — sin esperar a que la pestaña se recargue.
      if (isLoggedIn && !isDemo && !ref.read(isActiveProvider) && path != '/login') {
        SupabaseService.signOut();
        return '/login';
      }

      // Enlace de recuperación de contraseña: Supabase entrega el código de
      // intercambio (PKCE) como query param ('?code=...') sobre el
      // redirectTo configurado, pero el navegador nunca envía el fragmento
      // '#...' de esa URL al servidor de Supabase — por diseño, los
      // fragments son puramente del lado del cliente — así que cualquier
      // ruta que hayamos pedido después del '#' se pierde y el usuario
      // siempre aterriza en la raíz con solo el query string. Detectamos
      // ese caso aquí, en lugar de depender de que se preserve la ruta.
      if (path != '/reset-password' &&
          Uri.base.queryParameters.containsKey('code')) {
        return '/reset-password';
      }

      final publicPaths = [
        '/', '/onboarding', '/login', '/register',
        '/setup-client', '/setup-provider', '/verify-email', '/forgot-password',
        '/reset-password',
      ];
      final isPublic = publicPaths.contains(path);

      if (isDemo) return null;

      if (!isLoggedIn && !isPublic) return '/login';

      // SplashScreen (/) handles its own navigation — don't redirect from it
      if (path == '/') return null;

      // Tras login/onboarding (pero no /) → redirige según rol
      if (isLoggedIn && (path == '/login' || path == '/onboarding')) {
        if (userRole == UserRole.admin) return '/admin';
        if (userRole == UserRole.provider) return '/dashboard';
        return '/home';
      }

      // Guarda cruzada: prestadores no acceden al home de cliente.
      // userRole != null es obligatorio aquí: mientras el perfil del usuario
      // todavía está cargando (justo tras el login, antes de que
      // currentUserProvider resuelva), userRole es null, y null != client
      // también es true — sin este chequeo, /home redirige a /dashboard,
      // que a su vez redirige de vuelta a /home (misma razón, en espejo),
      // formando un loop infinito que GoRouter corta mostrando su
      // errorBuilder genérico ("Página no encontrada"). Confirmado en vivo
      // instrumentando el callback con logging: el ciclo se repetía
      // exactamente así, /login -> /home -> /dashboard -> /home, mientras
      // userRole seguía en null.
      if (isLoggedIn &&
          userRole != null &&
          path == '/home' &&
          userRole != UserRole.client) {
        return userRole == UserRole.admin ? '/admin' : '/dashboard';
      }

      // Guarda cruzada: clientes (y admins) no acceden al dashboard de
      // prestador. Mismo motivo que arriba: sin userRole != null, esto
      // forma la otra mitad del loop infinito /home <-> /dashboard.
      if (isLoggedIn &&
          userRole != null &&
          path == '/dashboard' &&
          userRole != UserRole.provider) {
        return userRole == UserRole.admin ? '/admin' : '/home';
      }

      return null;
    },
    routes: [
      // ── Auth & raíz ────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const LoginScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const ResetPasswordScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'client';
          return _slidePage(state.pageKey, RegisterScreen(role: role));
        },
      ),
      GoRoute(
        path: '/setup-client',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const ClientOnboardingScreen()),
      ),
      GoRoute(
        path: '/setup-provider',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const ProviderOnboardingScreen()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _fadePage(
            state.pageKey,
            EmailVerificationScreen(
              email: p['email'] ?? '',
              nextRoute: p['next'] ?? '/home',
            ),
          );
        },
      ),

      // ── Pantallas principales ───────────────────────────────────────────────
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const HomeScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const ProviderDashboardScreen()),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const AdminDashboardScreen()),
      ),

      // ── Prestadores ────────────────────────────────────────────────────────
      GoRoute(
        path: '/providers',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _slidePage(
            state.pageKey,
            ProvidersListScreen(
              categoryId: p['category'],
              categoryName: p['name'],
              filterNotes: p['notes'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/provider/:id',
        pageBuilder: (context, state) => _slidePage(
          state.pageKey,
          ProviderProfileScreen(providerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const SearchScreen()),
      ),

      // ── Booking & servicios ────────────────────────────────────────────────
      GoRoute(
        path: '/category-filter',
        pageBuilder: (context, state) {
          final categoryId = state.uri.queryParameters['category'] ?? '';
          return _slidePage(
              state.pageKey, CategoryFilterScreen(categoryId: categoryId));
        },
      ),
      GoRoute(
        path: '/service-request',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _slidePage(
            state.pageKey,
            ServiceRequestScreen(
              categoryId: p['category'] ?? '',
              categoryName: p['name'] ?? 'Servicio',
              filterNotes: p['notes'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/searching/:bookingId',
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          SearchingProviderScreen(
              bookingId: state.pathParameters['bookingId']!),
        ),
      ),
      GoRoute(
        path: '/booking/:providerId',
        pageBuilder: (context, state) => _slidePage(
          state.pageKey,
          BookingScreen(providerId: state.pathParameters['providerId']!),
        ),
      ),
      GoRoute(
        path: '/booking-confirmation',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const BookingConfirmationScreen()),
      ),
      GoRoute(
        path: '/bookings',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ClientBookingsScreen()),
      ),

      // ── Modales / pantallas de fondo ───────────────────────────────────────
      GoRoute(
        path: '/payment',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _slideUpPage(
            state.pageKey,
            PaymentScreen(
              bookingId: p['bookingId'] ?? '',
              amount: double.tryParse(p['amount'] ?? '0') ?? 0,
              serviceName: p['service'] ?? '',
              providerName: p['provider'] ?? '',
              currency: p['currency'] ?? 'dop',
            ),
          );
        },
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) {
          final mustAccept = state.uri.queryParameters['accept'] == 'true';
          return _slideUpPage(
              state.pageKey, TermsScreen(mustAccept: mustAccept));
        },
      ),
      GoRoute(
        path: '/report',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _slideUpPage(
            state.pageKey,
            ReportDisputeScreen(
              bookingId: p['bookingId'] ?? '',
              reportedUserId: p['userId'] ?? '',
              reportedUserName: p['userName'] ?? 'Usuario',
              serviceName: p['service'] ?? 'Servicio',
            ),
          );
        },
      ),
      GoRoute(
        path: '/rate-client',
        pageBuilder: (context, state) {
          final p = state.uri.queryParameters;
          return _slideUpPage(
            state.pageKey,
            RateClientScreen(
              bookingId: p['bookingId'] ?? '',
              clientId: p['clientId'] ?? '',
              clientName: p['clientName'] ?? 'Cliente',
              serviceName: p['service'] ?? 'Servicio',
            ),
          );
        },
      ),

      // ── Usuario & perfil ───────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ProfileScreen()),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ChangePasswordScreen()),
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const HelpScreen()),
      ),
      GoRoute(
        path: '/accessibility',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const AccessibilityScreen()),
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const PrivacyScreen()),
      ),
      GoRoute(
        path: '/referrals',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ReferralsScreen()),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const FavoritesScreen()),
      ),
      GoRoute(
        path: '/maintenance',
        pageBuilder: (_, state) =>
            _fadePage(state.pageKey, const MaintenanceScreen()),
      ),

      // ── Chat & notificaciones ──────────────────────────────────────────────
      GoRoute(
        path: '/chat/:bookingId',
        pageBuilder: (context, state) => _slidePage(
          state.pageKey,
          ChatScreen(
            bookingId: state.pathParameters['bookingId']!,
            otherUserName: state.uri.queryParameters['name'] ?? 'Usuario',
            serviceName: state.uri.queryParameters['service'] ?? 'Servicio',
            isProvider: state.uri.queryParameters['provider'] == 'true',
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const NotificationsScreen()),
      ),

      // ── Prestador (dashboard interno) ──────────────────────────────────────
      GoRoute(
        path: '/verify-identity',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ProviderVerificationScreen()),
      ),
      GoRoute(
        path: '/my-services',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ProviderServicesScreen()),
      ),
      GoRoute(
        path: '/provider-history',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ProviderHistoryScreen()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Página no encontrada',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
});
