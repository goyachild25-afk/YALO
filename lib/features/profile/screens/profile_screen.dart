import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

const List<String> _provinces = [
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _selectedProvince;
  bool _isEditing = false;
  bool _isSaving = false;
  Uint8List? _avatarBytes;
  String? _avatarExt;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    setState(() {
      _avatarBytes = bytes;
      _avatarExt = ext.isEmpty ? 'jpg' : ext;
    });
  }

  void _populate(UserModel user) {
    _nameCtrl.text = user.fullName;
    _phoneCtrl.text = user.phone ?? '';
    _cityCtrl.text = user.city ?? '';
    _selectedProvince = user.province;
  }

  Future<void> _save(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      // Upload avatar if a new one was picked
      String? newAvatarUrl;
      if (_avatarBytes != null) {
        try {
          final path = '${user.id}_avatar.${_avatarExt ?? 'jpg'}';
          await SupabaseService.client.storage.from('avatars').uploadBinary(
            path,
            _avatarBytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _avatarExt == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
          newAvatarUrl = SupabaseService.client.storage
              .from('avatars')
              .getPublicUrl(path);
        } catch (_) {
          // Storage bucket may not exist yet — skip avatar upload silently
        }
      }

      await SupabaseService.client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'province': _selectedProvince,
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
      }).eq('id', user.id);

      ref.invalidate(currentUserProvider);
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
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
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                userAsync.whenData((u) {
                  if (u != null) _populate(u);
                });
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No se pudo cargar el perfil'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(user),
                  const SizedBox(height: 24),
                  _buildRoleBadge(user),
                  const SizedBox(height: 24),
                  if (_isEditing) ...[
                    _buildEditForm(user),
                  ] else ...[
                    _buildProfileInfo(user),
                  ],
                  const SizedBox(height: 32),
                  _buildActions(user),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    final ImageProvider<Object>? bg = _avatarBytes != null
        ? MemoryImage(_avatarBytes!) as ImageProvider<Object>
        : user.avatarUrl != null
            ? CachedNetworkImageProvider(user.avatarUrl!) as ImageProvider<Object>
            : null;

    return Center(
      child: GestureDetector(
        onTap: _isEditing ? _pickAvatar : null,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primaryLighter,
              backgroundImage: bg,
              child: bg == null
                  ? Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            if (_isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserModel user) {
    final isProvider = user.role == UserRole.provider;
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isProvider ? AppColors.infoLight : AppColors.successLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isProvider ? Icons.work_outline : Icons.person_outline,
              size: 14,
              color: isProvider ? AppColors.info : AppColors.success,
            ),
            const SizedBox(width: 6),
            Text(
              isProvider ? 'Prestador de servicios' : 'Cliente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isProvider ? AppColors.info : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(UserModel user) {
    return Column(
      children: [
        _InfoTile(
          icon: Icons.person_outline,
          label: 'Nombre completo',
          value: user.fullName,
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Correo electrónico',
          value: user.email,
        ),
        if (user.phone != null && user.phone!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Teléfono',
            value: user.phone!,
          ),
        ],
        if (user.province != null || user.city != null) ...[
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Ubicación',
            value: [user.city, user.province]
                .where((v) => v != null && v.isNotEmpty)
                .join(', '),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm(UserModel user) {
    return Column(
      children: [
        AppTextField(
          label: 'Nombre completo',
          controller: _nameCtrl,
          prefixIcon: Icons.person_outline,
          validator: (v) =>
              v == null || v.length < 3 ? 'Nombre muy corto' : null,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Teléfono',
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'Provincia',
          value: _selectedProvince,
          prefixIcon: Icons.location_on_outlined,
          items: _provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _selectedProvince = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Ciudad / Cantón',
          controller: _cityCtrl,
          prefixIcon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Cancelar',
                onPressed: () => setState(() => _isEditing = false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Guardar',
                onPressed: () => _save(user),
                isLoading: _isSaving,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(UserModel user) {
    return Column(
      children: [
        if (user.role == UserRole.provider) ...[
          _ActionTile(
            icon: Icons.verified_user_outlined,
            label: 'Verificar mi identidad',
            onTap: () => context.push('/verify-identity'),
          ),
          _ActionTile(
            icon: Icons.settings_outlined,
            label: 'Configurar mis servicios',
            onTap: () => context.push('/my-services'),
          ),
        ],
        _ActionTile(
          icon: Icons.help_outline,
          label: 'Ayuda y soporte',
          onTap: () => context.push('/help'),
        ),
        _ActionTile(
          icon: Icons.security_outlined,
          label: 'Cambiar contraseña',
          onTap: () => context.push('/change-password'),
        ),
        const SizedBox(height: 16),
        SecondaryButton(
          label: 'Cerrar sesión',
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (mounted) context.go('/login');
          },
          icon: Icons.logout,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
