import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/user_location_service.dart';
import '../../../core/utils/haversine.dart';
import '../providers/providers_list_provider.dart';
import '../models/service_provider_model.dart';
import '../widgets/provider_card.dart';

// Chips rápidos (las más pobladas) — scroll horizontal en la pantalla
const List<String> _quickProvinces = [
  'Todas', 'Distrito Nacional', 'Santo Domingo', 'Santiago',
  'La Vega', 'San Cristóbal', 'Puerto Plata', 'La Altagracia',
  'La Romana', 'San Pedro de Macorís',
];

// Lista completa de las 32 provincias para el filtro desplegable
const List<String> _provinces = [
  'Todas',
  'Distrito Nacional',
  'Azua',
  'Baoruco',
  'Barahona',
  'Dajabón',
  'Duarte',
  'Elías Piña',
  'El Seibo',
  'Espaillat',
  'Hato Mayor',
  'Hermanas Mirabal',
  'Independencia',
  'La Altagracia',
  'La Romana',
  'La Vega',
  'María Trinidad Sánchez',
  'Monseñor Nouel',
  'Monte Cristi',
  'Monte Plata',
  'Pedernales',
  'Peravia',
  'Puerto Plata',
  'Samaná',
  'Sánchez Ramírez',
  'San Cristóbal',
  'San José de Ocoa',
  'San Juan',
  'San Pedro de Macorís',
  'Santiago',
  'Santiago Rodríguez',
  'Santo Domingo',
  'Valverde',
];

class ProvidersListScreen extends ConsumerStatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final String? filterNotes; // Resumen de las respuestas del filtro

  const ProvidersListScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.filterNotes,
  });

  @override
  ConsumerState<ProvidersListScreen> createState() =>
      _ProvidersListScreenState();
}

