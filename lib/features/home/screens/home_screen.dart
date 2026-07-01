import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notifications_provider.dart';
import '../../../shared/models/service_category_model.dart';
import '../widgets/featured_providers_section.dart';
import '../widgets/smart_suggestion.dart';
import '../../../shared/widgets/pwa_install_banner.dart';
import '../../../shared/widgets/help_fab.dart';

// ─── Real stats from Supabase ─────────────────────────────────────────────────
class _HomeStats {
  final int providers;
  final double avgRating;
  const _HomeStats({required this.providers, required this.avgRating});
}

final homeStatsProvider = FutureProvider<_HomeStats>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) return const _HomeStats(providers: 500, avgRating: 4.8);
  try {
    final resp = await SupabaseService.client
        .from('provider_profiles')
        .select('rating')
        .eq('is_available', true)
        .count(CountOption.exact);
    final count = resp.count;
    final rows = resp.data as List<dynamic>;
    double avg = 4.8;
    if (rows.isNotEmpty) {
      final total = rows.fold<double>(
          0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0));
      avg = total / rows.length;
    }
    return _HomeStats(providers: count, avgRating: avg);
  } catch (_) {
    return const _HomeStats(providers: 0, avgRating: 4.8);
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      floatingActionButton: const HelpFab(screenLabel: 'Inicio'),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 318,
            collapsedHeight: 70,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroHeader(userAsync: userAsync),
            ),
            // Collapsed version (when pinned at top)
            title: _CollapsedTitle(userAsync: userAsync, ref: ref),
            titleSpacing: 0,
            actions: const [SizedBox(width: 16)],
          ),

          // ── Body (rounded top corners que se solapan sobre el hero) ─────────
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // ── Indicador drag ─────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Categorías ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categorías',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/providers'),
                            child: const Text('Ver todas'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _CategoriesGrid(),
                    const SizedBox(height: 16),

                    // ── Sugerencia inteligente (repetir con favorito) ──────────
                    const SmartSuggestionCard(),
                    const SizedBox(height: 16),

                    // ── Estadísticas de credibilidad ───────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _StatsRow(),
                    ),
                    const SizedBox(height: 16),

                    // ── Banner PWA install ──────────────────────────────────────
                    const PwaInstallBanner(),
                    const SizedBox(height: 12),

                    // ── Banner promocional ─────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _PromoBanner(),
                    ),
                    const SizedBox(height: 28),

                    // ── Cómo funciona ──────────────────────────────────────────
                    const _HowItWorksSection(),
                    const SizedBox(height: 28),

                    // ── Prestadores destacados ─────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: FeaturedProvidersSection(),
                    ),
                    const SizedBox(height: 28),

                    // ── Badges de confianza ────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _TrustSection(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header (expandido)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends ConsumerWidget {
  final AsyncValue userAsync;
  const _HeroHeader({required this.userAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = userAsync.maybeWhen(
      data: (u) => u?.fullName.split(' ').first ?? 'Usuario',
      orElse: () => 'Usuario',
    );
    final location = userAsync.maybeWhen(
      data: (u) => u?.city != null ? '${u!.city}, ${u.province}' : 'República Dominicana',
      orElse: () => 'República Dominicana',
    );

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
              // Saludo
              Text(
                'Hola, $userName',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              // Ubicación (debajo del saludo, discreta)
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 12, color: Colors.white54),
                  const SizedBox(width: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      location,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Profesionales verificados\npara tu hogar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Search bar
              _SearchBar(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsed title (cuando el app bar está contraído / pinned)
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsedTitle extends StatelessWidget {
  final AsyncValue userAsync;
  final WidgetRef ref;
  const _CollapsedTitle({required this.userAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = userAsync.maybeWhen(data: (u) => u, orElse: () => null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Logo mini
          SvgPicture.asset(
            'assets/images/logo.svg',
            width: 34,
            height: 34,
          ),
          const SizedBox(width: 10),
          const Text(
            'ServiciosYa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          _NotificationBell(),
          const SizedBox(width: 10),
          // Avatar — solo en la barra contraída
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
              child: ClipOval(
                child: user?.avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: user!.avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox.shrink(),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : Center(
                        child: Text(
                          user?.fullName.isNotEmpty == true
                              ? user!.fullName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar (en el hero expandido)
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¿Qué servicio necesitas?',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Filter button
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Categorías — cuadrícula centrada (4 columnas × 2 filas)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 100,
        ),
        itemCount: serviceCategories.length,
        itemBuilder: (context, i) {
          final cat = serviceCategories[i];
          return _CategoryChip(
            category: cat,
            onTap: () => context.push('/category-filter?category=${cat.id}'),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final ServiceCategory category;
  final VoidCallback onTap;
  const _CategoryChip({required this.category, required this.onTap});

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: widget.category.backgroundColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _pressed
                    ? null
                    : [
                        BoxShadow(
                          color: widget.category.color.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                widget.category.icon,
                size: 26,
                color: widget.category.color,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.category.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner promocional
// ─────────────────────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      decoration: BoxDecoration(
        gradient: AppColors.warmGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decoración círculos
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Prestadores verificados',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Servicio profesional\ncon garantía total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => context.push('/providers'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver profesionales',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Ícono decorativo profesional
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_repair_service_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección de confianza (Trust Badges)
// ─────────────────────────────────────────────────────────────────────────────
class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Por qué ServiciosYa?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TrustBadge(
                emoji: '🛡️',
                title: 'Verificados',
                subtitle: 'Cédula y fotos revisadas',
                color: AppColors.primary,
                bg: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrustBadge(
                emoji: '⭐',
                title: 'Calificados',
                subtitle: 'Reseñas reales de clientes',
                color: AppColors.star,
                bg: AppColors.goldLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrustBadge(
                emoji: '💬',
                title: 'Chat seguro',
                subtitle: 'Comunicación directa',
                color: AppColors.info,
                bg: AppColors.infoLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Garantía de pago post-servicio — diferenciador ético clave
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.tropicalGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.payment_rounded, size: 24, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paga solo cuando estés satisfecho',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'El pago se realiza únicamente después de completar el servicio',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Legal disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Datos protegidos bajo la Ley 172-13 de la República Dominicana.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;

  const _TrustBadge({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campana de notificaciones con badge
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);

    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 22),
          ),
          if (unread > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isProvider = userAsync.value?.role.name == 'provider';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        elevation: 0,
        backgroundColor: Colors.transparent,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/bookings');
            case 2:
              context.go(isProvider ? '/dashboard' : '/profile');
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Mis servicios',
          ),
          BottomNavigationBarItem(
            icon: Icon(isProvider
                ? Icons.dashboard_outlined
                : Icons.person_outline),
            activeIcon: Icon(
                isProvider ? Icons.dashboard_rounded : Icons.person_rounded),
            label: isProvider ? 'Panel' : 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de estadísticas / credibilidad
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);
    final stats = statsAsync.valueOrNull;

    final providerLabel = stats == null
        ? '...'
        : stats.providers > 0
            ? '${stats.providers}${stats.providers >= 10 ? '+' : ''}'
            : '—';
    final ratingLabel = stats == null
        ? '...'
        : '${stats.avgRating.toStringAsFixed(1)} ⭐';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(value: providerLabel, label: 'Prestadores'),
          const _StatDivider(),
          const _StatItem(value: '32', label: 'Provincias'),
          const _StatDivider(),
          _StatItem(value: ratingLabel, label: 'Calificación'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.divider,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección "Cómo funciona" — 3 pasos transparentes
// ─────────────────────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Cómo funciona',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepCard(
                step: '1',
                icon: Icons.search_rounded,
                title: 'Elige',
                subtitle: 'Encuentra el profesional ideal para tu hogar',
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _StepCard(
                step: '2',
                icon: Icons.handshake_outlined,
                title: 'Acuerda',
                subtitle: 'Coordina fecha, hora y condiciones',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              _StepCard(
                step: '3',
                icon: Icons.task_alt_rounded,
                title: 'Paga al finalizar',
                subtitle: 'Solo cuando el trabajo esté listo',
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Paso $step',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
