import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dnevni_putnik.dart';
import '../models/gps_lokacija.dart';
import '../models/putnik.dart';
import '../utils/vozac_boja.dart';

/// 🔥 FIRESTORE DATABASE SERVICE
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static CollectionReference get _putnici => _firestore.collection('putnici');
  static CollectionReference get _dnevniPutnici =>
      _firestore.collection('dnevni_putnici');
  static CollectionReference get _gpsLokacije =>
      _firestore.collection('gps_lokacije');

  /// 👥 PUTNICI OPERATIONS

  /// Dobij sve putnike
  static Future<List<Putnik>> getPutnici() async {
    try {
      final snapshot = await _putnici.where('obrisan', isEqualTo: false).get();
      return snapshot.docs
          .map((doc) => Putnik.fromMap(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Realtime stream putnika
  static Stream<List<Putnik>> putniciStream() {
    return _putnici.where('obrisan', isEqualTo: false).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Putnik.fromMap(
                  {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList(),
        );
  }

  /// Dodaj novog putnika
  static Future<String?> addPutnik(Putnik putnik) async {
    try {
      final docRef = await _putnici.add(putnik.toMap());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Update putnika
  static Future<bool> updatePutnik(
      String id, Map<String, dynamic> updates) async {
    try {
      await _putnici.doc(id).update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obriši putnika (soft delete)
  static Future<bool> deletePutnik(String id) async {
    try {
      await _putnici.doc(id).update({'obrisan': true});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 📅 DNEVNI PUTNICI OPERATIONS

  /// Dobij dnevne putnike za datum
  static Future<List<DnevniPutnik>> getDnevniPutniciZaDatum(
      DateTime datum) async {
    try {
      final datumString = datum.toIso8601String().split('T')[0];
      final snapshot = await _dnevniPutnici
          .where('datum', isEqualTo: datumString)
          .where('obrisan', isEqualTo: false)
          .orderBy('polazak')
          .get();

      return snapshot.docs
          .map((doc) => DnevniPutnik.fromMap(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Realtime stream dnevnih putnika za datum
  static Stream<List<DnevniPutnik>> dnevniPutniciStreamZaDatum(DateTime datum) {
    final datumString = datum.toIso8601String().split('T')[0];
    return _dnevniPutnici
        .where('datum', isEqualTo: datumString)
        .where('obrisan', isEqualTo: false)
        .orderBy('polazak')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DnevniPutnik.fromMap(
                  {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList(),
        );
  }

  /// Dodaj dnevnog putnika
  static Future<String?> addDnevniPutnik(DnevniPutnik putnik) async {
    try {
      final docRef = await _dnevniPutnici.add(putnik.toMap());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Update dnevnog putnika
  static Future<bool> updateDnevniPutnik(
      String id, Map<String, dynamic> updates) async {
    try {
      await _dnevniPutnici.doc(id).update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 📍 GPS LOKACIJE OPERATIONS

  /// Dodaj GPS lokaciju
  static Future<bool> addGpsLokacija(GPSLokacija lokacija) async {
    try {
      await _gpsLokacije.add(lokacija.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Realtime stream GPS lokacija
  static Stream<List<GPSLokacija>> gpsLokacijeStream() {
    return _gpsLokacije
        .orderBy('timestamp', descending: true)
        .limit(100) // Ograniči na poslednje 100 lokacija
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GPSLokacija.fromMap(
                  {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList(),
        );
  }

  /// 🧹 UTILITY METHODS
  static Future<int> cleanupNevalidneVozace() async {
    int obrisaneStavke = 0;

    try {
      // Cleanup putnici
      final putniciBatch = _firestore.batch();
      final putniciSnapshot = await _putnici.get();

      for (var doc in putniciSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vozac = data['vozac'] as String?;

        if (vozac != null && !VozacBoja.validDrivers.contains(vozac)) {
          putniciBatch.update(doc.reference, {'obrisan': true});
          obrisaneStavke++;
        }
      }

      await putniciBatch.commit();

      // Cleanup dnevni_putnici
      final dnevniBatch = _firestore.batch();
      final dnevniSnapshot = await _dnevniPutnici.get();

      for (var doc in dnevniSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vozac = data['vozac'] as String?;

        if (vozac != null && !VozacBoja.validDrivers.contains(vozac)) {
          dnevniBatch.update(doc.reference, {'obrisan': true});
          obrisaneStavke++;
        }
      }

      await dnevniBatch.commit();
      return obrisaneStavke;
    } catch (e) {
      return 0;
    }
  }

  /// Proveri bazu za nevalidne vozače
  static Future<Map<String, int>> proveriBazuZaNevalidneVozace() async {
    final Map<String, int> rezultat = {'putnici': 0, 'dnevni_putnici': 0};

    try {
      // Proveri putnici
      final putniciSnapshot =
          await _putnici.where('obrisan', isEqualTo: false).get();
      for (var doc in putniciSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vozac = data['vozac'] as String?;
        if (vozac != null && !VozacBoja.validDrivers.contains(vozac)) {
          rezultat['putnici'] = rezultat['putnici']! + 1;
        }
      }

      // Proveri dnevni_putnici
      final dnevniSnapshot =
          await _dnevniPutnici.where('obrisan', isEqualTo: false).get();
      for (var doc in dnevniSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vozac = data['vozac'] as String?;
        if (vozac != null && !VozacBoja.validDrivers.contains(vozac)) {
          rezultat['dnevni_putnici'] = rezultat['dnevni_putnici']! + 1;
        }
      }

      return rezultat;
    } catch (e) {
      return rezultat;
    }
  }

  /// Dohvati GPS lokacije (async)
  static Future<List<GPSLokacija>> getGpsLokacije({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('gps_lokacije')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GPSLokacija.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // =========== PUTNIK SERVICE METHODS ===========

  /// Dohvati sve putnike - alias za getAllPutnici
  static Future<List<Putnik>> getAllPutnici() async {
    return await putniciStream().first.timeout(
          const Duration(seconds: 10),
          onTimeout: () => [],
        );
  }

  /// Stream kombinovanih putnika (filtered)
  static Stream<List<Putnik>> streamKombinovaniPutniciFiltered() {
    return putniciStream();
  }

  /// Pretraži putnike po imenu
  static Future<List<Putnik>> searchPutnici(String query) async {
    try {
      final snapshot = await _putnici
          .where('ime', isGreaterThanOrEqualTo: query)
          .where('ime', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('ime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Putnik.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ažuriraj dug putnika
  static Future<bool> updateDug(String putnikId, double noviDug) async {
    try {
      await _putnici.doc(putnikId).update({'duguje': noviDug});
      return true;
    } catch (e) {
      return false;
    }
  }
}
