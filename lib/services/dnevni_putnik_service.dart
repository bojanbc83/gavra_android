import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dnevni_putnik.dart';

/// Service za upravljanje dnevnim putnicima u Firebase Firestore
class DnevniPutnikService {
  static const String _collectionName = 'dnevni_putnici';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Referenca na kolekciju dnevnih putnika
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(_collectionName);

  // CRUD Operacije

  /// Kreira novog dnevnog putnika
  Future<String> createDnevniPutnik(DnevniPutnik putnik) async {
    try {
      developer.log('Creating dnevni putnik: ${putnik.id}', name: 'DnevniPutnikService');

      await _collection.doc(putnik.id).set(putnik.toMap());

      developer.log('Successfully created dnevni putnik: ${putnik.id}', name: 'DnevniPutnikService');
      return putnik.id;
    } catch (e) {
      developer.log('Error creating dnevni putnik: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to create dnevni putnik: $e');
    }
  }

  /// Dobija dnevnog putnika po ID
  Future<DnevniPutnik?> getDnevniPutnik(String id) async {
    try {
      developer.log('Getting dnevni putnik: $id', name: 'DnevniPutnikService');

      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return DnevniPutnik.fromMap(doc.data()!);
    } catch (e) {
      developer.log('Error getting dnevni putnik: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get dnevni putnik: $e');
    }
  }

  /// Dobija sve dnevne putnike
  Future<List<DnevniPutnik>> getAllDnevniPutnici() async {
    try {
      developer.log('Getting all dnevni putnici', name: 'DnevniPutnikService');

      final querySnapshot =
          await _collection.where('obrisan', isEqualTo: false).orderBy('createdAt', descending: true).get();

      return querySnapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting all dnevni putnici: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get all dnevni putnici: $e');
    }
  }

  /// Dobija dnevne putnike po ruti
  Future<List<DnevniPutnik>> getDnevniPutniciByRuta(String rutaId) async {
    try {
      developer.log('Getting dnevni putnici by ruta: $rutaId', name: 'DnevniPutnikService');

      final querySnapshot = await _collection
          .where('ruta_id', isEqualTo: rutaId)
          .where('obrisan', isEqualTo: false)
          .orderBy('vremePolaska')
          .get();

      return querySnapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting dnevni putnici by ruta: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get dnevni putnici by ruta: $e');
    }
  }

  /// Dobija dnevne putnike po datumu
  Future<List<DnevniPutnik>> getDnevniPutniciByDatum(DateTime datum) async {
    try {
      developer.log('Getting dnevni putnici by datum: $datum', name: 'DnevniPutnikService');

      final startOfDay = DateTime(datum.year, datum.month, datum.day);
      final endOfDay = DateTime(datum.year, datum.month, datum.day, 23, 59, 59);

      final querySnapshot = await _collection
          .where('datum', isGreaterThanOrEqualTo: startOfDay.toIso8601String().split('T')[0])
          .where('datum', isLessThanOrEqualTo: endOfDay.toIso8601String().split('T')[0])
          .where('obrisan', isEqualTo: false)
          .orderBy('vremePolaska')
          .get();

      return querySnapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting dnevni putnici by datum: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get dnevni putnici by datum: $e');
    }
  }

