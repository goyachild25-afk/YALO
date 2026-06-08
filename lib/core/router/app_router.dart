import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/services/demo_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
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
import '../../features/safety/screens/terms_screen.dart';
import '../../features/safety/screens/report_dispute_screen.dart';
import '../../features/provider_dashboard/screens/rate_client_screen.dart';
import '../../features/home/screens/category_filter_screen.dart';
import '../../features/onboarding_flow/screens/client_onboarding_screen.dart';
import '../../features/onboarding_flow/screens/provider_onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isDemo = ref.read(demoModeProvider);
      final path = state.matchedLocation;

      final publicPaths = [
        '/', '/onboarding', '/login', '/register',
        '/setup-client', '/setup-provider',
      ];
      final isPublic = publicPaths.any((p) => path.startsWith(p));

      // En modo demo siempre permitir acceso
      if (isDemo) return null;

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn && (path == '/login' || path == '/onboarding')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'client';
          return RegisterScreen(role: role);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/providers',
        builder: (context, state) {
          final categoryId = state.uri.queryParameters['category'];
          final categoryName = state.uri.queryParameters['name'] != null
              ? Uri.decodeComponent(state.uri.queryParameters['name']!)
              : null;
          final filterNotes = state.uri.queryParameters['notes'] != null
              ? Uri.decodeComponent(state.uri.queryParameters['notes']!)
              : null;
          return ProvidersListScreen(
            categoryId: categoryId,
            categoryName: categoryName,
            filterNotes: filterNotes,
          );
        },
      ),
      GoRoute(
        path: '/provider/:id',
        builder: (context, state) {
          return ProviderProfileScreen(
            providerId: state.pathParameters['id']!,
          );
        },
      ),
      GoRoute(
        path: '/booking/:providerId',
        builder: (context, state) {
          return BookingScreen(
            providerId: state.pathParameters['providerId']!,
          );
        },
      ),
      GoRoute(
        path: '/booking-confirmation',
        builder: (_, __) => const BookingConfirmationScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return PaymentScreen(
            bookingId: params['bookingId'] ?? '',
            amount: double.tryParse(params['amount'] ?? '0') ?? 0,
            serviceName: Uri.decodeComponent(params['service'] ?? ''),
            providerName: Uri.decodeComponent(params['provider'] ?? ''),
            currency: params['currency'] ?? 'dop',
          );
        },
      ),
      GoRoute(
        path: '/bookings',
        builder: (_, __) => const ClientBookingsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const ProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const ProvidersListScreen(),
      ),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (context, state) => ChatScreen(
          bookingId: state.pathParameters['bookingId']!,
          otherUserName: Uri.decodeComponent(
              state.uri.queryParameters['name'] ?? 'Usuario'),
          serviceName: Uri.decodeComponent(
              state.uri.queryParameters['service'] ?? 'Servicio'),
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/verify-identity',
        builder: (_, __) => const ProviderVerificationScreen(),
      ),
      GoRoute(
        path: '/my-services',
        builder: (_, __) => const ProviderServicesScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (_, __) => const HelpScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) {
          final mustAccept =
              state.uri.queryParameters['accept'] == 'true';
          return TermsScreen(mustAccept: mustAccept);
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final p = state.uri.queryParameters;
          return ReportDisputeScreen(
            bookingId: p['bookingId'] ?? '',
            reportedUserId: p['userId'] ?? '',
            reportedUserName:
                Uri.decodeComponent(p['userName'] ?? 'Usuario'),
            serviceName:
                Uri.decodeComponent(p['service'] ?? 'Servicio'),
          );
        },
      ),
      GoRoute(
        path: '/category-filter',
        builder: (context, state) {
          final categoryId = state.uri.queryParameters['category'] ?? '';
          return CategoryFilterScreen(categoryId: categoryId);
        },
      ),
      GoRoute(
        path: '/setup-client',
        builder: (_, __) => const ClientOnboardingScreen(),
      ),
      GoRoute(
        path: '/setup-provider',
        builder: (_, __) => const ProviderOnboardingScreen(),
      ),
      GoRoute(
        path: '/rate-client',
        builder: (context, state) {
          final p = state.uri.queryParameters;
          return RateClientScreen(
            bookingId: p['bookingId'] ?? '',
            clientId: p['clientId'] ?? '',
            clientName: Uri.decodeComponent(p['clientName'] ?? 'Cliente'),
            serviceName:
                Uri.decodeComponent(p['service'] ?? 'Servicio'),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Página no encontrada', style: TextStyle(fontSize: 18)),
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
