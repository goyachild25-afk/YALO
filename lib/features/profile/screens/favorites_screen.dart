import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class _FavoriteProvider {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final String? city;

  const _FavoriteProvider({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    this.city,
  });
}

final _myFavoritesProvider =
    FutureProvider.autoDispose<List<_FavoriteProvider>>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return const [];
  try {
    // Join manual: favoritos → provider_profiles
    final favs = await SupabaseService.client
        .from('favorites')
        .select('provider_id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    if ((favs as List).isEmpty) return const [];

    final ids =
        favs.map((r) => (r as Map<String, dynamic>)['provider_id']).toList();

    final providers = await SupabaseService.client
        .from('provider_profiles')
        .select('id, full_name, avatar_url, rating, completed_jobs, city')
        .inFilter('id', ids);

    return (providers as List<dynamic>).map((r) {
      final m = r as Map<String, dynamic>;
      return _FavoriteProvider(
        id: m['id'] as String,
        fullName: m['full_name'] as String? ?? 'Prestador',
        avatarUrl: m['avatar_url'] as String?,
        rating: ((m['rating'] as num?) ?? 0).toDouble(),
        completedJobs: (m['completed_jobs'] as int?) ?? 0,
        city: m['city'] as String?,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myFavoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis favoritos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
            child: Text('No pudimos cargar tus favoritos.')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 72, color: AppColors.textHint),
                    SizedBox(height: 16),
                    Text(
                      'Aún no tienes favoritos',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cuando encuentres un prestador que te guste, tócale al corazón para guardarlo aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/provider/${p.id}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryLighter,
                          backgroundImage: p.avatarUrl != null
                              ? CachedNetworkImageProvider(p.avatarUrl!)
                              : null,
                          child: p.avatarUrl == null
                              ? Text(
                                  p.fullName.isNotEmpty
                                      ? p.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 20,
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
                              Text(
                                p.fullName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: AppColors.star, size: 14),
                                  Text(
                                    ' ${p.rating.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('· ${p.completedJobs} trabajos',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  if (p.city != null && p.city!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('· ${p.city}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
