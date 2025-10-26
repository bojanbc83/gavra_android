import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

/// 🔥 GAVRA 013 - SUPABASE TO FIREBASE DATA TRANSFORMER
///
/// Transformiše exportovane Supabase podatke u Firebase format
/// Pokreće se sa: dart run lib/scripts/data_transformer.dart

class DataTransformer {
  /// 📁 Pronađi najnoviji backup direktorij
  static Future<Directory> findLatestBackup() async {
    final backupRoot = Directory('backup');
    if (!backupRoot.existsSync()) {
      throw Exception('Backup direktorij ne postoji! Pokreni export prvo.');
    }

    final backupDirs = await backupRoot
        .list()
        .where((entity) => entity is Directory)
        .map((entity) => entity as Directory)
        .toList();

    if (backupDirs.isEmpty) {
      throw Exception('Nema backup direktorija! Pokreni export prvo.');
    }

    // Sortiraj po imenu (timestamp) i uzmi poslednji
    backupDirs.sort((a, b) => b.path.compareTo(a.path));
    final latestBackup = backupDirs.first;

    print('📁 Koristim backup: ${latestBackup.path}');
    return latestBackup;
  }

  /// 🗂️ Učitaj exportovane podatke
  static Future<Map<String, dynamic>> loadExportedData(
      Directory backupDir, String tableName) async {
    final file = File(path.join(backupDir.path, '$tableName.json'));
    if (!file.existsSync()) {
      throw Exception('Fajl $tableName.json ne postoji u backup-u!');
    }

    final content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  }

