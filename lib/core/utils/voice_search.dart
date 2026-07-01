import 'dart:async';
import 'package:flutter/foundation.dart';

// Import condicional: en web usamos la implementación con SpeechRecognition,
// en mobile devolvemos siempre null (fallback silencioso).
import 'voice_search_stub.dart'
    if (dart.library.js_interop) 'voice_search_web_impl.dart' as impl;

class VoiceSearch {
  VoiceSearch._();

  /// Web + Chrome/Edge/Safari 14.1+ soportan `SpeechRecognition`. En cualquier
  /// otro caso el mic simplemente no aparecerá porque `isSupported` es false.
  static bool get isSupported {
    if (!kIsWeb) return false;
    return impl.isSupported();
  }

  /// Escucha una sola frase en español-DO y devuelve el texto reconocido.
  /// Devuelve null si el usuario canceló o no habló.
  static Future<String?> listenOnce({String lang = 'es-DO'}) =>
      impl.listenOnce(lang: lang);
}
