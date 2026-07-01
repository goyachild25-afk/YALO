import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

/// Estado observable del conjunto de favoritos del usuario actual. Se
/// mantiene como Set de provider_id para tap toggling instantáneo.
final favoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return <String>{};
  try {
    final rows = await SupabaseService.client
        .from('favorites')
        .select('provider_id')
        .eq('user_id', user.id);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['provider_id'] as String)
        .toSet();
  } catch (_) {
    return <String>{};
  }
});

/// Botón corazón para marcar/desmarcar como favorito. Optimista: cambia el
/// estado local al momento y persiste en background.
class FavoriteButton extends ConsumerStatefulWidget {
  final String providerId;
  final double size;
  final Color? inactiveColor;

  const FavoriteButton({
    super.key,
    required this.providerId,
    this.size = 28,
    this.inactiveColor,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _pending = false;

  Future<void> _toggle(bool isFav) async {
    if (_pending) return;
    final user = SupabaseService.currentUser;
    if (user == null) return;
    HapticFeedback.lightImpact();
    setState(() => _pending = true);
    try {
      if (isFav) {
        await SupabaseService.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('provider_id', widget.providerId);
      } else {
        await SupabaseService.client.from('favorites').insert({
          'user_id': user.id,
          'provider_id': widget.providerId,
        });
      }
      ref.invalidate(favoritesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos actualizar tus favoritos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final favs = async.valueOrNull ?? const <String>{};
    final isFav = favs.contains(widget.providerId);
    return IconButton(
      tooltip: isFav ? 'Quitar de favoritos' : 'Guardar en favoritos',
      icon: AnimatedScale(
        scale: isFav ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          size: widget.size,
          color: isFav ? AppColors.error : (widget.inactiveColor ?? Colors.white),
        ),
      ),
      onPressed: () => _toggle(isFav),
    );
  }
}
