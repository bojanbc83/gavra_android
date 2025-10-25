import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vozac.dart';

/// 🔥 GAVRA 013 - VOZAC SERVICE (FIREBASE)
///
/// Migrirano sa Supabase na Firebase Firestore
/// Upravlja vozačima i njihovim podacima

class VozacService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'vozaci';

  /// 📋 Dohvata sve aktivne vozače
  Future<List<Vozac>> getAllVozaci() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true)
          .orderBy('ime')
          .get();

      return querySnapshot.docs
          .map((doc) => Vozac.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Greška pri dohvatanju vozača: $e');
    }
  }

  /// 👤 Dohvata vozača po ID-u
  Future<Vozac?> getVozacById(String id) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(id).get();

      if (!docSnapshot.exists) return null;

      return Vozac.fromMap(docSnapshot.data()!);
    } catch (e) {
      throw Exception('Greška pri dohvatanju vozača po ID: $e');
    }
  }

  /// 🔍 Dohvata vozača po imenu (first match)
  Future<Vozac?> getVozacByIme(String ime) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true)
          .where('ime', isEqualTo: ime)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return Vozac.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      throw Exception('Greška pri dohvatanju vozača po imenu: $e');
    }
  }

  /// ➕ Dodaje novog vozača
  Future<Vozac> addVozac(Vozac vozac) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();

      // Kreiranje novog vozača sa generisanim ID-om
      final newVozac = Vozac(
        id: docRef.id,
        ime: vozac.ime,
        prezime: vozac.prezime,
        brojTelefona: vozac.brojTelefona,
        email: vozac.email,
        adresaId: vozac.adresaId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newVozac.toMap());
      return newVozac;
    } catch (e) {
      throw Exception('Greška pri dodavanju vozača: $e');
    }
  }

  /// ✏️ Ažurira postojećeg vozača
  Future<Vozac> updateVozac(String id, Map<String, dynamic> updates) async {
    try {
      // Dodaj updated_at timestamp
      updates['updated_at'] = FieldValue.serverTimestamp();
      updates['poslednja_aktivnost'] = FieldValue.serverTimestamp();

      final docRef = _firestore.collection(_collectionName).doc(id);
      await docRef.update(updates);

      // Vrati ažuriran dokument
      final updatedDoc = await docRef.get();
      if (!updatedDoc.exists) {
        throw Exception('Vozač sa ID $id ne postoji nakon ažuriranja');
      }

      return Vozac.fromMap(updatedDoc.data()!);
    } catch (e) {
      throw Exception('Greška pri ažuriranju vozača: $e');
    }
  }

  /// 🗑️ Briše vozača (soft delete)
  Future<void> deleteVozac(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'aktivan': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri brisanju vozača: $e');
    }
  }

  /// 🔍 Pretraga vozača po različitim kriterijumima
  Future<List<Vozac>> searchVozaci(String searchTerm) async {
    try {
      // Pretraži po imenu i email-u
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true)
          .get();

      // Client-side filtering (Firestore ne podržava složenu pretragu)
      final results = querySnapshot.docs
          .map((doc) => Vozac.fromMap(doc.data()))
          .where(
            (vozac) =>
                vozac.punoIme
                    .toLowerCase()
                    .contains(searchTerm.toLowerCase()) ||
                (vozac.email
                        ?.toLowerCase()
                        .contains(searchTerm.toLowerCase()) ??
                    false) ||
                (vozac.brojTelefona?.contains(searchTerm) ?? false),
          )
          .toList();

      return results;
    } catch (e) {
      throw Exception('Greška pri pretraži vozača: $e');
    }
  }

  /// 📍 Označi poslednju aktivnost vozača
  Future<void> updateLastActivity(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri ažuriranju poslednje aktivnosti: $e');
    }
  }

  /// 📊 Real-time stream aktivnih vozača
  Stream<List<Vozac>> getActiveVozaciStream() {
    return _firestore
        .collection(_collectionName)
        .where('aktivan', isEqualTo: true)
        .orderBy('ime')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Vozac.fromMap(doc.data())).toList(),
        );
  }

  /// 📱 Ažuriraj device token za push notifikacije
  Future<void> updateDeviceToken(String vozacId, String? deviceToken) async {
    try {
      await _firestore.collection(_collectionName).doc(vozacId).update({
        'device_token': deviceToken,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri ažuriranju device token-a: $e');
    }
  }
}
