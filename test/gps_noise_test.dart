import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/kilometraza_utils.dart';

void main() {
  test('sumValidDistances filters spikes', () {
    // Create synthetic points: small moves ~0.1km, then a spike ~500km, then normal again
    final points = [
      {'lat': 44.8, 'lng': 20.4},
      {'lat': 44.8005, 'lng': 20.401},
      {'lat': 50.0, 'lng': 10.0}, // spike
      {'lat': 44.801, 'lng': 20.402},
      {'lat': 44.802, 'lng': 20.403},
    ];

    final km = sumValidDistances(points, maksimalnaDistancaPoSegmentu: 5.0);
    // Spike should be filtered, so km should be small (< 10 km)
    expect(km, lessThan(10));
  });
}
