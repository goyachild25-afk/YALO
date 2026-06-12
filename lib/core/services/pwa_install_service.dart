import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('deferredPrompt')
external JSAny? get _deferredPrompt;

@JS('isInStandaloneMode')
external bool? get _isInStandaloneMode;

@JS('appInstalled')
external bool? get _appInstalled;

@JS('isIOS')
external bool? get _isIOS;

extension type _InstallPrompt(JSObject _) implements JSObject {
  external void prompt();
}

class PwaInstallService {
  /// True si Chrome capturó beforeinstallprompt (Android)
  static bool get isInstallable {
    if (!kIsWeb) return false;
    try {
      return _deferredPrompt != null;
    } catch (_) {
      return false;
    }
  }

  /// True si ya está instalada o corriendo en modo standalone
  static bool get isAlreadyInstalled {
    if (!kIsWeb) return false;
    try {
      return _isInStandaloneMode == true || _appInstalled == true;
    } catch (_) {
      return false;
    }
  }

  /// True en iOS (Safari no soporta beforeinstallprompt)
  static bool get isIOS {
    if (!kIsWeb) return false;
    try {
      return _isIOS == true;
    } catch (_) {
      return false;
    }
  }

  /// Dispara el diálogo nativo de instalación (Android/Chrome)
  static void triggerInstall() {
    if (!kIsWeb) return;
    try {
      final p = _deferredPrompt;
      if (p != null) {
        _InstallPrompt(p as JSObject).prompt();
      }
    } catch (_) {}
  }

  /// True si debe mostrarse el banner
  static bool get shouldShowBanner {
    if (isAlreadyInstalled) return false;
    return isInstallable || isIOS;
  }
}
