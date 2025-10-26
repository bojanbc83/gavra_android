import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart';

import '../models/gps_lokacija.dart';
import 'background_gps_service.dart';
import 'gps_data_migration_service.dart';
import 'gps_lokacija_service.dart';
import 'realtime_gps_service.dart';

/// 🛰️ UNIFIED GPS SERVICE
/// Integriše sve GPS servise u jedinstven sistem
/// Kombinuje Supabase podatke sa real-time tracking
class UnifiedGpsService {
  static bool _isInitialized = false;
  static bool _isTrackingActive = false;
  static StreamSubscription<Position>? _trackingSubscription;
  static String? _currentVozacId;

  /// 🚀 INITIALIZE UNIFIED GPS SYSTEM
  static Future<Map<String, dynamic>> initialize({
    bool migrateSupabaseData = true,
    bool enableRealTimeTracking = true,
    bool enableBackgroundTracking = false,
  }) async {
    if (_isInitialized) {
      return {
        'success': true,
        'message': 'GPS system already initialized',
        'status': await getSystemStatus(),
      };
    }

    try {
      developer.log('🛰️ Initializing Unified GPS System',
          name: 'UnifiedGpsService');

      final initResults = <String, dynamic>{};

      // 1. MIGRATE SUPABASE DATA (if requested)
      if (migrateSupabaseData) {
        developer.log('📡 Starting Supabase GPS data migration',
            name: 'UnifiedGpsService');

        final migrationResult =
            await GpsDataMigrationService.migrateAllGpsData();
        initResults['migration'] = migrationResult;

        if (migrationResult['success'] == true) {
          developer.log(
              '✅ GPS data migration completed: ${migrationResult['migrated']}/${migrationResult['total']} records',
              name: 'UnifiedGpsService');
        } else {
          developer.log(
              '⚠️ GPS data migration failed: ${migrationResult['error']}',
              name: 'UnifiedGpsService',
              level: 900);
        }
      }

      // 2. INITIALIZE REAL-TIME GPS (if requested)
      if (enableRealTimeTracking) {
        try {
          await RealtimeGpsService.startTracking();
          initResults['realtime_gps'] = {'success': true, 'status': 'active'};
          developer.log('✅ Real-time GPS tracking initialized',
              name: 'UnifiedGpsService');
        } catch (e) {
          initResults['realtime_gps'] = {
            'success': false,
            'error': e.toString()
          };
          developer.log('⚠️ Real-time GPS initialization failed: $e',
              name: 'UnifiedGpsService', level: 900);
        }
      }

      // 3. INITIALIZE BACKGROUND GPS (if requested)
      if (enableBackgroundTracking) {
        try {
          await BackgroundGpsService.initialize();
          initResults['background_gps'] = {
            'success': true,
            'status': 'initialized'
          };
          developer.log('✅ Background GPS service initialized',
              name: 'UnifiedGpsService');
        } catch (e) {
          initResults['background_gps'] = {
            'success': false,
            'error': e.toString()
          };
          developer.log('⚠️ Background GPS initialization failed: $e',
              name: 'UnifiedGpsService', level: 900);
        }
      }

      // 4. VERIFY SYSTEM INTEGRITY
      final verificationResult = await _verifySystemIntegrity();
      initResults['verification'] = verificationResult;

      _isInitialized = true;

      final finalResult = {
        'success': true,
        'message': 'Unified GPS System initialized successfully',
        'components': initResults,
        'system_status': await getSystemStatus(),
      };

      developer.log('🎉 Unified GPS System initialization completed',
          name: 'UnifiedGpsService');

      return finalResult;
    } catch (e) {
      developer.log('❌ Unified GPS System initialization failed: $e',
          name: 'UnifiedGpsService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to initialize GPS system',
      };
    }
  }