class _ProvidersListScreenState extends ConsumerState<ProvidersListScreen> {
  String? _selectedProvince;
  String _sortBy = 'rating';
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(providersListProvider(widget.categoryId));
    // Solo se observa cuando hace falta — evita pedir/vigilar ubicación en
    // los otros modos de orden.
    final locAsync =
        _sortBy == 'distance' ? ref.watch(userLocationProvider) : null;
    final locationUnavailable = locAsync != null &&
        !locAsync.isLoading &&
        locAsync.valueOrNull == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Todos los prestadores'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Toggle lista / mapa
          IconButton(
            tooltip: _showMap ? 'Ver lista' : 'Ver mapa',
            icon: Icon(_showMap ? Icons.list : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de filtros aplicados
          if (widget.filterNotes != null && widget.filterNotes!.isNotEmpty)
            _FilterSummaryBanner(notes: widget.filterNotes!),
          _buildFilterChips(),
          if (locationUnavailable) const _LocationUnavailableBanner(),
          Expanded(
            child: providersAsync.when(
              loading: () => _buildShimmerList(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Error al cargar los prestadores'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(providersListProvider(widget.categoryId)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (providers) {
                var sorted = [...providers];
                if (_selectedProvince != null &&
                    _selectedProvince != 'Todas') {
                  sorted = sorted
                      .where((p) => p.province == _selectedProvince)
                      .toList();
                }
                if (_sortBy == 'rating') {
                  sorted.sort((a, b) => b.rating.compareTo(a.rating));
                } else if (_sortBy == 'jobs') {
                  sorted.sort(
                      (a, b) => b.completedJobs.compareTo(a.completedJobs));
                } else if (_sortBy == 'distance') {
                  final loc = locAsync?.valueOrNull;
                  if (loc != null) {
                    double? distTo(p) {
                      if (p.latitude == null || p.longitude == null) return null;
                      return haversineKm(loc.latitude, loc.longitude,
                          p.latitude!, p.longitude!);
                    }
                    sorted.sort((a, b) {
                      final da = distTo(a);
                      final db = distTo(b);
                      if (da == null && db == null) return 0;
                      if (da == null) return 1;
                      if (db == null) return -1;
                      return da.compareTo(db);
                    });
                  }
                }

                if (sorted.isEmpty) return _buildEmptyState();

                // ── Vista mapa ──────────────────────────────────────────────
                if (_showMap) {
                  return _ProvidersMapView(providers: sorted);
                }

                // ── Vista lista (default) ───────────────────────────────────
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => RepaintBoundary(
                    child: ProviderCard(
                      provider: sorted[i],
                      compact: true,
                      onTap: () => context.push('/provider/${sorted[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SortChip(
            label: 'Mejor calificados',
            selected: _sortBy == 'rating',
            onSelected: (_) => setState(() => _sortBy = 'rating'),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Más trabajos',
            selected: _sortBy == 'jobs',
            onSelected: (_) => setState(() => _sortBy = 'jobs'),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Más cercanos',
            selected: _sortBy == 'distance',
            onSelected: (_) => setState(() => _sortBy = 'distance'),
          ),
          const SizedBox(width: 8),
          ..._quickProvinces.skip(1).map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SortChip(
                  label: p,
                  selected: _selectedProvince == p,
                  onSelected: (selected) => setState(() =>
                      _selectedProvince = selected ? p : null),
                ),
              )),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        selectedProvince: _selectedProvince,
        sortBy: _sortBy,
        onApply: (province, sort) {
          setState(() {
            _selectedProvince = province;
            _sortBy = sort;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off,
                size: 40, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay prestadores disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prueba cambiando los filtros\no la ubicación',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ── Banner de resumen de filtros ─────────────────────────────────────────────
// "Más cercanos" pedía la ubicación en silencio: si no había permiso o el
// GPS no respondía, la lista se quedaba en el orden anterior sin avisar —
// indistinguible de un orden por distancia real que funcionó.
class _LocationUnavailableBanner extends StatelessWidget {
  const _LocationUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off_outlined, size: 18, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No pudimos acceder a tu ubicación — mostrando el orden anterior. Activa el permiso de ubicación para ver los más cercanos primero.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryBanner extends StatelessWidget {
  final String notes;

  const _FilterSummaryBanner({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tune_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buscando según tus preferencias',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? selectedProvince;
  final String sortBy;
  final void Function(String?, String) onApply;

  const _FilterSheet({
    this.selectedProvince,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _province;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _province = widget.selectedProvince;
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ordenar por',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mejor calificados'),
                selected: _sortBy == 'rating',
                onSelected: (_) => setState(() => _sortBy = 'rating'),
              ),
              ChoiceChip(
                label: const Text('Más trabajos'),
                selected: _sortBy == 'jobs',
                onSelected: (_) => setState(() => _sortBy = 'jobs'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Provincia',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _province,
            hint: const Text('Todas las provincias'),
            decoration: const InputDecoration(),
            items: _provinces
                .skip(1)
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _province = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_province, _sortBy);
                Navigator.pop(context);
              },
              child: const Text('Aplicar filtros'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Vista de mapa de prestadores ─────────────────────────────────────────────
// Muestra GoogleMap cuando la API key está configurada.
// Para activar: reemplaza 'YOUR_GOOGLE_MAPS_API_KEY' en app_constants.dart
// y añade el key en android/app/src/main/AndroidManifest.xml y ios/Runner/Info.plist
class _ProvidersMapView extends StatefulWidget {
  final List<ServiceProviderModel> providers;
  const _ProvidersMapView({required this.providers});

  @override
  State<_ProvidersMapView> createState() => _ProvidersMapViewState();
}

class _ProvidersMapViewState extends State<_ProvidersMapView> {
  // Santo Domingo, República Dominicana
  static const _initialPosition = CameraPosition(
    target: LatLng(18.4861, -69.9312),
    zoom: 11,
  );

  @override
  Widget build(BuildContext context) {
    final mapsConfigured =
        AppConstants.googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        AppConstants.googleMapsApiKey.isNotEmpty;

    if (!mapsConfigured) {
      return _MapPlaceholder(providerCount: widget.providers.length);
    }

    // Build markers from providers that have lat/lng
    final markers = <Marker>{};
    for (final p in widget.providers) {
      if (p.latitude != null && p.longitude != null) {
        markers.add(Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.latitude!, p.longitude!),
          infoWindow: InfoWindow(
            title: p.fullName,
            snippet: '⭐ ${p.ratingFormatted} · ${p.locationLabel}',
          ),
        ));
      }
    }

    return GoogleMap(
      initialCameraPosition: _initialPosition,
      markers: markers,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapType: MapType.normal,
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final int providerCount;
  const _MapPlaceholder({required this.providerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_outlined,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mapa de prestadores',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '$providerCount prestadores disponibles en tu zona.\nEl mapa se activará cuando se configure la API key de Google Maps.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.info),
                    SizedBox(width: 6),
                    Text(
                      'Pendiente: Google Maps API key',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
