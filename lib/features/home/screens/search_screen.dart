import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/service_category_model.dart';

class _SearchHit {
  final String type; // 'category' | 'provider'
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? avatarUrl;
  const _SearchHit({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.avatarUrl,
  });
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<_SearchHit> _providerHits = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus el input al abrir la pantalla
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _search() async {
    if (_query.length < 2) {
      setState(() => _providerHits = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.client
          .from('provider_profiles')
          .select('id, full_name, avatar_url, city, province, rating, is_verified')
          .ilike('full_name', '%$_query%')
          .eq('is_available', true)
          .limit(15);
      final hits = (rows as List<dynamic>).map((r) {
        final m = r as Map<String, dynamic>;
        final rating = (m['rating'] as num?)?.toDouble() ?? 0;
        return _SearchHit(
          type: 'provider',
          id: m['id'] as String,
          title: m['full_name'] as String? ?? 'Prestador',
          subtitle: [
            if ((m['city'] as String?)?.isNotEmpty ?? false) m['city'],
            if (rating > 0) '⭐ ${rating.toStringAsFixed(1)}',
          ].whereType<String>().join(' · '),
          icon: Icons.person_rounded,
          color: AppColors.primary,
          avatarUrl: m['avatar_url'] as String?,
        );
      }).toList();
      if (mounted) setState(() => _providerHits = hits);
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_SearchHit> get _categoryHits {
    if (_query.isEmpty) {
      return serviceCategories
          .map((c) => _SearchHit(
                type: 'category',
                id: c.id,
                title: c.name,
                subtitle: c.description,
                icon: c.icon,
                color: c.color,
              ))
          .toList();
    }
    final q = _query.toLowerCase();
    return serviceCategories
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q))
        .map((c) => _SearchHit(
              type: 'category',
              id: c.id,
              title: c.name,
              subtitle: c.description,
              icon: c.icon,
              color: c.color,
            ))
        .toList();
  }

  void _onTapHit(_SearchHit hit) {
    if (hit.type == 'category') {
      context.push('/category-filter?category=${hit.id}');
    } else {
      context.push('/provider/${hit.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryHits = _categoryHits;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '¿Qué servicio necesitas?',
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: 15),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Categorías
          if (categoryHits.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _query.isEmpty ? 'Explora por categoría' : 'Categorías',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: categoryHits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HitTile(
                hit: categoryHits[i],
                onTap: () => _onTapHit(categoryHits[i]),
              ),
            ),
          ),

          // Divisor
          if (_providerHits.isNotEmpty || (_query.length >= 2 && _loading))
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Prestadores',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    )),
              ),
            ),

          if (_loading && _query.length >= 2)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: _providerHits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HitTile(
                hit: _providerHits[i],
                onTap: () => _onTapHit(_providerHits[i]),
              ),
            ),
          ),

          if (_query.length >= 2 &&
              !_loading &&
              _providerHits.isEmpty &&
              categoryHits.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 64, color: AppColors.textHint),
                      SizedBox(height: 12),
                      Text('Sin resultados',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        'Prueba con otra palabra o revisa las categorías.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  final _SearchHit hit;
  final VoidCallback onTap;
  const _HitTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hit.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  image: hit.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(hit.avatarUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: hit.avatarUrl == null
                    ? Icon(hit.icon, color: hit.color, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (hit.subtitle != null && hit.subtitle!.isNotEmpty)
                      Text(hit.subtitle!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
  }
}
