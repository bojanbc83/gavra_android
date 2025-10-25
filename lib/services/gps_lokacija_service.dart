import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gps_lokacija.dart';

/// Service za upravljanje GPS lokacijama u Firebase Firestore
class GpsLokacijaService {
  static const String _collectionName = 'gps_lokacije';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  /// Čuva GPS lokaciju
  static Future<void> saveGpsLokacija(GPSLokacija lokacija) async {
    try {
      developer.log('Saving GPS lokacija: ${lokacija.id}',
          name: 'GpsLokacijaService');

      await _collection.doc(lokacija.id).set(lokacija.toMap());

      developer.log('Successfully saved GPS lokacija: ${lokacija.id}',
          name: 'GpsLokacijaService');
    } catch (e) {
      developer.log('Error saving GPS lokacija: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to save GPS lokacija: $e');
    }
  }

  /// Dobija GPS lokacije vozača u određenom vremenskom periodu
  static Future<List<GPSLokacija>> getGpsLokacije(
      String vozac, DateTime from, DateTime to) async {
    try {
      developer.log('Getting GPS lokacije for vozac: $vozac from $from to $to',
          name: 'GpsLokacijaService');

      final querySnapshot = await _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('vreme', isGreaterThanOrEqualTo: from.toIso8601String())
          .where('vreme', isLessThanOrEqualTo: to.toIso8601String())
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => GPSLokacija.fromMap(doc.data()))
          .toList();
    } catch (e) {
      developer.log('Error getting GPS lokacije: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get GPS lokacije: $e');
    }
  }

  /// Dobija poslednju GPS lokaciju vozača
  static Future<GPSLokacija?> getLastGpsLokacija(String vozac) async {
    try {
      developer.log('Getting last GPS lokacija for vozac: $vozac',
          name: 'GpsLokacijaService');

      final querySnapshot = await _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return GPSLokacija.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      developer.log('Error getting last GPS lokacija: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get last GPS lokacija: $e');
    }
  }

  /// Briše stare lokacije (starije od određenog broja dana)
  static Future<void> clearOldLocations(int daysToKeep) async {
    try {
      developer.log('Clearing old locations older than $daysToKeep days',
          name: 'GpsLokacijaService');

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
          name: 'GpsLokacijaService');
    } catch (e) {
      developer.log('Error clearing old locations: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to clear old locations: $e');
    }
  }

  /// Dobija GPS lokacije po vozilu
  static Future<List<GPSLokacija>> getGpsLokacijeByVozilo(
      String voziloId, DateTime from, DateTime to) async {
    try {
      developer.log(
          'Getting GPS lokacije for vozilo: $voziloId from $from to $to',
          name: 'GpsLokacijaService');

      final querySnapshot = await _collection
          .where('vozilo_id', isEqualTo: voziloId)
          .where('vreme', isGreaterThanOrEqualTo: from.toIso8601String())
          .where('vreme', isLessThanOrEqualTo: to.toIso8601String())
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => GPSLokacija.fromMap(doc.data()))
          .toList();
    } catch (e) {
      developer.log('Error getting GPS lokacije by vozilo: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get GPS lokacije by vozilo: $e');
    }
  }

  /// Dobija sve aktivne GPS lokacije
  static Future<List<GPSLokacija>> getAllActiveGpsLokacije() async {
    try {
      developer.log('Getting all active GPS lokacije',
          name: 'GpsLokacijaService');

      final querySnapshot = await _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => GPSLokacija.fromMap(doc.data()))
          .toList();
    } catch (e) {
      developer.log('Error getting all active GPS lokacije: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get all active GPS lokacije: $e');
    }
  }

  /// Ažurira GPS lokaciju
  static Future<void> updateGpsLokacija(GPSLokacija lokacija) async {
    try {
      developer.log('Updating GPS lokacija: ${lokacija.id}',
          name: 'GpsLokacijaService');

      await _collection.doc(lokacija.id).update(lokacija.toMap());

      developer.log('Successfully updated GPS lokacija: ${lokacija.id}',
          name: 'GpsLokacijaService');
    } catch (e) {
      developer.log('Error updating GPS lokacija: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to update GPS lokacija: $e');
    }
  }

  /// Označava GPS lokaciju kao neaktivnu
  static Future<void> markGpsLokacijaInactive(String id) async {
    try {
      developer.log('Marking GPS lokacija inactive: $id',
          name: 'GpsLokacijaService');

      await _collection.doc(id).update({'aktivan': false});

      developer.log('Successfully marked GPS lokacija inactive: $id',
          name: 'GpsLokacijaService');
    } catch (e) {
      developer.log('Error marking GPS lokacija inactive: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to mark GPS lokacija inactive: $e');
    }
  }

  // Real-time Stream operacije

  /// Stream za praćenje GPS lokacija vozača
  static Stream<List<GPSLokacija>> watchGpsLokacijeByVozac(String vozac) {
    try {
      developer.log('Starting GPS lokacije watch stream for vozac: $vozac',
          name: 'GpsLokacijaService');

      return _collection
          .where('vozac_id', isEqualTo: vozac)
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => GPSLokacija.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      developer.log('Error in GPS lokacije watch stream: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to watch GPS lokacije: $e');
    }
  }

  /// Stream za praćenje poslednje GPS lokacije vozača
  static Stream<GPSLokacija?> watchLastGpsLokacija(String vozac) {
    try {
      developer.log('Starting last GPS lokacija watch stream for vozac: $vozac',
          name: 'GpsLokacijaService');

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
      developer.log('Error in last GPS lokacija watch stream: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to watch last GPS lokacija: $e');
    }
  }

  /// Stream za praćenje svih aktivnih GPS lokacija
  static Stream<List<GPSLokacija>> watchAllActiveGpsLokacije() {
    try {
      developer.log('Starting all active GPS lokacije watch stream',
          name: 'GpsLokacijaService');

      return _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('vreme', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => GPSLokacija.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      developer.log('Error in all active GPS lokacije watch stream: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to watch all active GPS lokacije: $e');
    }
  }

  // Batch operacije

  /// Kreira više GPS lokacija odjednom
  static Future<List<String>> createBatchGpsLokacije(
      List<GPSLokacija> lokacije) async {
    try {
      developer.log('Creating batch GPS lokacije: ${lokacije.length}',
          name: 'GpsLokacijaService');

      final batch = _firestore.batch();
      final ids = <String>[];

      for (final lokacija in lokacije) {
        final docRef = _collection.doc(lokacija.id);
        batch.set(docRef, lokacija.toMap());
        ids.add(lokacija.id);
      }

      await batch.commit();

      developer.log('Successfully created batch GPS lokacije: ${ids.length}',
          name: 'GpsLokacijaService');
      return ids;
    } catch (e) {
      developer.log('Error creating batch GPS lokacije: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to create batch GPS lokacije: $e');
    }
  }

  /// Označava više GPS lokacija kao neaktivne
  static Future<void> markBatchGpsLokacijeInactive(List<String> ids) async {
    try {
      developer.log('Marking batch GPS lokacije inactive: ${ids.length}',
          name: 'GpsLokacijaService');

      final batch = _firestore.batch();

      for (final id in ids) {
        final docRef = _collection.doc(id);
        batch.update(docRef, {'aktivan': false});
      }

      await batch.commit();

      developer.log(
          'Successfully marked batch GPS lokacije inactive: ${ids.length}',
          name: 'GpsLokacijaService');
    } catch (e) {
      developer.log('Error marking batch GPS lokacije inactive: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to mark batch GPS lokacije inactive: $e');
    }
  }

  // Statistike i analitika

  /// Dobija ukupnu distancu koju je vozač prešao u određenom periodu
  static Future<double> getTotalDistanceByVozac(
      String vozac, DateTime from, DateTime to) async {
    try {
      developer.log(
          'Getting total distance for vozac: $vozac from $from to $to',
          name: 'GpsLokacijaService');

      final lokacije = await getGpsLokacije(vozac, from, to);

      if (lokacije.length < 2) {
        return 0.0;
      }

      double totalDistance = 0.0;
      for (int i = 0; i < lokacije.length - 1; i++) {
        totalDistance += lokacije[i].distanceTo(lokacije[i + 1]);
      }

      return totalDistance;
    } catch (e) {
      developer.log('Error getting total distance: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get total distance: $e');
    }
  }

  /// Dobija prosečnu brzinu vozača u određenom periodu
  static Future<double> getAverageSpeedByVozac(
      String vozac, DateTime from, DateTime to) async {
    try {
      developer.log('Getting average speed for vozac: $vozac from $from to $to',
          name: 'GpsLokacijaService');

      final lokacije = await getGpsLokacije(vozac, from, to);

      if (lokacije.isEmpty) {
        return 0.0;
      }

      final validSpeeds = lokacije
          .where((l) => l.brzina != null && l.brzina! > 0)
          .map((l) => l.brzina!)
          .toList();

      if (validSpeeds.isEmpty) {
        return 0.0;
      }

      return validSpeeds.reduce((a, b) => a + b) / validSpeeds.length;
    } catch (e) {
      developer.log('Error getting average speed: $e',
          name: 'GpsLokacijaService', level: 1000);
      throw Exception('Failed to get average speed: $e');
    }
  }
}
