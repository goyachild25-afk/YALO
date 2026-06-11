import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

class TermsScreen extends StatefulWidget {
  final bool mustAccept; // true = modal de aceptación, false = solo lectura
  const TermsScreen({super.key, this.mustAccept = false});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y condiciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSection(
                    '1. Propósito de la plataforma',
                    'ServiciosYa es una plataforma tecnológica que conecta a personas que ofrecen servicios del hogar (prestadores) con personas que los necesitan (clientes). ServiciosYa actúa como intermediario y no es empleador de ningún prestador.',
                  ),
                  _buildSection(
                    '2. Uso de información personal',
                    'Recopilamos tu nombre completo, número de cédula, fotografías y datos de contacto con el único fin de:\n\n'
                    '• Verificar tu identidad y prevenir el uso de cuentas falsas.\n'
                    '• Garantizar la seguridad de todos los usuarios.\n'
                    '• Cumplir con las leyes de la República Dominicana.\n'
                    '• Facilitar la resolución de disputas y reclamos.\n\n'
                    'Tu información nunca será vendida a terceros. Está protegida bajo la Ley Orgánica sobre Protección de Datos de Carácter Personal (Ley 172-13).',
                  ),
                  _buildSection(
                    '3. Responsabilidad del prestador',
                    'Al registrarte como prestador, declaras que:\n\n'
                    '• La información y documentos que proporcionas son auténticos.\n'
                    '• Cuentas con las habilidades necesarias para los servicios que ofreces.\n'
                    '• Te comprometes a tratar con respeto la propiedad y privacidad del cliente.\n'
                    '• Entiendes que proporcionar información falsa es causa inmediata de suspensión y puede conllevar consecuencias legales.',
                  ),
                  _buildSection(
                    '4. Responsabilidad del cliente',
                    'Al usar ServiciosYa como cliente, te comprometes a:\n\n'
                    '• Proporcionar información veraz sobre el servicio solicitado.\n'
                    '• Tratar con respeto al prestador durante el servicio.\n'
                    '• No realizar cargos falsos o disputas infundadas.\n'
                    '• Garantizar un ambiente seguro para el prestador en tu propiedad.',
                  ),
                  _buildSection(
                    '5. Pagos y comisiones',
                    'ServiciosYa cobra una comisión del 15% sobre el valor de cada servicio. Esta comisión financia la operación de la plataforma, el sistema de seguridad y el soporte al usuario.\n\n'
                    'Los pagos se procesan de forma segura. En ningún momento ServiciosYa almacena datos de tarjetas de crédito o débito.',
                  ),
                  _buildSection(
                    '6. Sistema de disputas',
                    'En caso de conflicto entre las partes, ServiciosYa ofrece un proceso de mediación. El equipo de ServiciosYa revisará la evidencia presentada y emitirá una resolución. Ambas partes aceptan someterse a este proceso como paso previo a cualquier acción legal.',
                  ),
                  _buildSection(
                    '7. Prohibiciones',
                    'Está expresamente prohibido:\n\n'
                    '• Acordar pagos fuera de la plataforma para evadir comisiones.\n'
                    '• Compartir información personal de otros usuarios.\n'
                    '• Usar la plataforma para actividades ilegales.\n'
                    '• Crear múltiples cuentas para evadir suspensiones.\n\n'
                    'El incumplimiento resultará en suspensión permanente y puede ser reportado a las autoridades competentes.',
                  ),
                  _buildSection(
                    '8. Limitación de responsabilidad',
                    'ServiciosYa no se hace responsable por daños o perjuicios derivados de la relación entre cliente y prestador. Sin embargo, cuenta con mecanismos de mediación y puede suspender cuentas que incumplan estas políticas.',
                  ),
                  _buildSection(
                    '9. Modificaciones',
                    'ServiciosYa se reserva el derecho de modificar estos términos. Los usuarios serán notificados con al menos 15 días de anticipación ante cambios sustanciales.',
                  ),
                  _buildSection(
                    '10. Jurisdicción',
                    'Estos términos se rigen por las leyes de la República Dominicana. Cualquier disputa no resuelta por mediación será sometida a los tribunales de justicia de Santo Domingo, República Dominicana.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Última actualización: Mayo 2025',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Footer de aceptación ─────────────────────────────
          if (widget.mustAccept)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _accepted = !_accepted),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        const Expanded(
                          child: Text(
                            'He leído y acepto los Términos y Condiciones y la Política de Privacidad de ServiciosYa.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Aceptar y continuar',
                    onPressed: _accepted
                        ? () => context.pop(true) // retorna true = aceptado
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: Colors.white, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Términos y Condiciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Lee con atención antes de usar ServiciosYa',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
