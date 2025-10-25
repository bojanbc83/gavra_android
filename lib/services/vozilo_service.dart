import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vozilo.dart';

/// Service za upravljanje vozilima u Firebase Firestore
/// Migrirano sa Supabase na Firebase Firestore
class VoziloService {
  VoziloService();
  static const String _collectionName = 'vozila';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Referenca na kolekciju vozila
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // CRUD Operacije

  /// Dobija sva vozila
  Future<List<Vozilo>> getAllVozila() async {
    try {
      developer.log('Getting all vozila', name: 'VoziloService');

      final querySnapshot = await _collection.orderBy('registracija').get();

      return querySnapshot.docs
          .map((doc) => Vozilo.fromMap(doc.data()))
          .toList();
    } catch (e) {
      developer.log('Error getting all vozila: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to get all vozila: $e');
    }
  }

  /// Dobija vozilo po ID
  Future<Vozilo?> getVoziloById(String id) async {
    try {
      developer.log('Getting vozilo by ID: $id', name: 'VoziloService');

      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Vozilo.fromMap(doc.data()!);
    } catch (e) {
      developer.log('Error getting vozilo by ID: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to get vozilo by ID: $e');
    }
  }

  /// Dodaje novo vozilo
  Future<Vozilo> addVozilo(Vozilo vozilo) async {
    try {
      developer.log('Adding vozilo: ${vozilo.id}', name: 'VoziloService');

      await _collection.doc(vozilo.id).set(vozilo.toMap());

      developer.log('Successfully added vozilo: ${vozilo.id}',
          name: 'VoziloService');
      return vozilo;
    } catch (e) {
      developer.log('Error adding vozilo: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to add vozilo: $e');
    }
  }

  /// Ažurira vozilo
  Future<Vozilo> updateVozilo(String id, Map<String, dynamic> updates) async {
    try {
      developer.log('Updating vozilo: $id', name: 'VoziloService');

      // Dobij postojeće vozilo
      final existingVozilo = await getVoziloById(id);
      if (existingVozilo == null) {
        throw Exception('Vozilo with ID $id not found');
      }

      // Kreiraj novo vozilo sa ažuriranim podacima
      final updatedVozilo = Vozilo(
        id: existingVozilo.id,
        registracija:
            updates['registracija'] as String? ?? existingVozilo.registracija,
        marka: updates['marka'] as String? ?? existingVozilo.marka,
        model: updates['model'] as String? ?? existingVozilo.model,
        godinaProizvodnje: updates['godina_proizvodnje'] as int? ??
            existingVozilo.godinaProizvodnje,
        brojSedista:
            updates['broj_sedista'] as int? ?? existingVozilo.brojSedista,
        aktivan: updates['aktivan'] as bool? ?? existingVozilo.aktivan,
        createdAt: existingVozilo.createdAt,
        updatedAt: DateTime.now(),
      );

      await _collection.doc(id).update(updatedVozilo.toMap());

      developer.log('Successfully updated vozilo: $id', name: 'VoziloService');
      return updatedVozilo;
    } catch (e) {
      developer.log('Error updating vozilo: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to update vozilo: $e');
    }
  }

