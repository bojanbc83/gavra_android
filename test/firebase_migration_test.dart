import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/adresa.dart';
import '../lib/models/dnevni_putnik.dart';
import '../lib/models/mesecni_putnik.dart';
import '../lib/models/vozac.dart';
import '../lib/models/vozilo.dart';

/// 🧪 GAVRA 013 - FIREBASE MIGRATION TESTS
///
/// Unit testovi za validaciju migracije podataka
/// Pokreće se sa: flutter test test/firebase_migration_test.dart

void main() {
  group('🔥 Firebase Migration Tests', () {
    setUpAll(() async {
      // Note: Za testiranje trebaju Firebase emulatori
      // flutter pub global activate flutterfire_cli
      // firebase emulators:start --only firestore
    });

    group('📊 Model Validation Tests', () {
      test('MesecniPutnik Firebase serialization', () {
        final putnik = MesecniPutnik(
          id: 'test_123',
          vozacId: 'vozac_456',
          imePrezime: 'Marko Petrović',
          telefon: '+381641234567',
          adresaPolaroId: 'adresa_1',
          adresaDolaskaId: 'adresa_2',
          napomene: 'Test napomena',
          createdAt: DateTime.now(),
        );

        // Test toMap (Firebase format)
        final firebaseMap = putnik.toMap();

        expect(firebaseMap['id'], equals('test_123'));
        expect(firebaseMap['vozac_id'], equals('vozac_456'));
        expect(firebaseMap['ime_prezime'], equals('Marko Petrović'));
        expect(firebaseMap['aktivan'], equals(true));
        expect(firebaseMap['created_at'], isA<DateTime>());

        // Test fromMap (Firebase deserialization)
        final reconstructed = MesecniPutnik.fromMap(firebaseMap);

        expect(reconstructed.id, equals(putnik.id));
        expect(reconstructed.vozacId, equals(putnik.vozacId));
        expect(reconstructed.imePrezime, equals(putnik.imePrezime));
        expect(reconstructed.aktivan, equals(putnik.aktivan));
      });

      test('DnevniPutnik Firebase serialization', () {
        final putnik = DnevniPutnik(
          id: 'dnevni_123',
          vozacId: 'vozac_456',
          imePrezime: 'Ana Jovanović',
          telefon: '+381651234567',
          adresaPolaroId: 'adresa_1',
          adresaDolaskaId: 'adresa_2',
          datumPolaska: DateTime.now(),
          napomene: 'Dnevni putnik test',
          createdAt: DateTime.now(),
        );

        final firebaseMap = putnik.toMap();

        expect(firebaseMap['id'], equals('dnevni_123'));
        expect(firebaseMap['vozac_id'], equals('vozac_456'));
        expect(firebaseMap['datum_polaska'], isA<DateTime>());

        final reconstructed = DnevniPutnik.fromMap(firebaseMap);
        expect(reconstructed.id, equals(putnik.id));
        expect(reconstructed.imePrezime, equals(putnik.imePrezime));
      });

      test('Vozac Firebase serialization', () {
        final vozac = Vozac(
          id: 'vozac_123',
          imePrezime: 'Miloš Nikolić',
          telefon: '+381641234567',
          email: 'milos@example.com',
          lokacija: null, // Test null GeoPoint
          adresaPolaroId: 'adresa_1',
          adresaDolaskaId: 'adresa_2',
          rutaId: 'ruta_1',
          poslednjaAkti: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final firebaseMap = vozac.toMap();

        expect(firebaseMap['id'], equals('vozac_123'));
        expect(firebaseMap['ime_prezime'], equals('Miloš Nikolić'));
        expect(firebaseMap['email'], equals('milos@example.com'));
        expect(firebaseMap['lokacija'], isNull);
        expect(firebaseMap['aktivan'], equals(true));

        final reconstructed = Vozac.fromMap(firebaseMap);
        expect(reconstructed.id, equals(vozac.id));
        expect(reconstructed.email, equals(vozac.email));
      });

      test('Adresa Firebase serialization with GeoPoint', () {
        final adresa = Adresa(
          id: 'adresa_123',
          naziv: 'Trg Republike',
          koordinate: const GeoPoint(44.8176, 20.4633), // Belgrade coordinates
          tip: 'glavna',
          aktivan: true,
          createdAt: DateTime.now(),
        );

        final firebaseMap = adresa.toMap();

        expect(firebaseMap['id'], equals('adresa_123'));
        expect(firebaseMap['naziv'], equals('Trg Republike'));
        expect(firebaseMap['koordinate'], isA<GeoPoint>());
        expect(firebaseMap['tip'], equals('glavna'));

        final reconstructed = Adresa.fromMap(firebaseMap);
        expect(reconstructed.id, equals(adresa.id));
        expect(reconstructed.koordinate, isNotNull);
        expect(reconstructed.koordinate!.latitude, closeTo(44.8176, 0.0001));
        expect(reconstructed.koordinate!.longitude, closeTo(20.4633, 0.0001));
      });

      test('Vozilo Firebase serialization', () {
        final vozilo = Vozilo(
          id: 'vozilo_123',
          registracija: 'BG-1234-AB',
          marka: 'Mercedes',
          model: 'Sprinter',
          godinaProizvodnje: 2020,
          brojSedista: 19,
          vlasnikId: 'vozac_456',
          createdAt: DateTime.now(),
        );

        final firebaseMap = vozilo.toMap();

        expect(firebaseMap['id'], equals('vozilo_123'));
        expect(firebaseMap['registracija'], equals('BG-1234-AB'));
        expect(firebaseMap['marka'], equals('Mercedes'));
        expect(firebaseMap['broj_sedista'], equals(19));
        expect(firebaseMap['godina_proizvodnje'], equals(2020));

        final reconstructed = Vozilo.fromMap(firebaseMap);
        expect(reconstructed.id, equals(vozilo.id));
        expect(reconstructed.brojSedista, equals(vozilo.brojSedista));
      });
    });

    group('🔍 Search Terms Tests', () {
      test('Search terms generation', () {
        // Simulira search terms generiranje iz transform skripte
        final searchTerms = _createSearchTerms('Marko Petrović');

        expect(searchTerms, contains('marko'));
        expect(searchTerms, contains('petrović'));
        expect(searchTerms, contains('ma'));
        expect(searchTerms, contains('mar'));
        expect(searchTerms, contains('mark'));
        expect(searchTerms, contains('pe'));
        expect(searchTerms, contains('pet'));
        expect(searchTerms, contains('petr'));

        expect(searchTerms.length, greaterThan(5)); // Najmanje nekoliko terme
      });

      test('Empty search terms', () {
        final searchTerms = _createSearchTerms('');
        expect(searchTerms, isEmpty);

        final shortTerms = _createSearchTerms('A');
        expect(shortTerms, isEmpty); // Kratka slova se preskačeju
      });
    });

    group('🗄️ Data Structure Tests', () {
      test('Firebase timestamp conversion', () {
        final now = DateTime.now();
        final timestamp = Timestamp.fromDate(now);

        expect(timestamp, isA<Timestamp>());

        final convertedBack = timestamp.toDate();
        expect(
          convertedBack.millisecondsSinceEpoch,
          closeTo(now.millisecondsSinceEpoch, 1000),
        ); // 1s tolerance
      });

      test('GeoPoint validation', () {
        // Belgrade coordinates
        const belgrade = GeoPoint(44.8176, 20.4633);

        expect(belgrade.latitude, closeTo(44.8176, 0.0001));
        expect(belgrade.longitude, closeTo(20.4633, 0.0001));

        // Invalid coordinates should not crash
        const invalid = GeoPoint(200, 200); // Invalid but allowed
        expect(invalid.latitude, equals(200));
        expect(invalid.longitude, equals(200));
      });
    });

    group('🔗 Reference Validation', () {
      test('Document ID format', () {
        // Firebase document IDs moraju biti validni
        final validIds = [
          'vozac_123',
          'putnik-456',
          'UUID_1234567890',
          'test.doc.id',
        ];

        for (final id in validIds) {
          expect(id.length, lessThan(1500)); // Firebase limit
          expect(id, isNot(contains('/'))); // Slash not allowed
        }
      });

      test('Collection names validation', () {
        final collections = [
          'vozaci',
          'mesecni_putnici',
          'dnevni_putnici',
          'putovanja_istorija',
          'adrese',
          'vozila',
          'gps_lokacije',
          'rute',
        ];

        for (final name in collections) {
          expect(name.length, lessThan(100)); // Reasonable length
          expect(name, isNot(startsWith('_'))); // No underscore start
          expect(name, matches(RegExp(r'^[a-z][a-z0-9_]*$'))); // Valid pattern
        }
      });
    });

    group('📊 Performance Tests', () {
      test('Batch size limits', () {
        const int FIRESTORE_BATCH_LIMIT = 500;

        // Simulate large dataset
        final largeDataset = List.generate(1200, (i) => 'doc_$i');

        final batches = <List<String>>[];
        for (int i = 0; i < largeDataset.length; i += FIRESTORE_BATCH_LIMIT) {
          final end =
              (i + FIRESTORE_BATCH_LIMIT < largeDataset.length) ? i + FIRESTORE_BATCH_LIMIT : largeDataset.length;
          batches.add(largeDataset.sublist(i, end));
        }

        expect(batches.length, equals(3)); // 500 + 500 + 200
        expect(batches[0].length, equals(500));
        expect(batches[1].length, equals(500));
        expect(batches[2].length, equals(200));
      });
    });
  });
}

/// Helper function (duplicated from transform script)
List<String> _createSearchTerms(String text) {
  if (text.isEmpty) return [];

  final terms = <String>{};
  final words = text.toLowerCase().split(RegExp(r'\s+'));

  for (final word in words) {
    if (word.length >= 2) {
      // Dodaj celu reč
      terms.add(word);

      // Dodaj prefixe (za autocomplete)
      for (int i = 2; i <= word.length; i++) {
        terms.add(word.substring(0, i));
      }
    }
  }

  return terms.toList();
}
