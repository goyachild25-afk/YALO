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
                    'Para usar la plataforma debes ser mayor de 18 años, tener capacidad legal, y proporcionar información veraz. Al registrarte declaras que los datos que suministras son ciertos y actualizados. YALO puede suspender o eliminar cualquier cuenta con información falsa, duplicada o utilizada para fines ilícitos, sin necesidad de aviso previo. YALO podrá solicitar documentación que acredite tu edad e identidad en cualquier momento, incluyendo como parte del proceso de verificación descrito en el artículo 10.',
                  ),
                  _buildSection(
                    '3. Obligaciones del Prestador',
                    '• Ejecutar los servicios con la diligencia de un buen profesional.\n'
                    '• Cumplir con los estándares de seguridad, higiene y buen trato.\n'
                    '• Respetar la propiedad y la privacidad del Cliente.\n'
                    '• Emitir factura fiscal cuando la normativa tributaria lo exija.\n'
                    '• Cumplir con toda ley laboral y de seguridad social que le sea aplicable como trabajador independiente.\n'
                    '• Portar identificación válida durante la prestación del servicio.\n'
                    '• Declarar y pagar sus propios impuestos ante las autoridades fiscales correspondientes, en su condición de trabajador independiente; YALO no asume esa obligación en su nombre.',
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
                    '9. Suspensión y terminación de cuentas',
                    'YALO podrá suspender o eliminar de forma inmediata, sin necesidad de aviso previo, cualquier cuenta involucrada en:\n\n'
                    '• Fraude o intento de fraude.\n'
                    '• Violencia, acoso o amenazas hacia otro usuario.\n'
                    '• Lavado de activos u otras actividades ilícitas.\n'
                    '• Incumplimiento reiterado de estos Términos.\n'
                    '• Cualquier actividad que ponga en riesgo la seguridad de otros usuarios o de la plataforma.\n\n'
                    'La suspensión o eliminación bajo este artículo no genera responsabilidad de YALO frente al usuario afectado, sin perjuicio de su derecho a solicitar revisión del caso conforme al proceso de mediación (artículo 7).',
                  ),
                  _buildSection(
                    '10. Verificación de identidad — alcance y límites',
                    'YALO exige a los Prestadores completar un proceso de verificación de identidad (cédula + reconocimiento facial) a través de un proveedor externo especializado, como condición para operar en la plataforma. Esta verificación confirma que la persona registrada corresponde al documento presentado, pero NO constituye una garantía absoluta de la identidad, honestidad, antecedentes o capacidad profesional del Prestador. El Cliente reconoce que la contratación del servicio se realiza bajo su propio criterio y responsabilidad, y que YALO no asume el rol de garante de la idoneidad del Prestador más allá de la verificación descrita.',
                  ),
                  _buildSection(
                    '11. Seguros',
                    'YALO no ofrece ni comercializa pólizas de seguro para Clientes ni Prestadores. La Garantía YALO descrita en el artículo 5 es un mecanismo de reembolso interno de la plataforma, no un producto de seguro regulado, y está sujeta a los términos y límites que YALO defina y comunique en la app. Cualquier seguro adicional (responsabilidad civil, accidentes de trabajo, etc.) es responsabilidad exclusiva de cada Prestador conforme a su condición de trabajador independiente.',
                  ),
                  _buildSection(
                    '12. Propiedad intelectual y licencia de uso',
                    'La aplicación YALO, su código fuente, diseño, marca, logo, nombre comercial, algoritmos y demás elementos de la plataforma son propiedad exclusiva de YALO o de sus licenciantes, y están protegidos por la legislación dominicana e internacional de propiedad intelectual.\n\n'
                    'Al usar la app, YALO te otorga una licencia limitada, personal, no exclusiva, no transferible y revocable para acceder y utilizar la plataforma únicamente con los fines para los que fue diseñada. Esta licencia no te otorga ningún derecho de propiedad sobre el software, la marca, el código o los algoritmos de YALO. Queda prohibido copiar, modificar, descompilar, distribuir o crear obras derivadas de la plataforma sin autorización expresa y por escrito de YALO.\n\n'
                    'YALO y sus signos distintivos (nombre, logo, eslogan) son propiedad exclusiva de YALO y se encuentran en proceso de registro ante la Oficina Nacional de la Propiedad Industrial (ONAPI); su uso no autorizado por terceros está prohibido.',
                  ),
                  _buildSection(
                    '13. Contenido generado por usuarios',
                    'Las fotografías, comentarios, reseñas, calificaciones y demás contenido que subas a la plataforma ("Contenido de Usuario") siguen siendo de tu propiedad, pero al publicarlos otorgas a YALO una licencia mundial, no exclusiva y libre de regalías para usarlos, reproducirlos y mostrarlos dentro de la operación y promoción de la plataforma (por ejemplo, en el perfil público de un Prestador o en materiales de marketing), respetando en todo momento tu derecho a la imagen y los límites de esta Política de Privacidad.\n\n'
                    'YALO se reserva el derecho de moderar, ocultar o eliminar reseñas y comentarios que sean falsos, difamatorios, resultado de manipulación de reputación (por ejemplo, autocalificaciones o intercambios de reseñas entre cuentas relacionadas), o que violen estos Términos.',
                  ),
                  _buildSection(
                    '14. Cuentas inactivas',
                    'Una cuenta se considera inactiva cuando no registra inicio de sesión ni actividad por un período de 24 meses consecutivos. YALO podrá notificar al correo registrado antes de suspender una cuenta inactiva y, transcurrido un plazo adicional de 30 días sin respuesta, podrá suspenderla o eliminarla conforme a los plazos de retención de datos descritos en el artículo 24.',
                  ),
                  _buildSection(
                    '15. Fuerza mayor',
                    'YALO no será responsable por retrasos o incumplimientos ocasionados por eventos fuera de su control razonable, incluyendo desastres naturales, fallas de conectividad a internet o de proveedores de infraestructura (hosting, procesadores de pago), apagones, huelgas, actos gubernamentales, pandemias, conflictos civiles u otros eventos de fuerza mayor.',
                  ),
                  _buildSection(
                    '16. Renuncia de garantías',
                    'La plataforma se ofrece "tal como está" ("as is") y "según disponibilidad", sin garantizar que su funcionamiento será ininterrumpido, libre de errores, o compatible con todos los dispositivos o navegadores. YALO no garantiza que los Prestadores estén disponibles en todo momento ni que un servicio solicitado será aceptado.',
                  ),
                  _buildSection(
                    '17. Limitación de responsabilidad — reparación mediante servicio equivalente',
                    'Salvo dolo o culpa grave, YALO no responde por: daños derivados de la relación entre Cliente y Prestador, interrupciones del servicio por fuerza mayor o mantenimiento, errores u omisiones de los usuarios, lucro cesante, daños indirectos, daños consecuenciales, pérdida de oportunidades, pérdida de reputación, o pérdida de información.\n\n'
                    'Cuando una falla sea atribuible directamente a YALO (por ejemplo, un error de cobro, la pérdida de una reserva por falla técnica, o la indisponibilidad de la plataforma), la reparación consiste en que YALO cubra el costo de un servicio equivalente prestado por un Prestador de la plataforma, sin costo adicional para el Cliente. YALO no ofrece compensaciones en efectivo por este concepto.\n\n'
                    'Esta reparación procede una vez verificada la falla mediante la evidencia disponible en la plataforma (registros técnicos, historial de la reserva, mensajes de chat), conforme al proceso de revisión del artículo 7.\n\n'
                    'Esta limitación no aplica en casos de dolo o culpa grave de YALO, ni pretende limitar derechos irrenunciables reconocidos por la legislación de protección al consumidor de República Dominicana (Ley 358-05); en esos casos la reparación se determinará conforme a la ley aplicable.',
                  ),
                  _buildSection(
                    '18. Modificaciones, resolución amistosa y jurisdicción',
                    'YALO se reserva el derecho de modificar estos términos. Los cambios sustanciales serán notificados con al menos 15 días de anticipación por medio de la app o el correo registrado. El uso continuado tras la fecha de vigencia constituye aceptación de los nuevos términos.\n\n'
                    'Antes de acudir a los tribunales, las partes procurarán resolver cualquier disputa de forma amistosa durante un plazo de 30 días contados desde la notificación escrita del reclamo, salvo que la ley disponga un plazo distinto o se trate de una materia no susceptible de negociación.\n\n'
                    'Estos términos se rigen por las leyes de la República Dominicana. Cualquier disputa no resuelta por mediación ni por la vía amistosa será sometida a los tribunales de justicia del Distrito Nacional, con expresa renuncia a cualquier otro fuero.',
                  ),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════════════
                  // II. POLÍTICA DE PRIVACIDAD (Ley 172-13)
                  // ═══════════════════════════════════════════════════════════
                  _buildSectionTitle(
                      'II. Política de Privacidad (Ley 172-13)'),
                  const SizedBox(height: 12),

                  _buildSection(
                    '19. Responsable del tratamiento',
                    'YALO (en adelante, "el Responsable") es la entidad responsable del tratamiento de los datos personales recopilados a través de la plataforma. Contacto para asuntos de privacidad: privacidad@yalo.do. Puedes ejercer tus derechos ARCO (Acceso, Rectificación, Cancelación, Oposición y Portabilidad) escribiendo a esa dirección.',
                  ),
                  _buildSection(
                    '20. Datos que recopilamos',
                    'Recopilamos las siguientes categorías de datos personales:\n\n'
                    '• Datos de identificación: nombre completo, número de cédula, fecha de nacimiento.\n'
                    '• Datos de contacto: correo electrónico, número de teléfono, dirección.\n'
                    '• Datos biométricos: foto de perfil, selfie de verificación (solo Prestadores). La selfie se procesa mediante reconocimiento facial y detección de vida en tiempo real (liveness) a través de un proveedor externo especializado en verificación de identidad, para confirmar que la persona coincide con el documento de cédula.\n'
                    '• Datos documentales: fotos de cédula (solo Prestadores).\n'
                    '• Datos operativos: historial de reservas, mensajes de chat, reseñas, ubicación aproximada.\n'
                    '• Datos técnicos: dispositivo, sistema operativo, dirección IP, cookies estrictamente necesarias.\n\n'
                    'No recopilamos datos sensibles adicionales (opinión política, religiosa, salud) más allá de los descritos.',
                  ),
                  _buildSection(
                    '21. Finalidades del tratamiento',
                    'Usamos tus datos exclusivamente para:\n\n'
                    '• Prestar el servicio de la plataforma (búsqueda, reserva, chat, pago, resolución de disputas).\n'
                    '• Verificar tu identidad y prevenir fraude.\n'
                    '• Cumplir obligaciones legales, fiscales y regulatorias.\n'
                    '• Enviarte notificaciones operativas (confirmaciones, recordatorios, alertas de seguridad).\n'
                    '• Mejorar la plataforma mediante métricas agregadas y anónimas.\n\n'
                    'No usamos tus datos para publicidad de terceros ni los vendemos.',
                  ),
                  _buildSection(
                    '22. Base legal (Ley 172-13, arts. 6-8)',
                    'La base legal para el tratamiento de tus datos es el consentimiento libre, expreso e informado que otorgas al aceptar estos términos, así como la ejecución del contrato de uso de la plataforma. En algunos casos específicos, la base legal es el cumplimiento de una obligación legal (por ejemplo, retención tributaria).',
                  ),
                  _buildSection(
                    '23. Tus derechos (ARCO + Portabilidad)',
                    'Conforme a la Ley 172-13 tienes derecho a:\n\n'
                    '• ACCESO: consultar qué datos tenemos sobre ti. Botón "Descargar mis datos" en tu perfil.\n'
                    '• RECTIFICACIÓN: corregir datos inexactos desde tu perfil o solicitándolo por correo.\n'
                    '• CANCELACIÓN: eliminar tu cuenta y todos los datos vinculados. Botón "Eliminar mi cuenta" en tu perfil.\n'
                    '• OPOSICIÓN: negarte a tratamientos específicos escribiendo a privacidad@yalo.do.\n'
                    '• PORTABILIDAD: recibir tus datos en formato estructurado y legible.\n\n'
                    'Respondemos las solicitudes dentro de 15 días hábiles.',
                  ),
                  _buildSection(
                    '24. Retención de datos',
                    'Conservamos tus datos personales mientras tu cuenta esté activa. Al eliminar tu cuenta, aplicamos:\n\n'
                    '• Anonimización inmediata de datos operativos (nombre, correo, avatar).\n'
                    '• Retención por 5 años de datos financieros y de reservas, requerida por normativa contable y fiscal (Ley 11-92 y sus modificaciones).\n'
                    '• Retención por 10 años de evidencia de disputas resueltas, para responder a reclamos judiciales que puedan presentarse.\n'
                    '• Las fotos de cédula y la selfie de verificación se eliminan automáticamente 90 días después de que tu solicitud es revisada (aprobada o rechazada). El resultado de la verificación (aprobado/rechazado y fecha) se conserva para fines de auditoría, pero no las imágenes.\n\n'
                    'Tras esos plazos, los datos son eliminados definitivamente.',
                  ),
                  _buildSection(
                    '25. Seguridad',
                    'Aplicamos medidas técnicas y organizativas para proteger tus datos: cifrado en tránsito (TLS 1.3), cifrado en reposo (AES-256), control de acceso por roles, auditoría de todas las acciones administrativas, y revisiones periódicas de seguridad. Ningún sistema es 100% infalible; en caso de brecha de seguridad que afecte datos personales, te notificaremos dentro de 72 horas y reportaremos a la autoridad competente conforme al artículo 62 de la Ley 172-13.',
                  ),
                  _buildSection(
                    '26. Transferencia internacional',
                    'Algunos de nuestros proveedores tecnológicos operan servidores fuera de República Dominicana (Estados Unidos, Unión Europea). Al aceptar estos términos consientes la transferencia internacional de tus datos, la cual se realiza con las garantías técnicas y contractuales requeridas por la Ley 172-13 (art. 41-42).',
                  ),
                  _buildSection(
                    '27. Cookies y tecnologías similares',
                    'Usamos únicamente cookies estrictamente necesarias para el funcionamiento de la sesión y las preferencias del usuario (idioma, tamaño de texto, tema claro/oscuro). No usamos cookies de terceros para publicidad ni tracking de comportamiento.',
                  ),
                  _buildSection(
                    '28. Cambios en la política',
                    'Los cambios sustanciales a esta política serán notificados en la aplicación y por correo con al menos 15 días de anticipación. Si no estás de acuerdo con los cambios, puedes eliminar tu cuenta antes de la fecha de entrada en vigencia. Si en el futuro incorporamos nuevas tecnologías de tratamiento de datos (por ejemplo, nuevas capacidades de inteligencia artificial o geolocalización continua), actualizaremos esta política y te lo notificaremos conforme a lo indicado en este artículo.',
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Última actualización: Julio 2026 — incorpora fuerza mayor, propiedad intelectual, renuncia de garantías, protección de marca, responsabilidad fiscal del prestador y demás recomendaciones de una revisión legal preliminar. Pendiente validación final por abogado dominicano licenciado.',
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