  /// 🔄 TRANSFORM: PostgreSQL POINT → Firebase GeoPoint
  static GeoPoint? transformPoint(dynamic point) {
    if (point == null) return null;

    // PostgreSQL vraća POINT kao string "(lat,lng)" ili Map
    if (point is String) {
      // Format: "(latitude,longitude)"
      final cleaned = point.replaceAll(RegExp(r'[()]'), '');
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return GeoPoint(lat, lng);
        }
      }
    } else if (point is Map) {
      // Neki drugi format
      final lat = point['lat'] ?? point['latitude'];
      final lng = point['lng'] ?? point['longitude'];
      if (lat != null && lng != null) {
        return GeoPoint((lat as num).toDouble(), (lng as num).toDouble());
      }
    }

    print('⚠️ Nepoznat POINT format: $point');
    return null;
  }

  /// 🕐 TRANSFORM: PostgreSQL timestamp → Firestore Timestamp
  static Timestamp? transformTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    DateTime? dateTime;
    if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp);
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    }

    return dateTime != null ? Timestamp.fromDate(dateTime) : null;
  }

  /// 👤 TRANSFORM: vozaci tabela
  static Map<String, dynamic> transformVozac(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'ime_prezime': supabaseData['ime_prezime'] ?? '',
      'telefon': supabaseData['telefon'] ?? '',
      'email': supabaseData['email'] ?? '',
      'aktivan': supabaseData['aktivan'] ?? false,
      'lokacija': transformPoint(supabaseData['lokacija']),
      'adresa_polaska_id': supabaseData['adresa_polaska_id'],
      'adresa_dolaska_id': supabaseData['adresa_dolaska_id'],
      'ruta_id': supabaseData['ruta_id'],
      'poslednja_aktivnost':
          transformTimestamp(supabaseData['poslednja_aktivnost']),
      'created_at': transformTimestamp(supabaseData['created_at']),
      'updated_at': transformTimestamp(supabaseData['updated_at']),

      // Firebase specifični podaci
      'last_seen': transformTimestamp(supabaseData['poslednja_aktivnost']) ??
          FieldValue.serverTimestamp(),
      'device_token': null, // Dodaće se kada se user prijavi
    };
  }

  /// 👥 TRANSFORM: mesecni_putnici tabela
  static Map<String, dynamic> transformMesecniPutnik(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'vozac_id': supabaseData['vozac_id'],
      'ime_prezime': supabaseData['ime_prezime'] ?? '',
      'telefon': supabaseData['telefon'] ?? '',
      'adresa_polaska_id': supabaseData['adresa_polaska_id'],
      'adresa_dolaska_id': supabaseData['adresa_dolaska_id'],
      'aktivan': supabaseData['aktivan'] ?? true,
      'napomene': supabaseData['napomene'] ?? '',
      'created_at': transformTimestamp(supabaseData['created_at']),
      'updated_at': transformTimestamp(supabaseData['updated_at']),

      // Firebase specifični podaci
      'search_terms':
          _createSearchTerms((supabaseData['ime_prezime'] ?? '') as String),
    };
  }

  /// 🎫 TRANSFORM: dnevni_putnici tabela
  static Map<String, dynamic> transformDnevniPutnik(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'vozac_id': supabaseData['vozac_id'],
      'ime_prezime': supabaseData['ime_prezime'] ?? '',
      'telefon': supabaseData['telefon'] ?? '',
      'adresa_polaska_id': supabaseData['adresa_polaska_id'],
      'adresa_dolaska_id': supabaseData['adresa_dolaska_id'],
      'datum_polaska': transformTimestamp(supabaseData['datum_polaska']),
      'napomene': supabaseData['napomene'] ?? '',
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci
      'search_terms':
          _createSearchTerms((supabaseData['ime_prezime'] ?? '') as String),
      'status': 'active', // Default status
    };
  }

  /// 🛣️ TRANSFORM: putovanja_istorija tabela
  static Map<String, dynamic> transformPutovanjeIstorija(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'vozac_id': supabaseData['vozac_id'],
      'datum': transformTimestamp(supabaseData['datum']),
      'vreme_polaska': transformTimestamp(supabaseData['vreme_polaska']),
      'vreme_dolaska': transformTimestamp(supabaseData['vreme_dolaska']),
      'ruta_id': supabaseData['ruta_id'],
      'broj_putnika': supabaseData['broj_putnika'] ?? 0,
      'zarada': supabaseData['zarada']?.toDouble() ?? 0.0,
      'kilometraza': supabaseData['kilometraza']?.toDouble() ?? 0.0,
      'gorivo_potrosnja': supabaseData['gorivo_potrosnja']?.toDouble() ?? 0.0,
      'napomene': supabaseData['napomene'] ?? '',
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci
      'month_year': _getMonthYear(supabaseData['datum']),
    };
  }

  /// 📍 TRANSFORM: adrese tabela
  static Map<String, dynamic> transformAdresa(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'naziv': supabaseData['naziv'] ?? '',
      'koordinate': transformPoint(supabaseData['koordinate']),
      'tip': supabaseData['tip'] ?? 'standard',
      'aktivan': supabaseData['aktivan'] ?? true,
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci za search
      'search_terms':
          _createSearchTerms((supabaseData['naziv'] ?? '') as String),
    };
  }

  /// 🚗 TRANSFORM: vozila tabela
  static Map<String, dynamic> transformVozilo(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'registracija': supabaseData['registracija'] ?? '',
      'marka': supabaseData['marka'] ?? '',
      'model': supabaseData['model'] ?? '',
      'godina_proizvodnje': supabaseData['godina_proizvodnje'],
      'broj_sedista': supabaseData['broj_sedista'] ?? 0,
      'vlasnik_id': supabaseData['vlasnik_id'],
      'aktivan': supabaseData['aktivan'] ?? true,
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci
      'search_terms': _createSearchTerms(
          '${supabaseData['registracija'] ?? ''} ${supabaseData['marka'] ?? ''} ${supabaseData['model'] ?? ''}'),
    };
  }

  /// 📍 TRANSFORM: gps_lokacije tabela
  static Map<String, dynamic> transformGpsLokacija(
      Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'vozac_id': supabaseData['vozac_id'],
      'lokacija': transformPoint(supabaseData['lokacija']),
      'brzina': supabaseData['brzina']?.toDouble() ?? 0.0,
      'smer': supabaseData['smer']?.toDouble() ?? 0.0,
      'preciznost': supabaseData['preciznost']?.toDouble() ?? 0.0,
      'timestamp': transformTimestamp(supabaseData['timestamp']),
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci
      'date': _getDateString(supabaseData['timestamp']),
    };
  }

  /// 🗺️ TRANSFORM: rute tabela
  static Map<String, dynamic> transformRuta(Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'naziv': supabaseData['naziv'] ?? '',
      'adresa_polaska_id': supabaseData['adresa_polaska_id'],
      'adresa_dolaska_id': supabaseData['adresa_dolaska_id'],
      'waypoints': supabaseData['waypoints'], // JSON array ostaje isti
      'udaljenost': supabaseData['udaljenost']?.toDouble() ?? 0.0,
      'estimirano_vreme': supabaseData['estimirano_vreme'] ?? 0,
      'aktivan': supabaseData['aktivan'] ?? true,
      'created_at': transformTimestamp(supabaseData['created_at']),

      // Firebase specifični podaci
      'search_terms':
          _createSearchTerms((supabaseData['naziv'] ?? '') as String),
    };
  }

  /// 🔍 Helper: Kreira search terms za Firebase search
  static List<String> _createSearchTerms(String text) {
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

  /// 📅 Helper: Izdvoji YYYY-MM iz timestamp-a
  static String _getMonthYear(dynamic timestamp) {
    final dt = timestamp is String
        ? DateTime.tryParse(timestamp)
        : timestamp as DateTime?;
    if (dt == null) return DateTime.now().toIso8601String().substring(0, 7);
    return dt.toIso8601String().substring(0, 7); // YYYY-MM
  }

  /// 📅 Helper: Izdvoji YYYY-MM-DD iz timestamp-a
  static String _getDateString(dynamic timestamp) {
    final dt = timestamp is String
        ? DateTime.tryParse(timestamp)
        : timestamp as DateTime?;
    if (dt == null) return DateTime.now().toIso8601String().substring(0, 10);
    return dt.toIso8601String().substring(0, 10); // YYYY-MM-DD
  }

  /// 🔄 GLAVNA TRANSFORM FUNKCIJA
  static Future<void> transformAllData() async {
    try {
      print('🔄 GAVRA 013 - DATA TRANSFORMATION STARTED');
      print('🕐 ${DateTime.now()}');
      print('');

      // Pronađi najnoviji backup
      final backupDir = await findLatestBackup();

      // Kreiraj transformed direktorij
      final transformedDir =
          Directory(path.join(backupDir.path, 'firebase_ready'));
      await transformedDir.create();
      print('📁 Firebase direktorij kreiran: ${transformedDir.path}');

      // Transform mapping
      final transformMap = {
        'vozaci': transformVozac,
        'mesecni_putnici': transformMesecniPutnik,
        'dnevni_putnici': transformDnevniPutnik,
        'putovanja_istorija': transformPutovanjeIstorija,
        'adrese': transformAdresa,
        'vozila': transformVozilo,
        'gps_lokacije': transformGpsLokacija,
        'rute': transformRuta,
      };

      // Transformiši svaku tabelu
      for (final entry in transformMap.entries) {
        final tableName = entry.key;
        final transformFunction = entry.value;

        print('🔄 Transformišem $tableName...');

        try {
          // Učitaj originalne podatke
          final exportData = await loadExportedData(backupDir, tableName);
          final originalRecords = exportData['data'] as List<dynamic>;

          // Transformiši sve zapise
          final transformedRecords = <Map<String, dynamic>>[];
          for (final record in originalRecords) {
            try {
              final transformed =
                  transformFunction(record as Map<String, dynamic>);
              transformedRecords.add(transformed);
            } catch (e) {
              print('  ⚠️ Greška u zapisu ${record['id']}: $e');
            }
          }

          // Sačuvaj transformisane podatke
          final outputFile =
              File(path.join(transformedDir.path, '$tableName.json'));
          await outputFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'collection': tableName,
              'transformed_at': DateTime.now().toIso8601String(),
              'original_count': originalRecords.length,
              'transformed_count': transformedRecords.length,
              'data': transformedRecords,
            }),
          );

          print(
              '✅ $tableName: ${transformedRecords.length}/${originalRecords.length} zapisa');
        } catch (e) {
          print('❌ Greška kod $tableName: $e');
        }
      }

      print('\n🎉 TRANSFORMACIJA ZAVRŠENA!');
      print('📁 Firebase podatci: ${transformedDir.path}');
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
void main() async {
  await DataTransformer.transformAllData();
}
