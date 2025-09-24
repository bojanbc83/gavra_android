import 'dart:math';

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  // copy of Haversine used in StatistikaService
  const double R = 6371; // Earth radius in km
  double dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
  double dLon = (lon2 - lon1) * 3.141592653589793 / 180.0;
  double a = 0.5 -
      cos(dLat) / 2 +
      cos(lat1 * 3.141592653589793 / 180.0) *
          cos(lat2 * 3.141592653589793 / 180.0) *
          (1 - cos(dLon)) /
          2;
  return R * 2 * asin(sqrt(a));
}
