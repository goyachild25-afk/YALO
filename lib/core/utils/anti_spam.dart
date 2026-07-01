/// Detecta y ofusca datos de contacto en el chat para evitar que
/// prestadores y clientes se lleven la relación fuera de la plataforma
/// (evadiendo la comisión, la garantía y el sistema de mediación).
///
/// Estrategia: no bloqueamos el envío — el mensaje se envía pero los
/// contactos aparecen tachados con "🔒 (oculto por seguridad)". Un banner
/// educativo aparece al usuario que intenta compartir datos.
class AntiSpam {
  AntiSpam._();

  // Regex para número de teléfono dominicano (múltiples formatos)
  //   809/829/849 con o sin +1, con guiones/espacios/paréntesis
  //   También detecta 8 dígitos seguidos que podrían ser un teléfono
  static final _phoneRegex = RegExp(
    r'(\+?1[\s\-\.]?)?\(?(809|829|849)\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4}'
    r'|(?<!\d)\d{10}(?!\d)'
    r'|(?<!\d)\d{3}[\s\-\.]\d{3}[\s\-\.]\d{4}(?!\d)',
    caseSensitive: false,
  );

  // Email básico
  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  // Links / dominios (whatsapp.com, instagram, cualquier http)
  static final _linkRegex = RegExp(
    r'https?://\S+|(?:wa\.me|whatsapp\.com|instagram\.com|t\.me|telegram\.me)/\S+',
    caseSensitive: false,
  );

  // Frases que suenan a "vamos a WhatsApp / paguem fuera"
  static final _bypassPhrases = RegExp(
    r'(fuera de la plataforma|fuera de la app|te doy mi whatsapp|te paso mi numero|mándame tu whatsapp|pág(?:a|ame) en efectivo|sin la comisión|evitar la comisi)',
    caseSensitive: false,
  );

  /// Devuelve `true` si el texto contiene algún patrón que debemos bloquear.
  static bool containsSensitive(String text) {
    return _phoneRegex.hasMatch(text) ||
        _emailRegex.hasMatch(text) ||
        _linkRegex.hasMatch(text) ||
        _bypassPhrases.hasMatch(text);
  }

  /// Motivo específico del bloqueo, en lenguaje amigable.
  static String? reasonFor(String text) {
    if (_phoneRegex.hasMatch(text)) return 'un número de teléfono';
    if (_emailRegex.hasMatch(text)) return 'un correo electrónico';
    if (_linkRegex.hasMatch(text)) return 'un enlace externo';
    if (_bypassPhrases.hasMatch(text)) {
      return 'una propuesta de acordar el pago fuera de la plataforma';
    }
    return null;
  }

  /// Reemplaza los patrones sensibles con "🔒 (oculto)" para que el mensaje
  /// se pueda enviar sin filtrar el contacto.
  static String redact(String text) {
    return text
        .replaceAll(_phoneRegex, '🔒 (oculto)')
        .replaceAll(_emailRegex, '🔒 (oculto)')
        .replaceAll(_linkRegex, '🔒 (oculto)');
  }
}