  /// Dobija dnevne putnike po statusu
  Future<List<DnevniPutnik>> getDnevniPutniciByStatus(DnevniPutnikStatus status) async {
    try {
      developer.log('Getting dnevni putnici by status: ${status.value}', name: 'DnevniPutnikService');

      final querySnapshot = await _collection
          .where('status', isEqualTo: status.value)
          .where('obrisan', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting dnevni putnici by status: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get dnevni putnici by status: $e');
    }
  }

  /// Dobija dnevne putnike po vozaču
  Future<List<DnevniPutnik>> getDnevniPutniciByVozac(String vozacId) async {
    try {
      developer.log('Getting dnevni putnici by vozac: $vozacId', name: 'DnevniPutnikService');

      final querySnapshot = await _collection
          .where('dodao_vozac_id', isEqualTo: vozacId)
          .where('obrisan', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting dnevni putnici by vozac: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get dnevni putnici by vozac: $e');
    }
  }

  /// Ažurira dnevnog putnika
  Future<void> updateDnevniPutnik(DnevniPutnik putnik) async {
    try {
      developer.log('Updating dnevni putnik: ${putnik.id}', name: 'DnevniPutnikService');

      final updatedPutnik = DnevniPutnik(
        id: putnik.id,
        ime: putnik.ime,
        brojTelefona: putnik.brojTelefona,
        adresaId: putnik.adresaId,
        rutaId: putnik.rutaId,
        datumPutovanja: putnik.datumPutovanja,
        vremePolaska: putnik.vremePolaska,
        brojMesta: putnik.brojMesta,
        cena: putnik.cena,
        status: putnik.status,
        napomena: putnik.napomena,
        vremePokupljenja: putnik.vremePokupljenja,
        pokupioVozacId: putnik.pokupioVozacId,
        vremePlacanja: putnik.vremePlacanja,
        naplatioVozacId: putnik.naplatioVozacId,
        dodaoVozacId: putnik.dodaoVozacId,
        obrisan: putnik.obrisan,
        createdAt: putnik.createdAt,
        updatedAt: DateTime.now(),
      );

      await _collection.doc(putnik.id).update(updatedPutnik.toMap());

      developer.log('Successfully updated dnevni putnik: ${putnik.id}', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error updating dnevni putnik: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to update dnevni putnik: $e');
    }
  }

  /// Briše dnevnog putnika (logički - postavlja obrisan na true)
  Future<void> deleteDnevniPutnik(String id) async {
    try {
      developer.log('Deleting dnevni putnik: $id', name: 'DnevniPutnikService');

      await _collection.doc(id).update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully deleted dnevni putnik: $id', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error deleting dnevni putnik: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to delete dnevni putnik: $e');
    }
  }

  /// Pokuplja putnika (označava kao pokupljen)
  Future<void> pokupljajPutnika(String putnikId, String vozacId) async {
    try {
      developer.log('Pokupljanje putnika: $putnikId by vozac: $vozacId', name: 'DnevniPutnikService');

      await _collection.doc(putnikId).update({
        'status': DnevniPutnikStatus.pokupljen.value,
        'pokupio_vozac_id': vozacId,
        'vreme_pokupljenja': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully pokupljen putnik: $putnikId', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error pokupljanje putnika: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to pokupiti putnika: $e');
    }
  }

  /// Naplaćuje putovanje (označava kao pokupljen sa plaćanjem)
  Future<void> naplataPutovanja(String putnikId, String vozacId) async {
    try {
      developer.log('Naplata putovanja: $putnikId by vozac: $vozacId', name: 'DnevniPutnikService');

      await _collection.doc(putnikId).update({
        'status': DnevniPutnikStatus.pokupljen.value,
        'naplatio_vozac_id': vozacId,
        'vreme_placanja': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully naplaceno putovanje: $putnikId', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error naplata putovanja: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to naplatiti putovanje: $e');
    }
  }

  /// Otkazuje rezervaciju
  Future<void> otkaziRezervaciju(String putnikId) async {
    try {
      developer.log('Otkazivanje rezervacije: $putnikId', name: 'DnevniPutnikService');

      await _collection.doc(putnikId).update({
        'status': DnevniPutnikStatus.otkazan.value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully otkazana rezervacija: $putnikId', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error otkazivanje rezervacije: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to otkazati rezervaciju: $e');
    }
  }

  // Real-time Stream operacije

  /// Stream za praćenje svih dnevnih putnika
  Stream<List<DnevniPutnik>> watchAllDnevniPutnici() {
    try {
      developer.log('Starting watch all dnevni putnici stream', name: 'DnevniPutnikService');

      return _collection
          .where('obrisan', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch all dnevni putnici stream: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to watch all dnevni putnici: $e');
    }
  }

  /// Stream za praćenje dnevnih putnika po ruti
  Stream<List<DnevniPutnik>> watchDnevniPutniciByRuta(String rutaId) {
    try {
      developer.log('Starting watch dnevni putnici by ruta stream: $rutaId', name: 'DnevniPutnikService');

      return _collection
          .where('ruta_id', isEqualTo: rutaId)
          .where('obrisan', isEqualTo: false)
          .orderBy('vremePolaska')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch dnevni putnici by ruta stream: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to watch dnevni putnici by ruta: $e');
    }
  }

  /// Stream za praćenje dnevnih putnika po datumu
  Stream<List<DnevniPutnik>> watchDnevniPutniciByDatum(DateTime datum) {
    try {
      developer.log('Starting watch dnevni putnici by datum stream: $datum', name: 'DnevniPutnikService');

      final startOfDay = DateTime(datum.year, datum.month, datum.day);
      final endOfDay = DateTime(datum.year, datum.month, datum.day, 23, 59, 59);

      return _collection
          .where('datum', isGreaterThanOrEqualTo: startOfDay.toIso8601String().split('T')[0])
          .where('datum', isLessThanOrEqualTo: endOfDay.toIso8601String().split('T')[0])
          .where('obrisan', isEqualTo: false)
          .orderBy('vremePolaska')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch dnevni putnici by datum stream: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to watch dnevni putnici by datum: $e');
    }
  }

  /// Stream za praćenje dnevnih putnika po statusu
  Stream<List<DnevniPutnik>> watchDnevniPutniciByStatus(DnevniPutnikStatus status) {
    try {
      developer.log('Starting watch dnevni putnici by status stream: ${status.value}', name: 'DnevniPutnikService');

      return _collection
          .where('status', isEqualTo: status.value)
          .where('obrisan', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => DnevniPutnik.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch dnevni putnici by status stream: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to watch dnevni putnici by status: $e');
    }
  }

  /// Stream za praćenje jednog dnevnog putnika
  Stream<DnevniPutnik?> watchDnevniPutnik(String id) {
    try {
      developer.log('Starting watch dnevni putnik stream: $id', name: 'DnevniPutnikService');

      return _collection.doc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return DnevniPutnik.fromMap(snapshot.data()!);
      });
    } catch (e) {
      developer.log('Error in watch dnevni putnik stream: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to watch dnevni putnik: $e');
    }
  }

  // Statistike i izvještaji

  /// Dobija broj dnevnih putnika po statusu
  Future<Map<DnevniPutnikStatus, int>> getCountByStatus() async {
    try {
      developer.log('Getting count by status', name: 'DnevniPutnikService');

      final querySnapshot = await _collection.where('obrisan', isEqualTo: false).get();

      final counts = <DnevniPutnikStatus, int>{};
      for (final status in DnevniPutnikStatus.values) {
        counts[status] = 0;
      }

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = DnevniPutnikStatusExtension.fromString(
          data['status'] as String? ?? 'rezervisan',
        );
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      developer.log('Error getting count by status: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get count by status: $e');
    }
  }

  /// Dobija ukupnu zaradu od dnevnih putnika (pokupljenih sa plaćanjem)
  Future<double> getTotalEarnings() async {
    try {
      developer.log('Getting total earnings', name: 'DnevniPutnikService');

      final querySnapshot = await _collection.where('obrisan', isEqualTo: false).get();

      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Računa samo one koji imaju vreme plaćanja (naplaćeni)
        if (data['vreme_placanja'] != null) {
          final cena = (data['cena'] as num?)?.toDouble() ?? 0.0;
          final brojMesta = (data['broj_mesta'] as int?) ?? 1;
          total += cena * brojMesta;
        }
      }

      return total;
    } catch (e) {
      developer.log('Error getting total earnings: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get total earnings: $e');
    }
  }

  /// Dobija zaradu po datumu
  Future<double> getEarningsByDate(DateTime datum) async {
    try {
      developer.log('Getting earnings by date: $datum', name: 'DnevniPutnikService');

      final startOfDay = DateTime(datum.year, datum.month, datum.day);
      final endOfDay = DateTime(datum.year, datum.month, datum.day, 23, 59, 59);

      final querySnapshot = await _collection
          .where('datum', isGreaterThanOrEqualTo: startOfDay.toIso8601String().split('T')[0])
          .where('datum', isLessThanOrEqualTo: endOfDay.toIso8601String().split('T')[0])
          .where('obrisan', isEqualTo: false)
          .get();

      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Računa samo one koji imaju vreme plaćanja (naplaćeni)
        if (data['vreme_placanja'] != null) {
          final cena = (data['cena'] as num?)?.toDouble() ?? 0.0;
          final brojMesta = (data['broj_mesta'] as int?) ?? 1;
          total += cena * brojMesta;
        }
      }

      return total;
    } catch (e) {
      developer.log('Error getting earnings by date: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to get earnings by date: $e');
    }
  }

  // Batch operacije

  /// Kreira više dnevnih putnika odjednom
  Future<List<String>> createBatchDnevniPutnici(List<DnevniPutnik> putnici) async {
    try {
      developer.log('Creating batch dnevni putnici: ${putnici.length}', name: 'DnevniPutnikService');

      final batch = _firestore.batch();
      final ids = <String>[];

      for (final putnik in putnici) {
        final docRef = _collection.doc(putnik.id);
        batch.set(docRef, putnik.toMap());
        ids.add(putnik.id);
      }

      await batch.commit();

      developer.log('Successfully created batch dnevni putnici: ${ids.length}', name: 'DnevniPutnikService');
      return ids;
    } catch (e) {
      developer.log('Error creating batch dnevni putnici: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to create batch dnevni putnici: $e');
    }
  }

  /// Ažurira više dnevnih putnika odjednom
  Future<void> updateBatchDnevniPutnici(List<DnevniPutnik> putnici) async {
    try {
      developer.log('Updating batch dnevni putnici: ${putnici.length}', name: 'DnevniPutnikService');

      final batch = _firestore.batch();

      for (final putnik in putnici) {
        final updatedPutnik = DnevniPutnik(
          id: putnik.id,
          ime: putnik.ime,
          brojTelefona: putnik.brojTelefona,
          adresaId: putnik.adresaId,
          rutaId: putnik.rutaId,
          datumPutovanja: putnik.datumPutovanja,
          vremePolaska: putnik.vremePolaska,
          brojMesta: putnik.brojMesta,
          cena: putnik.cena,
          status: putnik.status,
          napomena: putnik.napomena,
          vremePokupljenja: putnik.vremePokupljenja,
          pokupioVozacId: putnik.pokupioVozacId,
          vremePlacanja: putnik.vremePlacanja,
          naplatioVozacId: putnik.naplatioVozacId,
          dodaoVozacId: putnik.dodaoVozacId,
          obrisan: putnik.obrisan,
          createdAt: putnik.createdAt,
          updatedAt: DateTime.now(),
        );

        final docRef = _collection.doc(putnik.id);
        batch.update(docRef, updatedPutnik.toMap());
      }

      await batch.commit();

      developer.log('Successfully updated batch dnevni putnici: ${putnici.length}', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error updating batch dnevni putnici: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to update batch dnevni putnici: $e');
    }
  }

  /// Briše više dnevnih putnika odjednom (logički)
  Future<void> deleteBatchDnevniPutnici(List<String> ids) async {
    try {
      developer.log('Deleting batch dnevni putnici: ${ids.length}', name: 'DnevniPutnikService');

      final batch = _firestore.batch();

      for (final id in ids) {
        final docRef = _collection.doc(id);
        batch.update(docRef, {
          'obrisan': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();

      developer.log('Successfully deleted batch dnevni putnici: ${ids.length}', name: 'DnevniPutnikService');
    } catch (e) {
      developer.log('Error deleting batch dnevni putnici: $e', name: 'DnevniPutnikService', level: 1000);
      throw Exception('Failed to delete batch dnevni putnici: $e');
    }
  }
}
