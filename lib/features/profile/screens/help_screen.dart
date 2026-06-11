import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y soporte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Buscar ayuda ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.textHint),
                SizedBox(width: 10),
                Text('¿En qué podemos ayudarte?',
                    style:
                        TextStyle(color: AppColors.textHint, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Preguntas frecuentes ─────────────────────────────
          const _SectionHeader('Preguntas frecuentes'),
          const SizedBox(height: 12),
          const _FAQItem(
            question: '¿Cómo solicito un servicio?',
            answer:
                'Selecciona una categoría en el inicio, elige un prestador, revisa su perfil y toca "Solicitar servicio". Llena el formulario con la fecha, hora y dirección, y confirma.',
          ),
          const _FAQItem(
            question: '¿Cómo me registro como prestador?',
            answer:
                'En la pantalla de login, toca "Registrarme como prestador". Completa tu perfil, agrega tus servicios con precios y envía tu verificación de identidad. Una vez aprobado, aparecerás en las búsquedas.',
          ),
          const _FAQItem(
            question: '¿Cómo funciona el pago?',
            answer:
                'Los servicios de precio fijo se pagan al momento de confirmar la reserva con tarjeta de crédito o débito. Los servicios por cotización se pagan una vez que el prestador te envíe el precio y lo aceptes.',
          ),
          const _FAQItem(
            question: '¿Puedo cancelar una reserva?',
            answer:
                'Sí, puedes cancelar reservas en estado "Pendiente" desde la pantalla "Mis servicios". Las reservas ya aceptadas deben coordinarse directamente con el prestador por el chat.',
          ),
          const _FAQItem(
            question: '¿Cuánto cobra la plataforma?',
            answer:
                'ServiciosYa cobra una comisión total del 10%: un 5% de Garantía ServiciosYa lo paga el cliente, y un 5% de Membresía de Visibilidad se descuenta al prestador. El prestador recibe el 95% del precio base acordado.',
          ),
          const _FAQItem(
            question: '¿Cómo verifico mi identidad como prestador?',
            answer:
                'Ve a tu perfil → "Verificar mi identidad". Necesitarás tu número de cédula, una foto del frente y reverso de tu cédula, y una selfie. El equipo de ServiciosYa revisará tu solicitud en 24-48 horas.',
          ),
          const SizedBox(height: 28),

          // ── Contacto ─────────────────────────────────────────
          const _SectionHeader('Contacto directo'),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.email_outlined,
            label: 'Correo electrónico',
            value: 'soporte@ServiciosYa.cr',
            color: AppColors.primary,
            onTap: () {}, // url_launcher para abrir correo
          ),
          const SizedBox(height: 8),
          _ContactTile(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            value: '+1-809-555-0000',
            color: const Color(0xFF25D366),
            onTap: () {}, // abrir WhatsApp
          ),
          const SizedBox(height: 8),
          _ContactTile(
            icon: Icons.access_time_outlined,
            label: 'Horario de atención',
            value: 'Lunes a viernes, 8am – 6pm',
            color: AppColors.textSecondary,
            onTap: null,
          ),
          const SizedBox(height: 28),

          // ── Legal ────────────────────────────────────────────
          const _SectionHeader('Legal'),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.gavel_outlined,
            label: 'Términos y condiciones',
            value: 'Ver documento completo',
            color: AppColors.primary,
            onTap: () => context.push('/terms'),
          ),
          const SizedBox(height: 8),
          _ContactTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de privacidad',
            value: 'Ley 172-13 — República Dominicana',
            color: AppColors.primary,
            onTap: () => context.push('/terms'),
          ),
          const SizedBox(height: 28),

          // ── Versión ──────────────────────────────────────────
          const Center(
            child: Column(
              children: [
                Icon(Icons.cleaning_services_rounded,
                    color: AppColors.primary, size: 32),
                SizedBox(height: 8),
                Text('ServiciosYa',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text('Versión 1.0.0',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _expanded
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Text(
                  widget.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            if (onTap != null) ...[
              const Spacer(),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}
