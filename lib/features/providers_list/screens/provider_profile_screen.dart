import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../models/service_provider_model.dart';
import '../providers/providers_list_provider.dart';

class ProviderProfileScreen extends ConsumerWidget {
  final String providerId;

  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerDetailProvider(providerId));
    final reviewsAsync = ref.watch(providerReviewsProvider(providerId));

    return Scaffold(
      body: providerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(onBack: () => context.pop()),
        data: (provider) {
          if (provider == null) {
            return _ErrorBody(onBack: () => context.pop());
          }
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, provider),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoHeader(provider),
                      const SizedBox(height: 20),
                      _buildStats(provider),
                      const SizedBox(height: 24),
                      _buildAbout(provider),
                      const SizedBox(height: 24),
                      _buildServices(context, provider),
                      const SizedBox(height: 24),
                      if (provider.photoUrls.isNotEmpty) ...[
                        _buildPhotos(provider),
                        const SizedBox(height: 24),
                      ],
                      _buildReviews(reviewsAsync),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: providerAsync.when(
        data: (provider) => provider != null
            ? _buildBottomBar(context, provider)
            : const SizedBox(),
        loading: () => const SizedBox(height: 80),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ServiceProviderModel provider) {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: provider.photoUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: provider.photoUrls.first,
                fit: BoxFit.cover,
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    provider.fullName.isNotEmpty
                        ? provider.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoHeader(ServiceProviderModel provider) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primaryLighter,
          backgroundImage: provider.avatarUrl != null
              ? NetworkImage(provider.avatarUrl!)
              : null,
          child: provider.avatarUrl == null
              ? Text(
                  provider.fullName.isNotEmpty
                      ? provider.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (provider.isVerified)
                    const Row(
                      children: [
                        Icon(Icons.verified, color: AppColors.success, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Verificado',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    provider.locationLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingStars(
                rating: provider.rating,
                size: 16,
                reviewCount: provider.reviewCount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(ServiceProviderModel provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: provider.completedJobs.toString(),
            label: 'Trabajos',
            icon: Icons.check_circle_outline,
          ),
          _Divider(),
          _StatItem(
            value: provider.ratingFormatted,
            label: 'Calificación',
            icon: Icons.star_outline,
          ),
          _Divider(),
          _StatItem(
            value: _memberSince(provider.memberSince),
            label: 'Miembro',
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(ServiceProviderModel provider) {
    if (provider.bio.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sobre mí',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          provider.bio,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildServices(BuildContext context, ServiceProviderModel provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicios ofrecidos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...provider.services.map(
          (service) => _ServiceTile(service: service),
        ),
      ],
    );
  }

  Widget _buildPhotos(ServiceProviderModel provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trabajos realizados',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: provider.photoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: provider.photoUrls[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviews(AsyncValue<List<ReviewModel>> reviewsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reseñas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Text('No se pudieron cargar las reseñas'),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const Text(
                'Aún no hay reseñas para este prestador.',
                style: TextStyle(color: AppColors.textSecondary),
              );
            }
            return Column(
              children:
                  reviews.map((r) => _ReviewTile(review: r)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(
      BuildContext context, ServiceProviderModel provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Garantía de pago post-servicio
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.task_alt_rounded,
                  size: 13, color: AppColors.success),
              const SizedBox(width: 5),
              Text(
                'Pagas solo cuando el servicio esté completado',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: provider.isAvailable
                      ? 'Solicitar servicio'
                      : 'No disponible',
                  onPressed: provider.isAvailable
                      ? () => context.push('/booking/${provider.id}')
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _memberSince(DateTime date) {
    final now = DateTime.now();
    final months = (now.year - date.year) * 12 + now.month - date.month;
    if (months < 1) return 'Nuevo';
    if (months < 12) return '$months meses';
    return '${months ~/ 12} años';
  }
}

// ─── Error / not found body ───────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final VoidCallback onBack;
  const _ErrorBody({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_outlined,
                size: 72, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'Prestador no encontrado',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Es posible que este perfil ya no esté disponible.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onBack,
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.divider,
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ProviderService service;

  const _ServiceTile({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              service.categoryName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: service.pricingType == PricingType.fixed
                  ? AppColors.successLight
                  : AppColors.infoLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              service.priceLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: service.pricingType == PricingType.fixed
                    ? AppColors.success
                    : AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLighter,
                backgroundImage: review.clientAvatarUrl != null
                    ? NetworkImage(review.clientAvatarUrl!)
                    : null,
                child: review.clientAvatarUrl == null
                    ? Text(
                        review.clientName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      timeago.format(review.createdAt, locale: 'es'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              RatingStars(
                rating: review.rating,
                size: 14,
                reviewCount: null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
