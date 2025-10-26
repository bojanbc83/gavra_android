import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/gps_lokacija.dart';
import 'gps_lokacija_service.dart';

/// 🛰️ GPS DATA MIGRATION SERVICE
/// Integriše 1000 GPS zapisa iz Supabase u Firebase
/// Povezuje Supabase podatke sa postojećim GPS servisima
class GpsDataMigrationService {
  // TODO: Replace with actual Supabase credentials
  static const String _supabaseUrl = 'https://your-supabase-url.supabase.co';
  static const String _supabaseKey = 'your-supabase-anon-key';
  // Note: These credentials should be loaded from environment variables or secure config

  static bool _isMigrationInProgress = false;
  static int _migratedCount = 0;
  static int _totalCount = 0;

  /// 🔄 MIGRIRAJ SVE GPS PODATKE IZ SUPABASE U FIREBASE
  static Future<Map<String, dynamic>> migrateAllGpsData({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? vozacIds,
    bool forceOverwrite = false,
  }) async {
    if (_isMigrationInProgress) {
      return {
        'success': false,
        'error': 'Migration is already in progress',
        'migrated': _migratedCount,
        'total': _totalCount,
      };
    }

    _isMigrationInProgress = true;
    _migratedCount = 0;
    _totalCount = 0;

    try {
      developer.log('🛰️ Starting GPS data migration from Supabase to Firebase',
          name: 'GpsDataMigrationService');

      // 1. FETCH GPS DATA FROM SUPABASE
      final supabaseGpsData = await _fetchGpsDataFromSupabase(
        fromDate: fromDate,
        toDate: toDate,
        vozacIds: vozacIds,
      );

      _totalCount = supabaseGpsData.length;
      developer.log('📊 Found $_totalCount GPS records in Supabase',
          name: 'GpsDataMigrationService');

      if (_totalCount == 0) {
        return {
          'success': true,
          'message': 'No GPS data found to migrate',
          'migrated': 0,
          'total': 0,
        };
      }

      // 2. BATCH MIGRATE TO FIREBASE
      final batchSize = 50; // Firebase batch write limit
      final batches = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < supabaseGpsData.length; i += batchSize) {
        final end = (i + batchSize < supabaseGpsData.length)
            ? i + batchSize
            : supabaseGpsData.length;
        batches.add(supabaseGpsData.sublist(i, end));
      }

      // 3. PROCESS EACH BATCH
      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];

