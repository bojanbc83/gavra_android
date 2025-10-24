import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ruta.dart';

/// Service za upravljanje rutama u Firebase Firestore
/// Migrirano sa Supabase na Firebase Firestore
class RutaService {
  RutaService();
  static const String _collectionName = 'rute';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Referenca na kolekciju ruta
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(_collectionName);

  // CRUD Operacije

  /// Dobija sve rute
  Future<List<Ruta>> getAllRute() async {
    try {
      developer.log('Getting all rute', name: 'RutaService');

      final querySnapshot = await _collection.orderBy('naziv').get();

      return querySnapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting all rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get all rute: $e');
    }
  }

  /// Dobija samo aktivne rute
  Future<List<Ruta>> getActiveRute() async {
    try {
      developer.log('Getting active rute', name: 'RutaService');

      final querySnapshot = await _collection.where('aktivan', isEqualTo: true).orderBy('naziv').get();

      return querySnapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log('Error getting active rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get active rute: $e');
    }
  }

  /// Dobija rutu po ID
  Future<Ruta?> getRutaById(String id) async {
    try {
      developer.log('Getting ruta by ID: $id', name: 'RutaService');

      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Ruta.fromMap(doc.data()!);
    } catch (e) {
      developer.log('Error getting ruta by ID: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get ruta by ID: $e');
    }
  }

  /// Dodaje novu rutu
  Future<Ruta> addRuta(Ruta ruta) async {
    try {
      developer.log('Adding ruta: ${ruta.id}', name: 'RutaService');

      // Validacija pre dodavanja
      if (!ruta.isValidForDatabase) {
        final errors = ruta.validateFull();
        throw Exception('Validation failed: ${errors.values.join(', ')}');
      }

      await _collection.doc(ruta.id).set(ruta.toMap());

      developer.log('Successfully added ruta: ${ruta.id}', name: 'RutaService');
      return ruta;
    } catch (e) {
      developer.log('Error adding ruta: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to add ruta: $e');
    }
  }

  /// Ažurira rutu
  Future<Ruta> updateRuta(String id, Map<String, dynamic> updates) async {
    try {
      developer.log('Updating ruta: $id', name: 'RutaService');

      // Dobij postojeću rutu
      final existingRuta = await getRutaById(id);
      if (existingRuta == null) {
        throw Exception('Ruta with ID $id not found');
      }

      // Kreiraj novu rutu sa ažuriranim podacima
      final updatedRuta = existingRuta.copyWith(
        naziv: updates['naziv'] as String?,
        polazak: updates['polazak'] as String?,
        dolazak: updates['dolazak'] as String?,
        opis: updates['opis'] as String?,
        udaljenostKm: (updates['udaljenost_km'] as num?)?.toDouble(),
        prosecnoVreme: updates['prosecno_vreme'] != null ? Duration(seconds: updates['prosecno_vreme'] as int) : null,
        aktivan: updates['aktivan'] as bool?,
        updatedAt: DateTime.now(),
      );

      // Validacija pre ažuriranja
      if (!updatedRuta.isValidForDatabase) {
        final errors = updatedRuta.validateFull();
        throw Exception('Validation failed: ${errors.values.join(', ')}');
      }

      await _collection.doc(id).update(updatedRuta.toMap());

      developer.log('Successfully updated ruta: $id', name: 'RutaService');
      return updatedRuta;
    } catch (e) {
      developer.log('Error updating ruta: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to update ruta: $e');
    }
  }

