// Web Speech API implementation.
// Nota: `SpeechRecognition` no está tipado por el package `web`, y las APIs
// de js_interop v11 (que usa Flutter 3.32) requieren que evitemos
// `callAsConstructor` y `getProperty`. En su lugar, usamos un shim JS
// embebido en el archivo host (index.html) — o, alternativamente, damos
// por no soportada la funcionalidad si el interop directo no funciona.
//
// Para no bloquear el resto del build, esta implementación reporta
// isSupported=false. Cuando el equipo migre a Flutter con dart:js_interop
// v12+ o agregue el shim, se activa reemplazando este archivo.
bool isSupported() => false;

Future<String?> listenOnce({String lang = 'es-DO'}) async => null;
