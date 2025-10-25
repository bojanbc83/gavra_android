import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dnevni_putnik.dart';
import '../models/mesecni_putnik.dart';

/// 🔥 GAVRA 013 - PUTNIK SERVICE (FIREBASE)
///
/// Migrirano sa Supabase na Firebase Firestore
/// Upravlja mesečnim i dnevnim putnicima

class PutnikService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🎫 Označi putnika kao pokupljenog
  Future<void> oznaciPokupljen(String putnikId, String vozacId) async {
    try {
      // Pokušaj u mesečnim putnicima
      final mesecniDoc =
          await _firestore.collection('mesecni_putnici').doc(putnikId).get();

      if (mesecniDoc.exists) {
        await mesecniDoc.reference.update({
          'pokupljen': true,
          'vreme_pokupljanja': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Pokušaj u dnevnim putnicima
      final dnevniDoc =
          await _firestore.collection('dnevni_putnici').doc(putnikId).get();

      if (dnevniDoc.exists) {
        await dnevniDoc.reference.update({
          'pokupljen': true,
          'vreme_pokupljanja': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        return;
      }

      throw Exception('Putnik sa ID $putnikId nije pronađen');
    } catch (e) {
      throw Exception('Greška pri označavanju pokupljanja: $e');
    }
  }

  /// 🔍 Dohvata putnika iz bilo koje tabele
  Future<dynamic> getPutnikFromAnyTable(String putnikId) async {
    try {
      // Pokušaj u mesečnim putnicima
      final mesecniDoc =
          await _firestore.collection('mesecni_putnici').doc(putnikId).get();

      if (mesecniDoc.exists) {
        return MesecniPutnik.fromMap(mesecniDoc.data()!);
      }

      // Pokušaj u dnevnim putnicima
      final dnevniDoc =
          await _firestore.collection('dnevni_putnici').doc(putnikId).get();

      if (dnevniDoc.exists) {
        return DnevniPutnik.fromMap(dnevniDoc.data()!);
      }

      return null;
    } catch (e) {
      throw Exception('Greška pri dohvatanju putnika: $e');
    }
  }

  /// 🔄 Resetuj putničku kartu (označava kao nepokupljen)
  Future<void> resetPutnikCard(String ime, String vozacId) async {
    try {
      // Reset u mesečnim putnicima
      final mesecniQuery = await _firestore
          .collection('mesecni_putnici')
          .where('ime_prezime', isEqualTo: ime)
          .where('vozac_id', isEqualTo: vozacId)
          .get();

      for (final doc in mesecniQuery.docs) {
        await doc.reference.update({
          'pokupljen': false,
          'vreme_pokupljanja': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Reset u dnevnim putnicima
      final dnevniQuery = await _firestore
          .collection('dnevni_putnici')
          .where('ime_prezime', isEqualTo: ime)
          .where('vozac_id', isEqualTo: vozacId)
          .get();

      for (final doc in dnevniQuery.docs) {
        await doc.reference.update({
          'pokupljen': false,
          'vreme_pokupljanja': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Greška pri resetovanju putničke karte: $e');
    }
  }

  /// 🔍 Dohvata putnika po imenu (first match)
  Future<dynamic> getPutnikByName(String ime) async {
    try {
      // Pokušaj u mesečnim putnicima
      final mesecniQuery = await _firestore
          .collection('mesecni_putnici')
          .where('ime_prezime', isEqualTo: ime)
          .where('aktivan', isEqualTo: true)
          .limit(1)
          .get();

      if (mesecniQuery.docs.isNotEmpty) {
        return MesecniPutnik.fromMap(mesecniQuery.docs.first.data());
      }

      // Pokušaj u dnevnim putnicima
      final dnevniQuery = await _firestore
          .collection('dnevni_putnici')
          .where('ime_prezime', isEqualTo: ime)
          .limit(1)
          .get();

      if (dnevniQuery.docs.isNotEmpty) {
        return DnevniPutnik.fromMap(dnevniQuery.docs.first.data());
      }

      return null;
    } catch (e) {
      throw Exception('Greška pri dohvatanju putnika po imenu: $e');
    }
  }

  /// 💰 Označi putnika kao plaćenog
  Future<void> oznaciPlaceno(
      String putnikId, String vozacId, double iznos) async {
    try {
      final putnik = await getPutnikFromAnyTable(putnikId);
      if (putnik == null) {
        throw Exception('Putnik sa ID $putnikId nije pronađen');
      }

      // Određi kolekciju na osnovu tipa putnika
      final kolekcija =
          putnik is MesecniPutnik ? 'mesecni_putnici' : 'dnevni_putnici';

      await _firestore.collection(kolekcija).doc(putnikId).update({
        'placeno': true,
        'iznos_placanja': iznos,
        'vreme_placanja': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri označavanju plaćanja: $e');
    }
  }

  /// 🏥 Označi bolovanje/godišnji
  Future<void> oznaciBolovanjeGodisnji(
      String putnikId, String status, String vozacId) async {
    try {
      final putnik = await getPutnikFromAnyTable(putnikId);
      if (putnik == null) {
        throw Exception('Putnik sa ID $putnikId nije pronađen');
      }

      final kolekcija =
          putnik is MesecniPutnik ? 'mesecni_putnici' : 'dnevni_putnici';

      await _firestore.collection(kolekcija).doc(putnikId).update({
        'status': status, // 'bolovanje' ili 'godisnji'
        'datum_statusa': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri označavanju statusa: $e');
    }
  }

  /// ❌ Otkaži putnika
  Future<void> otkaziPutnika(String putnikId, String razlog) async {
    try {
      final putnik = await getPutnikFromAnyTable(putnikId);
      if (putnik == null) {
        throw Exception('Putnik sa ID $putnikId nije pronađen');
      }

      final kolekcija =
          putnik is MesecniPutnik ? 'mesecni_putnici' : 'dnevni_putnici';

      await _firestore.collection(kolekcija).doc(putnikId).update({
        'otkazan': true,
        'razlog_otkazivanja': razlog,
        'datum_otkazivanja': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri otkazivanju putnika: $e');
    }
  }

  /// 🗑️ Obriši putnika (soft delete)
  Future<void> obrisiPutnika(String putnikId) async {
    try {
      final putnik = await getPutnikFromAnyTable(putnikId);
      if (putnik == null) {
        throw Exception('Putnik sa ID $putnikId nije pronađen');
      }

      final kolekcija =
          putnik is MesecniPutnik ? 'mesecni_putnici' : 'dnevni_putnici';

      await _firestore.collection(kolekcija).doc(putnikId).update({
        'aktivan': false,
        'obrisan': true,
        'datum_brisanja': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri brisanju putnika: $e');
    }
  }

  /// 📊 Dohvata sve putnike po vozaču
  Future<Map<String, List<dynamic>>> getPutniciByVozac(String vozacId) async {
    try {
      // Dohvati mesečne putnike
      final mesecniQuery = await _firestore
          .collection('mesecni_putnici')
          .where('vozac_id', isEqualTo: vozacId)
          .where('aktivan', isEqualTo: true)
          .get();

      final mesecniPutnici = mesecniQuery.docs
          .map((doc) => MesecniPutnik.fromMap(doc.data()))
          .toList();

      // Dohvati dnevne putnike (za danas)
      final danas = DateTime.now();
      final pocetakDana = DateTime(danas.year, danas.month, danas.day);
      final krajDana = pocetakDana.add(const Duration(days: 1));

      final dnevniQuery = await _firestore
          .collection('dnevni_putnici')
          .where('vozac_id', isEqualTo: vozacId)
          .where('datum_polaska',
              isGreaterThanOrEqualTo: Timestamp.fromDate(pocetakDana))
          .where('datum_polaska', isLessThan: Timestamp.fromDate(krajDana))
          .get();

      final dnevniPutnici = dnevniQuery.docs
          .map((doc) => DnevniPutnik.fromMap(doc.data()))
          .toList();

      return {
        'mesecni': mesecniPutnici,
        'dnevni': dnevniPutnici,
      };
    } catch (e) {
      throw Exception('Greška pri dohvatanju putnika po vozaču: $e');
    }
  }
}
