import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mesecni_putnik.dart';

/// 🔥 GAVRA 013 - MESECNI PUTNIK SERVICE (FIREBASE)
///
/// Migrirano sa Supabase na Firebase Firestore
/// Upravlja mesečnim putnicima

class MesecniPutnikService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'mesecni_putnici';

  /// 🔍 Dohvata mesečnog putnika po imenu
  static Future<MesecniPutnik?> getMesecniPutnikByIme(String ime) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('putnik_ime', isEqualTo: ime)
          .where('aktivan', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return MesecniPutnik.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      throw Exception('Greška pri dohvatanju mesečnog putnika: $e');
    }
  }

  /// 📊 Računa broj putovanja iz istorije
  static Future<int> izracunajBrojPutovanjaIzIstorije(String ime) async {
    try {
      // Dohvati ID putnika
      final putnik = await getMesecniPutnikByIme(ime);
      if (putnik == null) return 0;

      // Vratiće podatak iz modela (već se čuva u statistics)
      return putnik.brojPutovanja;
    } catch (e) {
      throw Exception('Greška pri računanju broja putovanja: $e');
    }
  }

  /// 📊 Računa broj otkazivanja iz istorije
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(String ime) async {
    try {
      final putnik = await getMesecniPutnikByIme(ime);
      if (putnik == null) return 0;

      // Vratiće podatak iz modela (već se čuva u statistics)
      return putnik.brojOtkazivanja;
    } catch (e) {
      throw Exception('Greška pri računanju broja otkazivanja: $e');
    }
  }

  /// 💰 Ažurira plaćanje za mesec
  Future<bool> azurirajPlacanjeZaMesec(
      String ime, String mesec, double iznos) async {
    try {
      final putnik = await getMesecniPutnikByIme(ime);
      if (putnik == null) return false;

      // Ažuriraj direktno putnik zapis sa plaćanjem
      await _firestore.collection(_collectionName).doc(putnik.id).update({
        'placeni_mesec': int.parse(mesec.split('-')[1]),
        'placena_godina': int.parse(mesec.split('-')[0]),
        'cena': iznos,
        'vreme_placanja': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Ažuriraj i putnikov zapis
      await _firestore.collection(_collectionName).doc(putnik.id).update({
        'poslednje_placanje': FieldValue.serverTimestamp(),
        'poslednji_iznos': iznos,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      throw Exception('Greška pri ažuriranju plaćanja: $e');
    }
  }

  /// 📋 Dohvata sve aktivne mesečne putnike
  static Future<List<MesecniPutnik>> getAllActiveMesecniPutnici() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true)
          .orderBy('putnik_ime')
          .get();

      return querySnapshot.docs
          .map((doc) => MesecniPutnik.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Greška pri dohvatanju mesečnih putnika: $e');
    }
  }

  /// ➕ Dodaj novog mesečnog putnika
  static Future<MesecniPutnik> addMesecniPutnik(MesecniPutnik putnik) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();

      // Kreiranje novog mesečnog putnika - direktno iz putnik objekta
      final newPutnik = MesecniPutnik(
        id: docRef.id,
        putnikIme: putnik.putnikIme,
        brojTelefona: putnik.brojTelefona,
        tip: putnik.tip,
        polasciPoDanu: putnik.polasciPoDanu,
        datumPocetkaMeseca: putnik.datumPocetkaMeseca,
        datumKrajaMeseca: putnik.datumKrajaMeseca,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newPutnik.toMap());
      return newPutnik;
    } catch (e) {
      throw Exception('Greška pri dodavanju mesečnog putnika: $e');
    }
  }

  /// ✏️ Ažuriraj mesečnog putnika
  static Future<MesecniPutnik> updateMesecniPutnik(
      String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = FieldValue.serverTimestamp();

      final docRef = _firestore.collection(_collectionName).doc(id);
      await docRef.update(updates);

      final updatedDoc = await docRef.get();
      if (!updatedDoc.exists) {
        throw Exception('Mesečni putnik sa ID $id ne postoji');
      }

      return MesecniPutnik.fromMap(updatedDoc.data()!);
    } catch (e) {
      throw Exception('Greška pri ažuriranju mesečnog putnika: $e');
    }
  }

  /// 🗑️ Deaktiviraj mesečnog putnika (soft delete)
  static Future<void> deactivateMesecniPutnik(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'aktivan': false,
        'deaktiviran_datum': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri deaktivaciji mesečnog putnika: $e');
    }
  }

  /// 📊 Real-time stream svih aktivnih mesečnih putnika
  static Stream<List<MesecniPutnik>> getMesecniPutniciStream() {
    return _firestore.collection(_collectionName).snapshots().map(
      (snapshot) {
        final putnici = <MesecniPutnik>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final putnik = MesecniPutnik.fromMap(data);

            // Filtriranje aktivnih putnika
            if (putnik.aktivan) {
              putnici.add(putnik);
            }
          } catch (e) {
            // Ignoriši pogrešne dokumente
            continue;
          }
        }

        // Sortiraj po imenu
        putnici.sort((a, b) => a.putnikIme.compareTo(b.putnikIme));
        return putnici;
      },
    );
  }

  /// 💰 Dohvata podatke o plaćanju za putnika (iz njegovog dokumenta)
  static Future<Map<String, dynamic>?> getPlacanja(String putnikId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(putnikId).get();

      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data()!;
      return {
        'placeni_mesec': data['placeni_mesec'],
        'placena_godina': data['placena_godina'],
        'cena': data['cena'],
        'vreme_placanja': data['vreme_placanja'],
        'ukupna_cena_meseca': data['ukupna_cena_meseca'],
      };
    } catch (e) {
      throw Exception('Greška pri dohvatanju plaćanja: $e');
    }
  }
}
