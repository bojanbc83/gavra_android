import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path/path.dart' as path;

import '../firebase_options.dart';

/// 🔥 GAVRA 013 - FIREBASE DATA IMPORTER
///
/// Importuje transformisane podatke u Firebase Firestore
/// Pokreće se sa: dart run lib/scripts/firebase_importer.dart

class FirebaseImporter {
  /// 📁 Pronađi transformisane podatke
  static Future<Directory> findTransformedData() async {
    final backupRoot = Directory('backup');
    if (!await backupRoot.exists()) {
      throw Exception('Backup direktorij ne postoji!');
    }

    // Pronađi najnoviji backup sa firebase_ready podacima
    final backupDirs = await backupRoot
        .list()
        .where((entity) => entity is Directory)
        .map((entity) => entity as Directory)
        .toList();

    for (final backupDir in backupDirs.reversed) {
      final firebaseDir =
          Directory(path.join(backupDir.path, 'firebase_ready'));
      if (await firebaseDir.exists()) {
        print('📁 Koristim transformisane podatke: ${firebaseDir.path}');
        return firebaseDir;
      }
    }

    throw Exception(
        'Nema transformisanih podataka! Pokreni data_transformer.dart prvo.');
  }

  /// 📄 Učitaj transformisane podatke za kolekciju
  static Future<List<Map<String, dynamic>>> loadTransformedCollection(
    Directory dataDir,
    String collectionName,
  ) async {
    final file = File(path.join(dataDir.path, '$collectionName.json'));
    if (!await file.exists()) {
      print('⚠️ Preskačem $collectionName - fajl ne postoji');
      return [];
    }

    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    final records = data['data'] as List<dynamic>;

    return records.cast<Map<String, dynamic>>();
  }

  /// 📤 Import kolekcije u Firestore (batch)
  static Future<void> importCollection(
      String collectionName, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) {
      print('⚠️ Preskačem $collectionName - nema podataka');
      return;
    }

    print('📤 Importujem $collectionName (${records.length} zapisa)...');

    final firestore = FirebaseFirestore.instance;
    const int batchSize = 500; // Firestore limit
    int imported = 0;

    try {
      // Podeli u batch-ove
      for (int i = 0; i < records.length; i += batchSize) {
        final batch = firestore.batch();
        final endIndex =
            (i + batchSize < records.length) ? i + batchSize : records.length;
        final batchRecords = records.sublist(i, endIndex);

        for (final record in batchRecords) {
          final docRef =
              firestore.collection(collectionName).doc(record['id'] as String);
          batch.set(docRef, record);
        }

        await batch.commit();
        imported += batchRecords.length;

        print('  📊 Importovano: $imported/${records.length}');

        // Kratka pauza između batch-ova
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      print('✅ $collectionName uspešno importovan: $imported zapisa');
    } catch (e) {
      print('❌ Greška pri importu $collectionName: $e');
      rethrow;
    }
  }