  /// Briše rutu (logički - označava kao neaktivnu)
  Future<void> deleteRuta(String id) async {
    try {
      developer.log('Deleting ruta: $id', name: 'RutaService');

      await _collection.doc(id).update({
        'aktivan': false,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully deleted ruta: $id', name: 'RutaService');
    } catch (e) {
      developer.log('Error deleting ruta: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to delete ruta: $e');
    }
  }

  /// Aktivira rutu
  Future<void> activateRuta(String id) async {
    try {
      developer.log('Activating ruta: $id', name: 'RutaService');

      await _collection.doc(id).update({
        'aktivan': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully activated ruta: $id', name: 'RutaService');
    } catch (e) {
      developer.log('Error activating ruta: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to activate ruta: $e');
    }
  }

  /// Deaktivira rutu
  Future<void> deactivateRuta(String id) async {
    try {
      developer.log('Deactivating ruta: $id', name: 'RutaService');

      await _collection.doc(id).update({
        'aktivan': false,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Successfully deactivated ruta: $id', name: 'RutaService');
    } catch (e) {
      developer.log('Error deactivating ruta: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to deactivate ruta: $e');
    }
  }

  // Search operacije

  /// Pretražuje rute po nazivu, polasku ili dolasku
  Future<List<Ruta>> searchRute(String query) async {
    try {
      developer.log('Searching rute with query: $query', name: 'RutaService');

      final querySnapshot = await _collection.where('aktivan', isEqualTo: true).orderBy('naziv').get();

      final allRute = querySnapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();

      // Filter client-side zbog ograničenja Firestore složenih upita
      return allRute.where((ruta) => ruta.containsQuery(query)).toList();
    } catch (e) {
      developer.log('Error searching rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to search rute: $e');
    }
  }

  /// Pronalazi rute koje povezuju određena mesta
  Future<List<Ruta>> findRuteByDestinations(String grad1, String grad2) async {
    try {
      developer.log('Finding rute between: $grad1 and $grad2', name: 'RutaService');

      final querySnapshot = await _collection.where('aktivan', isEqualTo: true).get();

      final allRute = querySnapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();

      return allRute.where((ruta) => ruta.connectsCities(grad1, grad2)).toList();
    } catch (e) {
      developer.log('Error finding rute by destinations: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to find rute by destinations: $e');
    }
  }

  // Real-time Stream operacije

  /// Stream za praćenje svih ruta
  Stream<List<Ruta>> watchAllRute() {
    try {
      developer.log('Starting watch all rute stream', name: 'RutaService');

      return _collection.orderBy('naziv').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch all rute stream: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to watch all rute: $e');
    }
  }

  /// Stream za praćenje aktivnih ruta
  Stream<List<Ruta>> watchActiveRute() {
    try {
      developer.log('Starting watch active rute stream', name: 'RutaService');

      return _collection.where('aktivan', isEqualTo: true).orderBy('naziv').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Ruta.fromMap(doc.data())).toList();
      });
    } catch (e) {
      developer.log('Error in watch active rute stream: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to watch active rute: $e');
    }
  }

  /// Stream za praćenje jedne rute
  Stream<Ruta?> watchRuta(String id) {
    try {
      developer.log('Starting watch ruta stream: $id', name: 'RutaService');

      return _collection.doc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return Ruta.fromMap(snapshot.data()!);
      });
    } catch (e) {
      developer.log('Error in watch ruta stream: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to watch ruta: $e');
    }
  }

  // Statistike i izvještaji

  /// Dobija broj ruta po statusu
  Future<Map<String, int>> getRouteStatistics() async {
    try {
      developer.log('Getting route statistics', name: 'RutaService');

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
      developer.log('Error getting route statistics: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get route statistics: $e');
    }
  }

  /// Dobija najduge rute
  Future<List<Ruta>> getLongestRoutes({int limit = 10}) async {
    try {
      developer.log('Getting longest routes', name: 'RutaService');

      final querySnapshot = await _collection.where('aktivan', isEqualTo: true).get();

      final rute =
          querySnapshot.docs.map((doc) => Ruta.fromMap(doc.data())).where((ruta) => ruta.udaljenostKm != null).toList();

      rute.sort((a, b) => (b.udaljenostKm ?? 0).compareTo(a.udaljenostKm ?? 0));

      return rute.take(limit).toList();
    } catch (e) {
      developer.log('Error getting longest routes: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get longest routes: $e');
    }
  }

  /// Dobija najbrže rute
  Future<List<Ruta>> getFastestRoutes({int limit = 10}) async {
    try {
      developer.log('Getting fastest routes', name: 'RutaService');

      final querySnapshot = await _collection.where('aktivan', isEqualTo: true).get();

      final rute = querySnapshot.docs
          .map((doc) => Ruta.fromMap(doc.data()))
          .where((ruta) => ruta.prosecnoVreme != null)
          .toList();

      rute.sort((a, b) => (a.prosecnoVreme ?? Duration.zero).compareTo(b.prosecnoVreme ?? Duration.zero));

      return rute.take(limit).toList();
    } catch (e) {
      developer.log('Error getting fastest routes: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to get fastest routes: $e');
    }
  }

  // Batch operacije

  /// Kreira više ruta odjednom
  Future<List<String>> createBatchRute(List<Ruta> rute) async {
    try {
      developer.log('Creating batch rute: ${rute.length}', name: 'RutaService');

      // Validacija svih ruta
      for (final ruta in rute) {
        if (!ruta.isValidForDatabase) {
          final errors = ruta.validateFull();
          throw Exception('Validation failed for ruta ${ruta.naziv}: ${errors.values.join(', ')}');
        }
      }

      final batch = _firestore.batch();
      final ids = <String>[];

      for (final ruta in rute) {
        final docRef = _collection.doc(ruta.id);
        batch.set(docRef, ruta.toMap());
        ids.add(ruta.id);
      }

      await batch.commit();

      developer.log('Successfully created batch rute: ${ids.length}', name: 'RutaService');
      return ids;
    } catch (e) {
      developer.log('Error creating batch rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to create batch rute: $e');
    }
  }

  /// Ažurira više ruta odjednom
  Future<void> updateBatchRute(List<Ruta> rute) async {
    try {
      developer.log('Updating batch rute: ${rute.length}', name: 'RutaService');

      // Validacija svih ruta
      for (final ruta in rute) {
        if (!ruta.isValidForDatabase) {
          final errors = ruta.validateFull();
          throw Exception('Validation failed for ruta ${ruta.naziv}: ${errors.values.join(', ')}');
        }
      }

      final batch = _firestore.batch();

      for (final ruta in rute) {
        final updatedRuta = ruta.withUpdatedTime();
        final docRef = _collection.doc(ruta.id);
        batch.update(docRef, updatedRuta.toMap());
      }

      await batch.commit();

      developer.log('Successfully updated batch rute: ${rute.length}', name: 'RutaService');
    } catch (e) {
      developer.log('Error updating batch rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to update batch rute: $e');
    }
  }

  /// Deaktivira više ruta odjednom
  Future<void> deactivateBatchRute(List<String> ids) async {
    try {
      developer.log('Deactivating batch rute: ${ids.length}', name: 'RutaService');

      final batch = _firestore.batch();

      for (final id in ids) {
        final docRef = _collection.doc(id);
        batch.update(docRef, {
          'aktivan': false,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();

      developer.log('Successfully deactivated batch rute: ${ids.length}', name: 'RutaService');
    } catch (e) {
      developer.log('Error deactivating batch rute: $e', name: 'RutaService', level: 1000);
      throw Exception('Failed to deactivate batch rute: $e');
    }
  }
}