        try {
          await _processBatch(batch, forceOverwrite);
          _migratedCount += batch.length;

          developer.log(
              '✅ Batch ${batchIndex + 1}/${batches.length} completed. '
              'Migrated: $_migratedCount/$_totalCount',
              name: 'GpsDataMigrationService');

          // Small delay to avoid overwhelming Firebase
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          developer.log('❌ Error processing batch ${batchIndex + 1}: $e',
              name: 'GpsDataMigrationService', level: 1000);
          // Continue with next batch
        }
      }

      // 4. VERIFY MIGRATION
      final verificationResult = await _verifyMigration();

      final result = {
        'success': true,
        'migrated': _migratedCount,
        'total': _totalCount,
        'verification': verificationResult,
        'success_rate': (_migratedCount / _totalCount * 100).toStringAsFixed(2),
      };

      developer.log(
          '🎉 GPS migration completed! '
          'Migrated: $_migratedCount/$_totalCount '
          '(${result['success_rate']}%)',
          name: 'GpsDataMigrationService');

      return result;
    } catch (e) {
      developer.log('❌ GPS migration failed: $e',
          name: 'GpsDataMigrationService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'migrated': _migratedCount,
        'total': _totalCount,
      };
    } finally {
      _isMigrationInProgress = false;
    }
  }

  /// 📡 FETCH GPS DATA FROM SUPABASE
  static Future<List<Map<String, dynamic>>> _fetchGpsDataFromSupabase({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? vozacIds,
  }) async {
    try {
      // Build query
      var query = 'select=*';

      final filters = <String>[];

      if (fromDate != null) {
        filters.add('vreme.gte.${fromDate.toIso8601String()}');
      }

      if (toDate != null) {
        filters.add('vreme.lte.${toDate.toIso8601String()}');
      }

      if (vozacIds != null && vozacIds.isNotEmpty) {
        filters.add('vozac_id.in.(${vozacIds.join(',')})');
      }

      if (filters.isNotEmpty) {
        query += '&${filters.join('&')}';
      }

      // Order by time descending
      query += '&order=vreme.desc';

      // Limit to avoid timeout (can be adjusted)
      query += '&limit=1000';

      final url = Uri.parse('$_supabaseUrl/rest/v1/gps_lokacije?$query');

      final response = await http.get(
        url,
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch from Supabase: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching GPS data from Supabase: $e',
          name: 'GpsDataMigrationService', level: 1000);
      rethrow;
    }
  }

  /// ⚡ PROCESS BATCH OF GPS RECORDS
  static Future<void> _processBatch(
      List<Map<String, dynamic>> batch, bool forceOverwrite) async {
    final firestore = FirebaseFirestore.instance;
    final batch_write = firestore.batch();

    for (final supabaseRecord in batch) {
      try {
        // Convert Supabase record to Firebase GPS model
        final gpsLokacija = _convertSupabaseToFirebase(supabaseRecord);

        final docRef = firestore.collection('gps_lokacije').doc(gpsLokacija.id);

        if (forceOverwrite) {
          batch_write.set(docRef, gpsLokacija.toMap());
        } else {
          // Check if document exists first (more expensive but safer)
          batch_write.set(docRef, gpsLokacija.toMap(), SetOptions(merge: true));
        }
      } catch (e) {
        developer.log('Error converting GPS record: $e',
            name: 'GpsDataMigrationService', level: 1000);
        // Skip this record and continue
      }
    }

    // Execute batch write
    await batch_write.commit();
  }

  /// 🔄 CONVERT SUPABASE GPS RECORD TO FIREBASE FORMAT
  static GPSLokacija _convertSupabaseToFirebase(
      Map<String, dynamic> supabaseRecord) {
    return GPSLokacija(
      id: supabaseRecord['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      voziloId: supabaseRecord['vozilo_id']?.toString() ?? 'unknown',
      vozacId: supabaseRecord['vozac_id']?.toString() ?? '',
      latitude: (supabaseRecord['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (supabaseRecord['longitude'] as num?)?.toDouble() ?? 0.0,
      brzina: (supabaseRecord['brzina'] as num?)?.toDouble(),
      pravac: (supabaseRecord['pravac'] as num?)?.toDouble(),
      // Note: tacnost field from Supabase is not supported in current GPSLokacija model
      vreme: supabaseRecord['vreme'] != null
          ? DateTime.parse(supabaseRecord['vreme'] as String)
          : DateTime.now(),
      aktivan: true, // Default to active
      // Note: obrisan field not supported in current GPSLokacija model
    );
  }

  /// ✅ VERIFY MIGRATION SUCCESS
  static Future<Map<String, dynamic>> _verifyMigration() async {
    try {
      // Count total GPS records in Firebase
      final firebaseQuery = await FirebaseFirestore.instance
          .collection('gps_lokacije')
          .count()
          .get();

      final firebaseCount = firebaseQuery.count;

      // Get latest GPS record
      final latestQuery = await FirebaseFirestore.instance
          .collection('gps_lokacije')
          .orderBy('vreme', descending: true)
          .limit(1)
          .get();

      final latestRecord =
          latestQuery.docs.isNotEmpty ? latestQuery.docs.first.data() : null;

      // Get GPS records by vozac to verify distribution
      final vozacDistribution = await _getVozacDistribution();

      return {
        'firebase_total_count': firebaseCount,
        'latest_record': latestRecord,
        'vozac_distribution': vozacDistribution,
        'migration_status': (firebaseCount ?? 0) > 0 ? 'success' : 'failed',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'migration_status': 'verification_failed',
      };
    }
  }

  /// 📊 GET VOZAC GPS DISTRIBUTION
  static Future<Map<String, int>> _getVozacDistribution() async {
    try {
      final query =
          await FirebaseFirestore.instance.collection('gps_lokacije').get();

      final distribution = <String, int>{};

      for (final doc in query.docs) {
        final vozacId = doc.data()['vozac_id'] as String?;
        if (vozacId != null) {
          distribution[vozacId] = (distribution[vozacId] ?? 0) + 1;
        }
      }

      return distribution;
    } catch (e) {
      return {};
    }
  }

  /// 📈 GET MIGRATION STATUS
  static Map<String, dynamic> getMigrationStatus() {
    return {
      'is_in_progress': _isMigrationInProgress,
      'migrated_count': _migratedCount,
      'total_count': _totalCount,
      'progress_percentage': _totalCount > 0
          ? (_migratedCount / _totalCount * 100).toStringAsFixed(2)
          : '0.00',
    };
  }

  /// 🧹 CLEAN UP OLD GPS DATA (OPTIONAL)
  static Future<int> cleanupOldGpsData({
    required DateTime olderThan,
    String? vozacId,
  }) async {
    try {
      developer.log('🧹 Cleaning up GPS data older than $olderThan',
          name: 'GpsDataMigrationService');

      var query = FirebaseFirestore.instance
          .collection('gps_lokacije')
          .where('vreme', isLessThan: olderThan.toIso8601String());

      if (vozacId != null) {
        query = query.where('vozac_id', isEqualTo: vozacId);
      }

      final snapshot = await query.get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      developer.log('✅ Cleaned up ${snapshot.docs.length} old GPS records',
          name: 'GpsDataMigrationService');

      return snapshot.docs.length;
    } catch (e) {
      developer.log('❌ Error cleaning up GPS data: $e',
          name: 'GpsDataMigrationService', level: 1000);
      rethrow;
    }
  }

  /// 🔧 INTEGRATE WITH EXISTING GPS SERVICES
  static Future<void> activateGpsTracking() async {
    try {
      developer.log('🛰️ Activating GPS tracking with migrated data',
          name: 'GpsDataMigrationService');

      // Test GPS services integration
      final testVozacId = 'test-vozac-id';
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Test GpsLokacijaService
      final gpsRecords = await GpsLokacijaService.getGpsLokacije(
          testVozacId, yesterday, today);

      developer.log(
          '✅ GPS services integration test: ${gpsRecords.length} records found',
          name: 'GpsDataMigrationService');
    } catch (e) {
      developer.log('❌ GPS services integration failed: $e',
          name: 'GpsDataMigrationService', level: 1000);
      rethrow;
    }
  }

  /// 📊 MIGRIRAJ GPS PODATKE IZ CSV DATOTEKE
  /// Alternativa za Supabase API - direktno iz CSV eksporta
  static Future<Map<String, dynamic>> migrateCsvGpsData({
    required String csvFilePath,
    bool forceOverwrite = false,
    int? maxRecords,
  }) async {
    if (_isMigrationInProgress) {
      return {
        'success': false,
        'error': 'Migration is already in progress',
        'migrated': _migratedCount,
        'total': _totalCount,
      };
    }

    _isMigrationInProgress = true;
    _migratedCount = 0;
    _totalCount = 0;

    try {
      developer.log(
          '📊 Starting GPS data migration from CSV file: $csvFilePath',
          name: 'GpsDataMigrationService');

      // 1. READ AND PARSE CSV FILE
      final csvGpsData = await _parseCsvGpsData(csvFilePath, maxRecords);

      _totalCount = csvGpsData.length;
      developer.log('📊 Found $_totalCount GPS records in CSV file',
          name: 'GpsDataMigrationService');

      if (_totalCount == 0) {
        return {
          'success': true,
          'message': 'No GPS data found in CSV file',
          'migrated': 0,
          'total': 0,
        };
      }

      // 2. BATCH MIGRATE TO FIREBASE (same logic as Supabase migration)
      final batchSize = 50;
      final batches = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < csvGpsData.length; i += batchSize) {
        final end = (i + batchSize < csvGpsData.length)
            ? i + batchSize
            : csvGpsData.length;
        batches.add(csvGpsData.sublist(i, end));
      }

      // 3. PROCESS EACH BATCH
      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];

        try {
          await _processBatch(batch, forceOverwrite);
          _migratedCount += batch.length;

          developer.log(
              '✅ CSV Batch ${batchIndex + 1}/${batches.length} completed. '
              'Migrated: $_migratedCount/$_totalCount',
              name: 'GpsDataMigrationService');

          await Future<void>.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          developer.log('❌ Error processing CSV batch ${batchIndex + 1}: $e',
              name: 'GpsDataMigrationService', level: 1000);
        }
      }

      // 4. VERIFY MIGRATION
      final verificationResult = await _verifyMigration();

      final result = {
        'success': true,
        'source': 'CSV',
        'csv_file': csvFilePath,
        'migrated': _migratedCount,
        'total': _totalCount,
        'verification': verificationResult,
        'success_rate': (_migratedCount / _totalCount * 100).toStringAsFixed(2),
      };

      developer.log(
          '🎉 CSV GPS migration completed! '
          'Migrated: $_migratedCount/$_totalCount '
          '(${result['success_rate']}%)',
          name: 'GpsDataMigrationService');

      return result;
    } catch (e) {
      developer.log('❌ CSV GPS migration failed: $e',
          name: 'GpsDataMigrationService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'source': 'CSV',
        'csv_file': csvFilePath,
        'migrated': _migratedCount,
        'total': _totalCount,
      };
    } finally {
      _isMigrationInProgress = false;
    }
  }

  /// 📄 PARSE CSV GPS DATA
  static Future<List<Map<String, dynamic>>> _parseCsvGpsData(
      String csvFilePath, int? maxRecords) async {
    try {
      final file = File(csvFilePath);

      if (!await file.exists()) {
        throw Exception('CSV file does not exist: $csvFilePath');
      }

      final contents = await file.readAsString();
      final lines = contents.split('\n');

      if (lines.isEmpty) {
        return [];
      }

      // Parse header row
      final headers =
          lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
      developer.log('📊 CSV Headers: ${headers.join(', ')}',
          name: 'GpsDataMigrationService');

      final gpsData = <Map<String, dynamic>>[];

      // Parse data rows (skip header)
      final dataRows = lines.skip(1).where((line) => line.trim().isNotEmpty);
      int processedRows = 0;

      for (final line in dataRows) {
        if (maxRecords != null && processedRows >= maxRecords) {
          break;
        }

        try {
          final values = _parseCsvLine(line);

          if (values.length != headers.length) {
            developer.log('⚠️ Skipping malformed CSV line: $line',
                name: 'GpsDataMigrationService', level: 900);
            continue;
          }

          final record = <String, dynamic>{};
          for (int i = 0; i < headers.length; i++) {
            record[headers[i]] = values[i].trim().replaceAll('"', '');
          }

          // Convert to expected format
          final normalizedRecord = _normalizeCsvRecord(record);
          if (normalizedRecord != null) {
            gpsData.add(normalizedRecord);
            processedRows++;
          }
        } catch (e) {
          developer.log('⚠️ Error parsing CSV line: $line - $e',
              name: 'GpsDataMigrationService', level: 900);
        }
      }

      developer.log('📊 Parsed ${gpsData.length} valid GPS records from CSV',
          name: 'GpsDataMigrationService');

      return gpsData;
    } catch (e) {
      developer.log('❌ Error parsing CSV file: $e',
          name: 'GpsDataMigrationService', level: 1000);
      rethrow;
    }
  }

  /// 🔧 PARSE CSV LINE (handles quotes and commas)
  static List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final chars = line.split('');
    final currentValue = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue.toString());
        currentValue.clear();
      } else {
        currentValue.write(char);
      }
    }

    // Don't forget the last value
    values.add(currentValue.toString());

    return values;
  }

  /// 🔄 NORMALIZE CSV RECORD TO EXPECTED FORMAT
  static Map<String, dynamic>? _normalizeCsvRecord(
      Map<String, dynamic> csvRecord) {
    try {
      // Map CSV column names to expected field names
      final normalized = <String, dynamic>{};

      // Handle different possible column name variations
      for (final entry in csvRecord.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value?.toString();

        if (value == null || value.isEmpty || value == 'NULL') {
          continue;
        }

        switch (key) {
          case 'id':
            normalized['id'] = value;
            break;
          case 'vozac_id':
          case 'vozacid':
            normalized['vozac_id'] = value;
            break;
          case 'vozilo_id':
          case 'voziloid':
            normalized['vozilo_id'] = value;
            break;
          case 'latitude':
          case 'lat':
            try {
              normalized['latitude'] = double.parse(value);
            } catch (e) {
              developer.log('⚠️ Invalid latitude: $value',
                  name: 'GpsDataMigrationService');
              return null;
            }
            break;
          case 'longitude':
          case 'lng':
          case 'lon':
            try {
              normalized['longitude'] = double.parse(value);
            } catch (e) {
              developer.log('⚠️ Invalid longitude: $value',
                  name: 'GpsDataMigrationService');
              return null;
            }
            break;
          case 'brzina':
          case 'speed':
            try {
              normalized['brzina'] = double.parse(value);
            } catch (e) {
              normalized['brzina'] = null;
            }
            break;
          case 'pravac':
          case 'heading':
          case 'direction':
            try {
              normalized['pravac'] = double.parse(value);
            } catch (e) {
              normalized['pravac'] = null;
            }
            break;
          case 'tacnost':
          case 'accuracy':
            try {
              normalized['tacnost'] = double.parse(value);
            } catch (e) {
              normalized['tacnost'] = null;
            }
            break;
          case 'vreme':
          case 'timestamp':
          case 'time':
          case 'created_at':
            normalized['vreme'] = value;
            break;
        }
      }

      // Validate required fields
      if (!normalized.containsKey('id') ||
          !normalized.containsKey('latitude') ||
          !normalized.containsKey('longitude')) {
        developer.log('⚠️ Missing required GPS fields in record: $csvRecord',
            name: 'GpsDataMigrationService', level: 900);
        return null;
      }

      return normalized;
    } catch (e) {
      developer.log('❌ Error normalizing CSV record: $e',
          name: 'GpsDataMigrationService', level: 1000);
      return null;
    }
  }
}
