import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gps_lokacija.dart';

/// Service za upravljanje GPS praćenjem vozača
class GpsService {
  static const String _collectionName = 'gps_lokacije';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  static StreamSubscription<QuerySnapshot>? _trackingSubscription;
  static bool _isTracking = false;

  /// Čuva GPS lokaciju vozača
  static Future<void> saveGpsLocation(
      String vozac, double lat, double lng) async {
    try {
      developer.log('Saving GPS location for vozac: $vozac',
          name: 'GpsService');

      final lokacija = GPSLokacija.sada(
        voziloId: vozac, // Koristimo vozac ID kao vozilo ID za kompatibilnost
        vozacId: vozac,
        latitude: lat,
        longitude: lng,
      );

      await _collection.doc(lokacija.id).set(lokacija.toMap());

      developer.log('Successfully saved GPS location: ${lokacija.id}',
          name: 'GpsService');
    } catch (e) {
      developer.log('Error saving GPS location: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to save GPS location: $e');
    }
  }

  /// Dobija istoriju lokacija vozača u određenom vremenskom periodu
  static Future<List<Map<String, dynamic>>> getLocationHistory(
      String vozac, DateTime from, DateTime to) async {
    try {
      developer.log(
          'Getting location history for vozac: $vozac from $from to $to',
          name: 'GpsService');

      final querySnapshot = await _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('vreme', isGreaterThanOrEqualTo: from.toIso8601String())
          .where('vreme', isLessThanOrEqualTo: to.toIso8601String())
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      developer.log('Error getting location history: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to get location history: $e');
    }
  }

  /// Dobija poslednju poznatu lokaciju vozača
  static Future<Map<String, dynamic>?> getLastKnownLocation(
      String vozac) async {
    try {
      developer.log('Getting last known location for vozac: $vozac',
          name: 'GpsService');

      final querySnapshot = await _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.data();
    } catch (e) {
      developer.log('Error getting last known location: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to get last known location: $e');
    }
  }

  /// Pokreće praćenje lokacije vozača u realnom vremenu
  static Future<void> startLocationTracking(String vozac) async {
    try {
      developer.log('Starting location tracking for vozac: $vozac',
          name: 'GpsService');

      if (_isTracking) {
        developer.log('Location tracking already started', name: 'GpsService');
        await stopLocationTracking();
      }

      _trackingSubscription = _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .limit(1)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            developer.log(
                'Real-time location update: ${data['latitude']}, ${data['longitude']}',
                name: 'GpsService');
          }
        },
        onError: (Object error) {
          developer.log('Error in location tracking: $error',
              name: 'GpsService', level: 1000);
        },
      );

      _isTracking = true;
      developer.log('Successfully started location tracking',
          name: 'GpsService');
    } catch (e) {
      developer.log('Error starting location tracking: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to start location tracking: $e');
    }
  }

  /// Zaustavlja praćenje lokacije
  static Future<void> stopLocationTracking() async {
    try {
      developer.log('Stopping location tracking', name: 'GpsService');

      if (_trackingSubscription != null) {
        await _trackingSubscription!.cancel();
        _trackingSubscription = null;
      }

      _isTracking = false;
      developer.log('Successfully stopped location tracking',
          name: 'GpsService');
    } catch (e) {
      developer.log('Error stopping location tracking: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to stop location tracking: $e');
    }
  }

  /// Proverava da li je praćenje aktivno
  static bool get isTracking => _isTracking;

  /// Stream za praćenje lokacije vozača u realnom vremenu
  static Stream<GPSLokacija?> watchLocationStream(String vozac) {
    try {
      developer.log('Starting location watch stream for vozac: $vozac',
          name: 'GpsService');

      return _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return null;
        }
        return GPSLokacija.fromMap(snapshot.docs.first.data());
      });
    } catch (e) {
      developer.log('Error in location watch stream: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to watch location stream: $e');
    }
  }

  /// Briše stare lokacije (starije od određenog broja dana)
  static Future<void> clearOldLocations(int daysToKeep) async {
    try {
      developer.log('Clearing old locations older than $daysToKeep days',
          name: 'GpsService');

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final querySnapshot = await _collection
          .where('vreme', isLessThan: cutoffDate.toIso8601String())
          .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      developer.log(
          'Successfully cleared ${querySnapshot.docs.length} old locations',
          name: 'GpsService');
    } catch (e) {
      developer.log('Error clearing old locations: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to clear old locations: $e');
    }
  }

  /// Dobija aktivne vozače sa poslednjim lokacijama
  static Future<List<Map<String, dynamic>>>
      getActiveDriversWithLocations() async {
    try {
      developer.log('Getting active drivers with locations',
          name: 'GpsService');

      final querySnapshot = await _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .get();

      final driversMap = <String, Map<String, dynamic>>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final vozacId = data['vozac_id'] as String?;

        if (vozacId != null && !driversMap.containsKey(vozacId)) {
          driversMap[vozacId] = data;
        }
      }

      return driversMap.values.toList();
    } catch (e) {
      developer.log('Error getting active drivers with locations: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to get active drivers with locations: $e');
    }
  }

  /// Označava vozača kao neaktivnog
  static Future<void> markDriverInactive(String vozac) async {
    try {
      developer.log('Marking driver inactive: $vozac', name: 'GpsService');

      final querySnapshot = await _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'aktivan': false});
      }

      await batch.commit();

      developer.log('Successfully marked driver inactive: $vozac',
          name: 'GpsService');
    } catch (e) {
      developer.log('Error marking driver inactive: $e',
          name: 'GpsService', level: 1000);
      throw Exception('Failed to mark driver inactive: $e');
    }
  }
}