  /// Briše vozilo (logički - označava kao neaktivno)
  Future<void> deleteVozilo(String id) async {
    try {
      developer.log('Deleting vozilo: $id', name: 'VoziloService');

      await _collection.doc(id).update({
        'aktivan': false,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully deleted vozilo: $id', name: 'VoziloService');
    } catch (e) {
      developer.log('Error deleting vozilo: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to delete vozilo: $e');
    }
  }

  /// Dobija samo aktivna vozila
  Future<List<Vozilo>> getActiveVozila() async {
    try {
      developer.log('Getting active vozila', name: 'VoziloService');

      final querySnapshot = await _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('registracija')
          .get();

      return querySnapshot.docs
          .map((doc) => Vozilo.fromMap(doc.data()))
          .toList();
    } catch (e) {
      developer.log('Error getting active vozila: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to get active vozila: $e');
    }
  }

  /// Pretražuje vozila po registraciji, marki ili modelu
  Future<List<Vozilo>> searchVozila(String query) async {
    try {
      developer.log('Searching vozila with query: $query',
          name: 'VoziloService');

      final querySnapshot = await _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('registracija')
          .get();

      final allVozila =
          querySnapshot.docs.map((doc) => Vozilo.fromMap(doc.data())).toList();

      // Filter client-side zbog ograničenja Firestore složenih upita
      final lowerQuery = query.toLowerCase();
      return allVozila
          .where(
            (vozilo) =>
                vozilo.registracija.toLowerCase().contains(lowerQuery) ||
                vozilo.marka.toLowerCase().contains(lowerQuery) ||
                vozilo.model.toLowerCase().contains(lowerQuery),
          )
          .toList();
    } catch (e) {
      developer.log('Error searching vozila: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to search vozila: $e');
    }
  }

  // Real-time Stream operacije

  /// Stream za praćenje svih vozila
  Stream<List<Vozilo>> watchAllVozila() {
    try {
      developer.log('Starting watch all vozila stream', name: 'VoziloService');

      return _collection.orderBy('registracija').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Vozilo.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch all vozila stream: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to watch all vozila: $e');
    }
  }

  /// Stream za praćenje aktivnih vozila
  Stream<List<Vozilo>> watchActiveVozila() {
    try {
      developer.log('Starting watch active vozila stream',
          name: 'VoziloService');

      return _collection
          .where('aktivan', isEqualTo: true)
          .orderBy('registracija')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => Vozilo.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch active vozila stream: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to watch active vozila: $e');
    }
  }

  /// Stream za praćenje jednog vozila
  Stream<Vozilo?> watchVozilo(String id) {
    try {
      developer.log('Starting watch vozilo stream: $id', name: 'VoziloService');

      return _collection.doc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return Vozilo.fromMap(snapshot.data()!);
      });
    } catch (e) {
      developer.log('Error in watch vozilo stream: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to watch vozilo: $e');
    }
  }

  // Statistike

  /// Dobija broj vozila po statusu
  Future<Map<String, int>> getVozilaStatistics() async {
    try {
      developer.log('Getting vozila statistics', name: 'VoziloService');

      final querySnapshot = await _collection.get();

      int total = 0;
      int active = 0;
      int inactive = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total++;
        if (data['aktivan'] == true) {
          active++;
        } else {
          inactive++;
        }
      }

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
      };
    } catch (e) {
      developer.log('Error getting vozila statistics: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to get vozila statistics: $e');
    }
  }

  // Batch operacije

  /// Kreira više vozila odjednom
  Future<List<String>> createBatchVozila(List<Vozilo> vozila) async {
    try {
      developer.log('Creating batch vozila: ${vozila.length}',
          name: 'VoziloService');

      final batch = _firestore.batch();
      final ids = <String>[];

      for (final vozilo in vozila) {
        final docRef = _collection.doc(vozilo.id);
        batch.set(docRef, vozilo.toMap());
        ids.add(vozilo.id);
      }

      await batch.commit();

      developer.log('Successfully created batch vozila: ${ids.length}',
          name: 'VoziloService');
      return ids;
    } catch (e) {
      developer.log('Error creating batch vozila: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to create batch vozila: $e');
    }
  }

  /// Deaktivira više vozila odjednom
  Future<void> deactivateBatchVozila(List<String> ids) async {
    try {
      developer.log('Deactivating batch vozila: ${ids.length}',
          name: 'VoziloService');

      final batch = _firestore.batch();

      for (final id in ids) {
        final docRef = _collection.doc(id);
        batch.update(docRef, {
          'aktivan': false,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();

      developer.log('Successfully deactivated batch vozila: ${ids.length}',
          name: 'VoziloService');
    } catch (e) {
      developer.log('Error deactivating batch vozila: $e',
          name: 'VoziloService', level: 1000);
      throw Exception('Failed to deactivate batch vozila: $e');
    }
  }
}
