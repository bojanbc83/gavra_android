import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/statistika_helpers.dart';

void main() {
  test('distanceKm between two known points approx', () {
    // Coordinates: Belgrade center and Novi Sad center (~70 km)
    final belgradeLat = 44.8167;
    final belgradeLon = 20.4667;
    final nsLat = 45.2671;
    final nsLon = 19.8335;

    final km = distanceKm(belgradeLat, belgradeLon, nsLat, nsLon);
    // Accept a broad range around 70km
    expect(km, greaterThan(60));
    expect(km, lessThan(90));
  });
}
