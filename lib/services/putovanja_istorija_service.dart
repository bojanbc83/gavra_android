import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/putovanja_istorija.dart';

/// 🔥 GAVRA 013 - PUTOVANJA ISTORIJA SERVICE (FIREBASE)
///
/// Upravlja istorijom putovanja (plaćanja, statistike, otkazivanja)
///
class PutovanjaIstorijaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'putovanja_istorija';

  /// 📊 Dohvata statistike putovanja za putnika po ID
  ///
  /// [putnikId] - ID mesečnog putnika
  /// [startDate] - početni datum (opciono)
  /// [endDate] - krajnji datum (opciono)
  ///
  static Future<Map<String, dynamic>> getStatistikePutnikId(
    String putnikId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collectionName)
          .where('mesecni_putnik_id', isEqualTo: putnikId)
          .where('obrisan', isEqualTo: false);

      // Dodaj datum filtriranje ako je zadato
      if (startDate != null) {
        query = query.where('datum_putovanja',
            isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.where('datum_putovanja',
            isLessThanOrEqualTo: endDate.toIso8601String().split('T')[0]);
      }

      final querySnapshot =
          await query.orderBy('datum_putovanja', descending: true).get();

      int ukupnaPutovanja = 0;
      int otkazivanja = 0;
      double ukupanPrihod = 0;
      String? poslednjePutovanje;

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        final cena = (data['cena'] as num?)?.toDouble() ?? 0;
        final datum = data['datum_putovanja'] as String?;

        ukupnaPutovanja++;

        if (status == 'otkazan' || status == 'nije_se_pojavio') {
          otkazivanja++;
        }

        if (status == 'placeno' && cena > 0) {
          ukupanPrihod += cena;
        }

        // Prva iteracija je poslednje putovanje (zbog descending sort)
        if (poslednjePutovanje == null && datum != null) {
          poslednjePutovanje = datum;
        }
      }

      return {
        'putovanja': ukupnaPutovanja,
        'otkazivanja': otkazivanja,
        'ukupan_prihod': '${ukupanPrihod.toStringAsFixed(0)} RSD',
        'poslednje_putovanje': poslednjePutovanje,
        'uspesnost': ukupnaPutovanja > 0
            ? ((ukupnaPutovanja - otkazivanja) / ukupnaPutovanja * 100).round()
            : 0,
      };
    } catch (e) {
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'ukupan_prihod': '0 RSD',
        'poslednje_putovanje': null,
        'uspesnost': 0,
        'error': true,
      };
    }
  }

  /// 📅 Dohvata statistike za određenu godinu
  static Future<Map<String, dynamic>> getGodisnjeStatistike(
    String putnikId,
    int godina,
  ) async {
    final startOfYear = DateTime(godina, 1, 1);
    final endOfYear = DateTime(godina, 12, 31);

    return getStatistikePutnikId(putnikId,
        startDate: startOfYear, endDate: endOfYear);
  }

  /// 📊 Dohvata ukupne statistike (sve godine)
  static Future<Map<String, dynamic>> getUkupneStatistike(
      String putnikId) async {
    return await getStatistikePutnikId(putnikId);
  }

  /// 📆 Dohvata putovanja za određeni mesec i godinu
  static Future<List<String>> getPutovanjaZaMesec(
    String putnikId,
    int mesec,
    int godina,
  ) async {
    try {
      final startOfMonth = DateTime(godina, mesec, 1);
      final endOfMonth = DateTime(godina, mesec + 1, 0); // Poslednji dan meseca

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mesecni_putnik_id', isEqualTo: putnikId)
          .where('obrisan', isEqualTo: false)
          .where('datum_putovanja',
              isGreaterThanOrEqualTo:
                  startOfMonth.toIso8601String().split('T')[0])
          .where('datum_putovanja',
              isLessThanOrEqualTo: endOfMonth.toIso8601String().split('T')[0])
          .orderBy('datum_putovanja')
          .get();

      List<String> uspesniDatumi = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final datum = data['datum_putovanja'] as String?;

        if (datum != null && (status == 'placeno' || status == 'pokupljen')) {
          uspesniDatumi.add(datum);
        }
      }

      return uspesniDatumi;
    } catch (e) {
      return [];
    }
  }

  /// 🔍 Dohvata sva putovanja za putnika
  static Future<List<PutovanjaIstorija>> getPutovanjaZaPutnika(
      String putnikId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mesecni_putnik_id', isEqualTo: putnikId)
          .where('obrisan', isEqualTo: false)
          .orderBy('datum_putovanja', descending: true)
          .limit(100) // Ograniči na 100 najnovijih
          .get();

      return querySnapshot.docs
          .map((doc) => PutovanjaIstorija.fromMap({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 📋 Stream svih putovanja (realtime)
  static Stream<List<PutovanjaIstorija>> getPutovanjaStream({
    String? vozacId,
    DateTime? datum,
  }) {
    Query query = _firestore
        .collection(_collectionName)
        .where('obrisan', isEqualTo: false);

    if (vozacId != null) {
      query = query.where('vozac_id', isEqualTo: vozacId);
    }

    if (datum != null) {
      final datumString = datum.toIso8601String().split('T')[0];
      query = query.where('datum_putovanja', isEqualTo: datumString);
    }

    return query
        .orderBy('datum_putovanja', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PutovanjaIstorija.fromMap({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                }))
            .toList());
  }
}
