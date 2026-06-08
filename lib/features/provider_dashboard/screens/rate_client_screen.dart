import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class RateClientScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String clientId;
  final String clientName;
  final String serviceName;

  const RateClientScreen({
    super.key,
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    required this.serviceName,
  });

  @override
  ConsumerState<RateClientScreen> createState() => _RateClientScreenState();
}

class _RateClientScreenState extends ConsumerState<RateClientScreen> {
  double _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyRated();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAlreadyRated() async {
    final isDemo = ref.read(demoModeProvider);
    if (isDemo) return;

    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final providerProfile = await SupabaseService.client
          .from('provider_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (providerProfile == null) return;

      final existing = await SupabaseService.client
          .from('client_ratings')
          .select('id')
          .eq('booking_id', widget.bookingId)
          .eq('provider_id', providerProfile['id'])
          .maybeSingle();

      if (existing != null && mounted) {
        setState(() => _alreadyRated = true);
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _isSending = true);

    try {
      final isDemo = ref.read(demoModeProvider);

      if (!isDemo) {
        final user = SupabaseService.currentUser!;
        final providerProfile = await SupabaseService.client
            .from('provider_profiles')
            .select('id')
            .eq('user_id', user.id)
            .single();

        await SupabaseService.client.from('client_ratings').insert({
          'booking_id': widget.bookingId,
          'provider_id': providerProfile['id'],
          'client_id': widget.clientId,
          'rating': _rating,
          'comment': _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
      }

      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar cliente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _sent
              ? _buildSuccess()
              : _alreadyRated
                  ? _buildAlreadyRated()
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  widget.clientName.isNotEmpty
                      ? widget.clientName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.serviceName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Aviso de propósito ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.info.withValues(alpha: 0.25)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tu calificación ayuda a mantener la calidad de la plataforma y alerta a otros prestadores sobre clientes problemáticos.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.info, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Estrellas ────────────────────────────────────────────
        const Text(
          '¿Cómo fue la experiencia con este cliente?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = (i + 1).toDouble()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < _rating
                            ? AppColors.star
                            : AppColors.divider,
                        size: 44,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _ratingLabel(_rating),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ratingColor(_rating),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Rótulos rápidos ──────────────────────────────────────
        const Text(
          'Etiquetas rápidas',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _QuickTags(
          onTagSelected: (tag) {
            final current = _commentCtrl.text;
            if (current.isNotEmpty && !current.endsWith(' ')) {
              _commentCtrl.text = '$current $tag';
            } else {
              _commentCtrl.text = '$current$tag';
            }
            _commentCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _commentCtrl.text.length),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Comentario ───────────────────────────────────────────
        AppTextField(
          label: 'Comentario (opcional)',
          hint: 'Ej: Cliente puntual, hogar ordenado, buen trato...',
          controller: _commentCtrl,
          maxLines: 4,
          prefixIcon: Icons.comment_outlined,
        ),
        const SizedBox(height: 32),

        // ── Botones ──────────────────────────────────────────────
        PrimaryButton(
          label: 'Enviar calificación',
          onPressed: _submit,
          isLoading: _isSending,
          icon: Icons.star_outline,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Omitir por ahora',
          onPressed: () => context.pop(),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.successLight,
            child: const Icon(Icons.star_rounded,
                size: 60, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '¡Gracias por calificar!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Tu opinión ayuda a construir una comunidad más\nsegura y confiable en ServiciosYa.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Volver al panel',
          onPressed: () => context.go('/dashboard'),
        ),
      ],
    );
  }

  Widget _buildAlreadyRated() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.warningLight,
            child: const Icon(Icons.check_circle_outline,
                size: 60, color: AppColors.warning),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Ya calificaste este servicio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Solo puedes calificar un cliente una vez por servicio.',
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Volver al panel',
          onPressed: () => context.go('/dashboard'),
        ),
      ],
    );
  }

  String _ratingLabel(double r) {
    if (r >= 5) return '😍 Excelente cliente';
    if (r >= 4) return '😊 Muy buen cliente';
    if (r >= 3) return '😐 Cliente regular';
    if (r >= 2) return '😟 Cliente difícil';
    return '😡 Mala experiencia';
  }

  Color _ratingColor(double r) {
    if (r >= 4) return AppColors.success;
    if (r >= 3) return AppColors.warning;
    return AppColors.error;
  }
}

// ── Etiquetas rápidas ─────────────────────────────────────────────────────────
class _QuickTags extends StatefulWidget {
  final void Function(String tag) onTagSelected;
  const _QuickTags({required this.onTagSelected});

  @override
  State<_QuickTags> createState() => _QuickTagsState();
}

class _QuickTagsState extends State<_QuickTags> {
  final Set<String> _selected = {};

  static const List<String> _positiveTags = [
    'Puntual ✅',
    'Buen trato 👍',
    'Hogar ordenado 🏠',
    'Pagó a tiempo 💰',
    'Comunicativo 💬',
  ];

  static const List<String> _negativeTags = [
    'Impuntual ⏰',
    'Mal trato ⚠️',
    'Desorganizado 😕',
    'Difícil de contactar 📵',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTagRow('Positivas', _positiveTags, isPositive: true),
        const SizedBox(height: 8),
        _buildTagRow('Negativas', _negativeTags, isPositive: false),
      ],
    );
  }

  Widget _buildTagRow(String label, List<String> tags,
      {required bool isPositive}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final selected = _selected.contains(tag);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selected.remove(tag);
              } else {
                _selected.add(tag);
                widget.onTagSelected(tag);
              }
            });
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? (isPositive
                      ? AppColors.successLight
                      : AppColors.errorLight)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? (isPositive ? AppColors.success : AppColors.error)
                    : AppColors.divider,
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? (isPositive ? AppColors.success : AppColors.error)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
