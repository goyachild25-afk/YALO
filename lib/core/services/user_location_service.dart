import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Ubicación aproximada del usuario, cacheada en memoria durante toda la
/// sesión. Se pide una sola vez cuando alguien la observa; si el usuario
/// rechaza el permiso el provider devuelve null y todo lo dependiente
/// (ordenamiento por cercanía, distancia en la card) simplemente no aparece.
///
/// Usamos precisión `low` porque solo la necesitamos para ordenar prestadores
/// y esa precisión ahorra batería + funciona en más navegadores/dispositivos
/// que `high`.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 8),
    );
  } catch (_) {
    return null;
  }
});
