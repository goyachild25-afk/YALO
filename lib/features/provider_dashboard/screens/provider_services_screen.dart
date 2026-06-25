import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../onboarding_flow/providers/onboarding_provider.dart' show kServiceCategories;
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../providers_list/models/service_provider_model.dart';

// ── Provider que carga los servicios actuales del prestador ─────────────────
final myProviderServicesProvider =
    FutureProvider<List<ProviderService>>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const ProviderService(
        id: 'svc-demo-1',
        categoryId: 'home_cleaning',
        categoryName: 'Limpieza del hogar',
        pricingType: PricingType.fixed,
        fixedPrice: 25000,
        priceDescription: 'Por sesión de 3 horas',
      ),
    ];
  }

  final user = SupabaseService.currentUser;
  if (user == null) return [];

  final profile = await SupabaseService.client
      .from('provider_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (profile == null) return [];

  final rows = await SupabaseService.client
      .from('provider_services')
      .select()
      .eq('provider_id', profile['id'] as String)
      .eq('is_active', true)
      .order('created_at');

  return (rows as List<dynamic>)
      .map((r) => ProviderService.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Pantalla principal ───────────────────────────────────────────────────────
class ProviderServicesScreen extends ConsumerWidget {
  const ProviderServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(myProviderServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis servicios'),
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (services) => _ServicesList(services: services),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServiceSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar servicio'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddServiceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddServiceSheet(
        onSaved: () => ref.invalidate(myProviderServicesProvider),
      ),
    );
  }
}

// ── Lista de servicios activos ───────────────────────────────────────────────
class _ServicesList extends ConsumerWidget {
  final List<ProviderService> services;
  const _ServicesList({required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (services.isEmpty) {
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
              child: const Icon(Icons.work_outline,
                  size: 40, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes servicios',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega los servicios que ofreces\npara que los clientes puedan encontrarte',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ServiceTile(
        service: services[i],
        onDelete: () async {
          await _deleteService(context, ref, services[i].id);
        },
      ),
    );
  }

  Future<void> _deleteService(
      BuildContext context, WidgetRef ref, String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar servicio?'),
        content:
            const Text('Este servicio dejará de aparecer para los clientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final isDemo = ref.read(demoModeProvider);
    if (!isDemo) {
      await SupabaseService.client
          .from('provider_services')
          .update({'is_active': false}).eq('id', serviceId);
    }
    ref.invalidate(myProviderServicesProvider);
  }
}

// ── Tarjeta de servicio ──────────────────────────────────────────────────────
class _ServiceTile extends StatelessWidget {
  final ProviderService service;
  final VoidCallback onDelete;

  const _ServiceTile({required this.service, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = kServiceCategories
        .where((c) => c['id'] == service.categoryId)
        .firstOrNull;
    const color = AppColors.primary;
    const bg = AppColors.primaryLighter;
    final emoji = cat?['emoji'] ?? '🔧';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service.pricingType == PricingType.fixed
                            ? 'RD\$${_formatPrice(service.fixedPrice)}'
                            : 'Por cotización',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (service.priceDescription != null &&
                    service.priceDescription!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.priceDescription!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return '0';
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }
}

// ── Bottom sheet para agregar servicio ──────────────────────────────────────
class _AddServiceSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddServiceSheet({required this.onSaved});

  @override
  ConsumerState<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends ConsumerState<_AddServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Map<String, String>? _selectedCategory;
  PricingType _pricingType = PricingType.fixed;
  bool _isSaving = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isDemo = ref.read(demoModeProvider);

      if (!isDemo) {
        final user = SupabaseService.currentUser!;
        final profile = await SupabaseService.client
            .from('provider_profiles')
            .select('id')
            .eq('user_id', user.id)
            .single();

        await SupabaseService.client.from('provider_services').insert({
          'provider_id': profile['id'],
          'category_id': _selectedCategory!['id'],
          'category_name': _selectedCategory!['name'],
          'pricing_type': _pricingType.name,
          'fixed_price': _pricingType == PricingType.fixed
              ? double.tryParse(_priceCtrl.text.replaceAll(',', ''))
              : null,
          'price_description': _descCtrl.text.trim(),
          'is_active': true,
        });
      } else {
        // En demo: simular delay
        await Future.delayed(const Duration(milliseconds: 500));
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio agregado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 20),
            const Text(
              'Agregar servicio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Categoría
            const Text(
              'Categoría del servicio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kServiceCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = kServiceCategories[i];
                  final isSelected = _selectedCategory?['id'] == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat['emoji']!,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            cat['name']!.split(' ').first,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Tipo de precio
            const Text(
              'Tipo de precio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PricingTypeChip(
                    label: 'Precio fijo',
                    icon: Icons.sell_outlined,
                    selected: _pricingType == PricingType.fixed,
                    onTap: () =>
                        setState(() => _pricingType = PricingType.fixed),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PricingTypeChip(
                    label: 'Por cotización',
                    icon: Icons.calculate_outlined,
                    selected: _pricingType == PricingType.quote,
                    onTap: () =>
                        setState(() => _pricingType = PricingType.quote),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Precio (solo si es fijo)
            if (_pricingType == PricingType.fixed) ...[
              AppTextField(
                label: 'Precio (RD\$)',
                hint: 'Ej: 25000',
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa el precio';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Precio inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Descripción
            AppTextField(
              label: 'Descripción del precio (opcional)',
              hint: 'Ej: Por sesión de 3 horas, incluye materiales',
              controller: _descCtrl,
              maxLines: 2,
              prefixIcon: Icons.info_outline,
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Guardar servicio',
              onPressed: _save,
              isLoading: _isSaving,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PricingTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PricingTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
