import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

/// Términos y Condiciones + Política de Privacidad — borrador para YALO
///
/// IMPORTANTE — este documento cubre los requisitos operativos habituales de
/// una plataforma de marketplace en República Dominicana (Ley 172-13 de
/// protección de datos personales, Ley 358-05 de consumidor, Código Civil).
/// Sin embargo, ANTES DE LANZAMIENTO PÚBLICO debe ser revisado y firmado
/// por un abogado dominicano con especialidad en tecnología y consumidor.
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
        title: const Text('Términos y Política de Privacidad'),
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
                  const SizedBox(height: 12),
                  _buildLegalNotice(),
                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════════════
                  // I. TÉRMINOS Y CONDICIONES DE USO
                  // ═══════════════════════════════════════════════════════════
                  _buildSectionTitle('I. Términos y Condiciones de Uso'),
                  const SizedBox(height: 12),

                  _buildSection(
                    '1. Naturaleza de la plataforma',
                    'YALO es una plataforma tecnológica que conecta a personas que ofrecen servicios del hogar (Prestadores) con personas que los necesitan (Clientes). YALO actúa exclusivamente como intermediario tecnológico y NO es empleador, contratista, ni empresa de servicios respecto de los Prestadores. La relación de servicio se acuerda directamente entre Cliente y Prestador; YALO no es parte de ese contrato.',
                  ),
                  _buildSection(
                    '2. Registro y elegibilidad',
                    'Para usar la plataforma debes ser mayor de 18 años, tener capacidad legal, y proporcionar información veraz. Al registrarte declaras que los datos que suministras son ciertos y actualizados. YALO puede suspender o eliminar cualquier cuenta con información falsa, duplicada o utilizada para fines ilícitos, sin necesidad de aviso previo.',
                  ),
                  _buildSection(
                    '3. Obligaciones del Prestador',
                    '• Ejecutar los servicios con la diligencia de un buen profesional.\n'
                    '• Cumplir con los estándares de seguridad, higiene y buen trato.\n'
                    '• Respetar la propiedad y la privacidad del Cliente.\n'
                    '• Emitir factura fiscal cuando la normativa tributaria lo exija.\n'
                    '• Cumplir con toda ley laboral y de seguridad social que le sea aplicable como trabajador independiente.\n'
                    '• Portar identificación válida durante la prestación del servicio.',
                  ),
                  _buildSection(
                    '4. Obligaciones del Cliente',
                    '• Describir con veracidad el servicio requerido.\n'
                    '• Garantizar un ambiente seguro al Prestador dentro de su propiedad.\n'
                    '• Tratar al Prestador con respeto y sin discriminación.\n'
                    '• Pagar el precio acordado en los términos y plazos pactados.\n'
                    '• No presentar reclamos infundados con el fin de evadir el pago.',
                  ),
                  _buildSection(
                    '5. Precios, pagos y comisiones',
                    'YALO cobra una comisión total del 10% sobre el precio base del servicio, dividida en:\n\n'
                    '• Un 5% de "Garantía YALO" pagado por el Cliente adicional al precio base.\n'
                    '• Un 5% de "Membresía de Visibilidad" descontado al Prestador del monto que recibe.\n\n'
                    'La comisión financia la operación, el sistema de mediación, el soporte al usuario y las verificaciones de identidad.\n\n'
                    'Los pagos se procesan mediante procesadores autorizados. YALO NO almacena datos de tarjetas de crédito o débito en sus servidores; estos datos residen únicamente en el procesador de pagos correspondiente, conforme a los estándares PCI-DSS.',
                  ),
                  _buildSection(
                    '6. Cancelaciones y reembolsos',
                    '• El Cliente puede cancelar una reserva sin costo mientras esté en estado "Pendiente".\n'
                    '• Cancelaciones con menos de 3 horas de anticipación al servicio agendado pueden generar un cargo del 30% del precio como compensación al Prestador.\n'
                    '• Si el Prestador no se presenta o cancela sin causa justificada, YALO reembolsará al Cliente el 100% pagado y podrá aplicar sanciones al Prestador.',
                  ),
                  _buildSection(
                    '7. Sistema de mediación de disputas',
                    'En caso de conflicto entre las partes, YALO ofrece un proceso de mediación con las siguientes etapas: (a) reporte del incidente por cualquiera de las partes; (b) recolección de evidencia (fotos, chat, historial); (c) resolución emitida por el equipo de moderación de YALO dentro de 5 días hábiles. Ambas partes reconocen esta mediación como paso previo obligatorio a cualquier reclamación ante las autoridades competentes. La resolución no es vinculante judicialmente pero puede ser usada como evidencia.',
                  ),
                  _buildSection(
                    '8. Conductas prohibidas',
                    'Está expresamente prohibido:\n\n'
                    '• Acordar pagos fuera de la plataforma con el fin de evadir comisiones.\n'
                    '• Solicitar o compartir datos personales de otros usuarios para fines ajenos al servicio.\n'
                    '• Publicar contenido ofensivo, discriminatorio, obsceno o ilícito.\n'
                    '• Suplantar la identidad de otra persona.\n'
                    '• Crear cuentas múltiples para evadir suspensiones.\n'
                    '• Realizar cargos falsos o disputas infundadas.\n\n'
                    'El incumplimiento resultará en suspensión de la cuenta y podrá ser reportado a las autoridades competentes conforme a la Ley 53-07 sobre Crímenes y Delitos de Alta Tecnología.',
                  ),
                  _buildSection(
                    '9. Limitación de responsabilidad',
                    'Salvo dolo o culpa grave, YALO no responde por: daños derivados de la relación entre Cliente y Prestador, interrupciones del servicio por fuerza mayor o mantenimiento, errores u omisiones de los usuarios, o pérdidas indirectas. En ningún caso la responsabilidad total de YALO excederá el monto de la comisión percibida por la operación en disputa.',
                  ),
                  _buildSection(
                    '10. Modificaciones y jurisdicción',
                    'YALO se reserva el derecho de modificar estos términos. Los cambios sustanciales serán notificados con al menos 15 días de anticipación por medio de la app o el correo registrado. El uso continuado tras la fecha de vigencia constituye aceptación de los nuevos términos.\n\n'
                    'Estos términos se rigen por las leyes de la República Dominicana. Cualquier disputa no resuelta por mediación será sometida a los tribunales de justicia del Distrito Nacional, con expresa renuncia a cualquier otro fuero.',
                  ),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════════════
                  // II. POLÍTICA DE PRIVACIDAD (Ley 172-13)
                  // ═══════════════════════════════════════════════════════════
                  _buildSectionTitle(
                      'II. Política de Privacidad (Ley 172-13)'),
                  const SizedBox(height: 12),

                  _buildSection(
                    '11. Responsable del tratamiento',
                    'YALO (en adelante, "el Responsable") es la entidad responsable del tratamiento de los datos personales recopilados a través de la plataforma. Contacto para asuntos de privacidad: privacidad@yalo.do. Puedes ejercer tus derechos ARCO (Acceso, Rectificación, Cancelación, Oposición y Portabilidad) escribiendo a esa dirección.',
                  ),
                  _buildSection(
                    '12. Datos que recopilamos',
                    'Recopilamos las siguientes categorías de datos personales:\n\n'
                    '• Datos de identificación: nombre completo, número de cédula, fecha de nacimiento.\n'
                    '• Datos de contacto: correo electrónico, número de teléfono, dirección.\n'
                    '• Datos biométricos: foto de perfil, selfie de verificación (solo Prestadores). La selfie y las fotos de cédula son procesadas por un proveedor externo especializado en verificación de identidad para confirmar que la persona coincide con el documento.\n'
                    '• Datos documentales: fotos de cédula (solo Prestadores).\n'
                    '• Datos operativos: historial de reservas, mensajes de chat, reseñas, ubicación aproximada.\n'
                    '• Datos técnicos: dispositivo, sistema operativo, dirección IP, cookies estrictamente necesarias.\n\n'
                    'No recopilamos datos sensibles adicionales (opinión política, religiosa, salud) más allá de los descritos.',
                  ),
                  _buildSection(
                    '13. Finalidades del tratamiento',
                    'Usamos tus datos exclusivamente para:\n\n'
                    '• Prestar el servicio de la plataforma (búsqueda, reserva, chat, pago, resolución de disputas).\n'
                    '• Verificar tu identidad y prevenir fraude.\n'
                    '• Cumplir obligaciones legales, fiscales y regulatorias.\n'
                    '• Enviarte notificaciones operativas (confirmaciones, recordatorios, alertas de seguridad).\n'
                    '• Mejorar la plataforma mediante métricas agregadas y anónimas.\n\n'
                    'No usamos tus datos para publicidad de terceros ni los vendemos.',
                  ),
                  _buildSection(
                    '14. Base legal (Ley 172-13, arts. 6-8)',
                    'La base legal para el tratamiento de tus datos es el consentimiento libre, expreso e informado que otorgas al aceptar estos términos, así como la ejecución del contrato de uso de la plataforma. En algunos casos específicos, la base legal es el cumplimiento de una obligación legal (por ejemplo, retención tributaria).',
                  ),
                  _buildSection(
                    '15. Tus derechos (ARCO + Portabilidad)',
                    'Conforme a la Ley 172-13 tienes derecho a:\n\n'
                    '• ACCESO: consultar qué datos tenemos sobre ti. Botón "Descargar mis datos" en tu perfil.\n'
                    '• RECTIFICACIÓN: corregir datos inexactos desde tu perfil o solicitándolo por correo.\n'
                    '• CANCELACIÓN: eliminar tu cuenta y todos los datos vinculados. Botón "Eliminar mi cuenta" en tu perfil.\n'
                    '• OPOSICIÓN: negarte a tratamientos específicos escribiendo a privacidad@yalo.do.\n'
                    '• PORTABILIDAD: recibir tus datos en formato estructurado y legible.\n\n'
                    'Respondemos las solicitudes dentro de 15 días hábiles.',
                  ),
                  _buildSection(
                    '16. Retención de datos',
                    'Conservamos tus datos personales mientras tu cuenta esté activa. Al eliminar tu cuenta, aplicamos:\n\n'
                    '• Anonimización inmediata de datos operativos (nombre, correo, avatar).\n'
                    '• Retención por 5 años de datos financieros y de reservas, requerida por normativa contable y fiscal (Ley 11-92 y sus modificaciones).\n'
                    '• Retención por 10 años de evidencia de disputas resueltas, para responder a reclamos judiciales que puedan presentarse.\n'
                    '• Las fotos de cédula y la selfie de verificación se eliminan automáticamente 90 días después de que tu solicitud es revisada (aprobada o rechazada). El resultado de la verificación (aprobado/rechazado y fecha) se conserva para fines de auditoría, pero no las imágenes.\n\n'
                    'Tras esos plazos, los datos son eliminados definitivamente.',
                  ),
                  _buildSection(
                    '17. Seguridad',
                    'Aplicamos medidas técnicas y organizativas para proteger tus datos: cifrado en tránsito (TLS 1.3), cifrado en reposo (AES-256), control de acceso por roles, auditoría de todas las acciones administrativas, y revisiones periódicas de seguridad. Ningún sistema es 100% infalible; en caso de brecha de seguridad que afecte datos personales, te notificaremos dentro de 72 horas y reportaremos a la autoridad competente conforme al artículo 62 de la Ley 172-13.',
                  ),
                  _buildSection(
                    '18. Transferencia internacional',
                    'Algunos de nuestros proveedores tecnológicos operan servidores fuera de República Dominicana (Estados Unidos, Unión Europea). Al aceptar estos términos consientes la transferencia internacional de tus datos, la cual se realiza con las garantías técnicas y contractuales requeridas por la Ley 172-13 (art. 41-42).',
                  ),
                  _buildSection(
                    '19. Cookies y tecnologías similares',
                    'Usamos únicamente cookies estrictamente necesarias para el funcionamiento de la sesión y las preferencias del usuario (idioma, tamaño de texto, tema claro/oscuro). No usamos cookies de terceros para publicidad ni tracking de comportamiento.',
                  ),
                  _buildSection(
                    '20. Cambios en la política',
                    'Los cambios sustanciales a esta política serán notificados en la aplicación y por correo con al menos 15 días de anticipación. Si no estás de acuerdo con los cambios, puedes eliminar tu cuenta antes de la fecha de entrada en vigencia.',
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Última actualización: Marzo 2026',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Para consultas sobre privacidad escribe a privacidad@yalo.do',
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
                            'He leído y acepto los Términos y Condiciones y la Política de Privacidad de YALO. Doy mi consentimiento libre, expreso e informado para el tratamiento de mis datos personales conforme a la Ley 172-13.',
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
                        ? () => context.pop(true)
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
                  'Términos y Política de Privacidad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Ley 172-13 · República Dominicana',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.goldDark, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este documento es la política vigente durante la fase piloto. Antes del lanzamiento público será revisado y firmado por un abogado dominicano especializado.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
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
