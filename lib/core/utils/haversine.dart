import 'dart:math' as math;

/// Distancia en km entre dos puntos usando la fórmula de Haversine.
/// Es ~99.7% precisa a distancias de hasta 1000 km — más que suficiente
/// para RD.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0088;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double d) => d * math.pi / 180;

/// Formato amigable de una distancia en km.
///   0.7 → "700 m"
///   4.2 → "4.2 km"
///  25.0 → "25 km"
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