  /// 🎯 START GPS TRACKING FOR VOZAC
  static Future<Map<String, dynamic>> startTrackingForVozac(
      String vozacId) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isTrackingActive && _currentVozacId == vozacId) {
      return {
        'success': true,
        'message': 'Tracking already active for this vozac',
        'vozac_id': vozacId,
      };
    }

    try {
      developer.log('🛰️ Starting GPS tracking for vozac: $vozacId',
          name: 'UnifiedGpsService');

      // Stop previous tracking if active
      if (_isTrackingActive) {
        await stopTracking();
      }

      _currentVozacId = vozacId;

      // Start real-time position tracking
      _trackingSubscription = RealtimeGpsService.positionStream.listen(
        (Position position) async {
          try {
            // Save position to Firebase via GpsLokacijaService
            final gpsLokacija = GPSLokacija.sada(
              voziloId: vozacId, // Using vozac as vozilo for compatibility
              vozacId: vozacId,
              latitude: position.latitude,
              longitude: position.longitude,
              brzina: position.speed * 3.6, // Convert m/s to km/h
              pravac: position.heading >= 0 ? position.heading : null,
            );

            await GpsLokacijaService.saveGpsLokacija(gpsLokacija);

            developer.log(
                '📍 GPS position saved: ${position.latitude}, ${position.longitude}',
                name: 'UnifiedGpsService');
          } catch (e) {
            developer.log('❌ Error saving GPS position: $e',
                name: 'UnifiedGpsService', level: 900);
          }
        },
        onError: (Object error) {
          developer.log('❌ GPS tracking stream error: $error',
              name: 'UnifiedGpsService', level: 1000);
        },
      );

      _isTrackingActive = true;

      return {
        'success': true,
        'message': 'GPS tracking started successfully',
        'vozac_id': vozacId,
        'tracking_status': 'active',
      };
    } catch (e) {
      developer.log('❌ Failed to start GPS tracking: $e',
          name: 'UnifiedGpsService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'vozac_id': vozacId,
      };
    }
  }

  /// ⏹️ STOP GPS TRACKING
  static Future<Map<String, dynamic>> stopTracking() async {
    try {
      developer.log('⏹️ Stopping GPS tracking', name: 'UnifiedGpsService');

      await _trackingSubscription?.cancel();
      _trackingSubscription = null;
      _isTrackingActive = false;

      final stoppedVozacId = _currentVozacId;
      _currentVozacId = null;

      return {
        'success': true,
        'message': 'GPS tracking stopped',
        'previous_vozac_id': stoppedVozacId,
      };
    } catch (e) {
      developer.log('❌ Error stopping GPS tracking: $e',
          name: 'UnifiedGpsService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 📊 GET SYSTEM STATUS
  static Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      // Get Firebase GPS count
      final firebaseCount = await _getFirebaseGpsCount();

      // Get latest GPS record
      final latestGps = await _getLatestGpsRecord();

      // Check real-time tracking status
      final realtimeStatus = _isTrackingActive ? 'active' : 'inactive';

      // Check background service status
      final backgroundStatus =
          await BackgroundGpsService.isBackgroundTrackingActive();

      return {
        'initialized': _isInitialized,
        'firebase_gps_count': firebaseCount,
        'latest_gps_record': latestGps,
        'realtime_tracking': {
          'status': realtimeStatus,
          'vozac_id': _currentVozacId,
        },
        'background_tracking': {
          'status': backgroundStatus ? 'active' : 'inactive',
        },
        'migration_status': GpsDataMigrationService.getMigrationStatus(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'initialized': _isInitialized,
      };
    }
  }

  /// 📈 GET GPS STATISTICS FOR VOZAC
  static Future<Map<String, dynamic>> getGpsStatistics(
    String vozacId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      fromDate ??= DateTime.now().subtract(const Duration(days: 7));
      toDate ??= DateTime.now();

      final gpsRecords = await GpsLokacijaService.getGpsLokacije(
        vozacId,
        fromDate,
        toDate,
      );

      if (gpsRecords.isEmpty) {
        return {
          'vozac_id': vozacId,
          'period': {
            'from': fromDate.toIso8601String(),
            'to': toDate.toIso8601String(),
          },
          'total_records': 0,
          'message': 'No GPS data found for this period',
        };
      }

      // Calculate statistics
      final totalDistance = _calculateTotalDistance(gpsRecords);
      final averageSpeed = _calculateAverageSpeed(gpsRecords);
      final maxSpeed = _calculateMaxSpeed(gpsRecords);
      final trackingDuration = _calculateTrackingDuration(gpsRecords);

      return {
        'vozac_id': vozacId,
        'period': {
          'from': fromDate.toIso8601String(),
          'to': toDate.toIso8601String(),
        },
        'total_records': gpsRecords.length,
        'total_distance_km': totalDistance,
        'average_speed_kmh': averageSpeed,
        'max_speed_kmh': maxSpeed,
        'tracking_duration_hours': trackingDuration,
        'first_record': gpsRecords.last.vreme.toIso8601String(),
        'last_record': gpsRecords.first.vreme.toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'vozac_id': vozacId,
      };
    }
  }

  /// 🗺️ GET GPS ROUTE FOR VOZAC
  static Future<List<Map<String, dynamic>>> getGpsRoute(
    String vozacId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    try {
      fromDate ??= DateTime.now().subtract(const Duration(hours: 24));
      toDate ??= DateTime.now();

      final gpsRecords = await GpsLokacijaService.getGpsLokacije(
        vozacId,
        fromDate,
        toDate,
      );

      // Apply limit if specified
      final limitedRecords = limit != null && limit < gpsRecords.length
          ? gpsRecords.take(limit).toList()
          : gpsRecords;

      return limitedRecords
          .map((gps) => {
                'id': gps.id,
                'latitude': gps.latitude,
                'longitude': gps.longitude,
                'brzina': gps.brzina,
                'pravac': gps.pravac,
                'vreme': gps.vreme.toIso8601String(),
                // Note: tacnost field not available in current GPSLokacija model
              })
          .toList();
    } catch (e) {
      developer.log('❌ Error getting GPS route: $e',
          name: 'UnifiedGpsService', level: 1000);
      return [];
    }
  }

  // PRIVATE HELPER METHODS

  static Future<Map<String, dynamic>> _verifySystemIntegrity() async {
    try {
      final firebaseCount = await _getFirebaseGpsCount();
      final latestRecord = await _getLatestGpsRecord();

      return {
        'firebase_accessible': true,
        'gps_count': firebaseCount,
        'has_recent_data': latestRecord != null,
        'latest_record_age_hours': latestRecord != null
            ? DateTime.now().difference(latestRecord.vreme).inHours
            : null,
      };
    } catch (e) {
      return {
        'firebase_accessible': false,
        'error': e.toString(),
      };
    }
  }

  static Future<int> _getFirebaseGpsCount() async {
    try {
      // Get total count by querying all active GPS records
      final allRecords = await GpsLokacijaService.getAllActiveGpsLokacije();
      return allRecords.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<GPSLokacija?> _getLatestGpsRecord() async {
    try {
      // Get latest record from any vozac
      final records = await GpsLokacijaService.getGpsLokacije(
        'any', // This might need modification in GpsLokacijaService
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now(),
      );
      return records.isNotEmpty ? records.first : null;
    } catch (e) {
      return null;
    }
  }

  static double _calculateTotalDistance(List<GPSLokacija> records) {
    if (records.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < records.length; i++) {
      final prev = records[i - 1];
      final curr = records[i];

      final distance = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      totalDistance += distance;
    }

    return totalDistance / 1000; // Convert to kilometers
  }

  static double _calculateAverageSpeed(List<GPSLokacija> records) {
    final speedRecords =
        records.where((r) => r.brzina != null && r.brzina! > 0);
    if (speedRecords.isEmpty) return 0.0;

    final totalSpeed = speedRecords.fold(0.0, (sum, r) => sum + r.brzina!);
    return totalSpeed / speedRecords.length;
  }

  static double _calculateMaxSpeed(List<GPSLokacija> records) {
    final speedRecords = records.where((r) => r.brzina != null);
    if (speedRecords.isEmpty) return 0.0;

    return speedRecords.map((r) => r.brzina!).reduce((a, b) => a > b ? a : b);
  }

  static double _calculateTrackingDuration(List<GPSLokacija> records) {
    if (records.length < 2) return 0.0;

    final earliest = records.last.vreme;
    final latest = records.first.vreme;

    return latest.difference(earliest).inMinutes / 60.0; // Convert to hours
  }

  /// 📊 IMPORT GPS DATA FROM CSV FILE
  /// Convenience method for CSV import
  static Future<Map<String, dynamic>> importGpsDataFromCsv({
    required String csvFilePath,
    bool forceOverwrite = false,
    int? maxRecords,
  }) async {
    try {
      developer.log('📊 Starting CSV GPS import from: $csvFilePath',
          name: 'UnifiedGpsService');

      final result = await GpsDataMigrationService.migrateCsvGpsData(
        csvFilePath: csvFilePath,
        forceOverwrite: forceOverwrite,
        maxRecords: maxRecords,
      );

      if (result['success'] == true) {
        developer.log(
            '✅ CSV GPS import completed: ${result['migrated']}/${result['total']} records',
            name: 'UnifiedGpsService');

        // Update system status after import
        final newStatus = await getSystemStatus();
        result['updated_system_status'] = newStatus;
      } else {
        developer.log('❌ CSV GPS import failed: ${result['error']}',
            name: 'UnifiedGpsService', level: 1000);
      }

      return result;
    } catch (e) {
      developer.log('❌ CSV GPS import error: $e',
          name: 'UnifiedGpsService', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'csv_file': csvFilePath,
      };
    }
  }

  /// 🧹 CLEANUP METHODS
  static Future<void> dispose() async {
    await stopTracking();
    await RealtimeGpsService.stopTracking();
    _isInitialized = false;
  }
}