  /// 🧹 Opciono: Obriši postojeće podatke (OPASNO!)
  static Future<void> clearCollection(String collectionName) async {
    print('🧹 Brišem postojeće podatke iz $collectionName...');

    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection(collectionName);

    // Batch delete u manjim grupama
    const int batchSize = 500;
    bool hasMore = true;

    while (hasMore) {
      final snapshot = await collection.limit(batchSize).get();

      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('  🗑️ Obrisano ${snapshot.docs.length} dokumenata');

      // Kratka pauza
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    print('✅ $collectionName očišćena');
  }

  /// 📊 Validacija importa
  static Future<void> validateImport() async {
    print('\n📊 VALIDACIJA IMPORTA...');

    final firestore = FirebaseFirestore.instance;
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

    int totalDocuments = 0;

    for (final collectionName in collections) {
      try {
        final snapshot =
            await firestore.collection(collectionName).count().get();
        final count = snapshot.count;
        totalDocuments += count ?? 0;
        print('  📋 $collectionName: ${count ?? 0} dokumenata');
      } catch (e) {
        print('  ❌ Greška pri brojanju $collectionName: $e');
      }
    }

    print('\n📊 UKUPNO IMPORTOVANO: $totalDocuments dokumenata');

    // Test query-ja
    try {
      print('\n🔍 TESTIRANJE QUERY-JA...');

      // Test vozaci
      final vozaciSnapshot = await firestore
          .collection('vozaci')
          .where('aktivan', isEqualTo: true)
          .limit(1)
          .get();
      print(
          '  ✅ Vozaci query: ${vozaciSnapshot.docs.length > 0 ? 'OK' : 'Nema aktivnih vozača'}');

      // Test mesecni putnici
      final putniciSnapshot = await firestore
          .collection('mesecni_putnici')
          .where('aktivan', isEqualTo: true)
          .limit(1)
          .get();
      print(
          '  ✅ Mesečni putnici query: ${putniciSnapshot.docs.length > 0 ? 'OK' : 'Nema aktivnih putnika'}');

      // Test search terms
      if (putniciSnapshot.docs.isNotEmpty) {
        final searchTerms = putniciSnapshot.docs.first.data()['search_terms'];
        print('  ✅ Search terms: ${searchTerms is List ? 'OK' : 'Greška'}');
      }
    } catch (e) {
      print('  ❌ Greška pri testiranju query-ja: $e');
    }
  }

  /// 🚀 GLAVNA IMPORT FUNKCIJA
  static Future<void> importAllData({bool clearFirst = false}) async {
    try {
      print('🔥 GAVRA 013 - FIREBASE IMPORT STARTED');
      print('🕐 ${DateTime.now()}');
      print('⚠️ Clear existing data: $clearFirst');
      print('');

      // Inicijalizuj Firebase
      print('🔥 Inicijalizujem Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase inicijalizovan');

      // Pronađi transformisane podatke
      final dataDir = await findTransformedData();

      // Lista kolekcija za import (redosled je bitan zbog referenci)
      final importOrder = [
        'adrese', // Moraju prvo (referencirane od drugih)
        'rute', // Moraju pre vozača
        'vozaci', // Moraju pre putnika
        'vozila', // Nezavisno
        'mesecni_putnici',
        'dnevni_putnici',
        'putovanja_istorija',
        'gps_lokacije', // Poslednje (najveće količine)
      ];

      // Import svake kolekcije
      for (final collectionName in importOrder) {
        try {
          // Opciono obriši postojeće podatke
          if (clearFirst) {
            await clearCollection(collectionName);
          }

          // Učitaj transformisane podatke
          final records =
              await loadTransformedCollection(dataDir, collectionName);

          // Importuj u Firestore
          await importCollection(collectionName, records);
        } catch (e) {
          print('❌ Greška kod $collectionName: $e');
          // Nastavi sa ostalim kolekcijama
        }
      }

      // Validacija
      await validateImport();

      print('\n🎉 FIREBASE IMPORT ZAVRŠEN!');
    } catch (e, stackTrace) {
      print('\n💥 KRITIČNA GREŠKA:');
      print('$e');
      print('\n📍 Stack trace:');
      print('$stackTrace');
      exit(1);
    }
  }
}

/// 🎬 ENTRY POINT
void main(List<String> args) async {
  // Proveri argumente
  final clearFirst = args.contains('--clear') || args.contains('-c');

  if (clearFirst) {
    print('⚠️⚠️⚠️ UPOZORENJE ⚠️⚠️⚠️');
    print('Brisaćeš sve postojeće podatke iz Firebase!');
    print('Da li si siguran? (y/N)');

    final response = stdin.readLineSync();
    if (response?.toLowerCase() != 'y') {
      print('❌ Import otkazan');
      exit(0);
    }
  }

  await FirebaseImporter.importAllData(clearFirst: clearFirst);
}
