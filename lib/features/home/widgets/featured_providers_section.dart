import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers_list/providers/providers_list_provider.dart';
import '../../providers_list/widgets/provider_card.dart';

class FeaturedProvidersSection extends ConsumerWidget {
  const FeaturedProvidersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(providersListProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mejor calificados ⭐',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/providers'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        providersAsync.when(
          loading: () => SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => _ProviderShimmer(),
            ),
          ),
          error: (e, _) => const Center(
            child: Text('No se pudieron cargar los prestadores'),
          ),
          data: (providers) {
            if (providers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sé de los primeros prestadores en ServiciosYa — ¡regístrate ya!',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final featured = providers.take(8).toList();
            return SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ProviderCard(
                  provider: featured[i],
                  onTap: () => context.push(
                    '/provider/${featured[i].id}',
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProviderShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
