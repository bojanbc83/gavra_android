import 'dart:math';
import 'statistika_helpers.dart';

/// Sum valid distances (in km) from an ordered list of GPS points.
/// Each point is a Map containing numeric `lat` and `lng`.
double sumValidDistances(List<Map<String, dynamic>> lokacije,
    {double maksimalnaDistancaPoSegmentu = 5.0}) {
  if (lokacije.length < 2) return 0.0;
  double ukupno = 0.0;
  for (int i = 1; i < lokacije.length; i++) {
    final prev = lokacije[i - 1];
    final cur = lokacije[i];
    if (prev['lat'] == null ||
        prev['lng'] == null ||
        cur['lat'] == null ||
        cur['lng'] == null) continue;
    double lat1, lng1, lat2, lng2;
    try {
      lat1 = (prev['lat'] as num).toDouble();
      lng1 = (prev['lng'] as num).toDouble();
      lat2 = (cur['lat'] as num).toDouble();
      lng2 = (cur['lng'] as num).toDouble();
    } catch (e) {
      continue;
    }
    final dist = distanceKm(lat1, lng1, lat2, lng2);
    if (dist <= maksimalnaDistancaPoSegmentu && dist > 0.001) {
      ukupno += dist;
    }
  }
  return ukupno;
}
