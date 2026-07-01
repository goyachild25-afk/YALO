/// Stub para plataformas donde Web Speech API no aplica (mobile, desktop).
bool isSupported() => false;

Future<String?> listenOnce({String lang = 'es-DO'}) async => null;
