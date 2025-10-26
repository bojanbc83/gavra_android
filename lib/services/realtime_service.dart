import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dnevni_putnik.dart';
import '../models/putnik.dart';

/// 🔥 FIREBASE REALTIME SERVICE
class RealtimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static CollectionReference get _putnici => _firestore.collection('putnici');
  static CollectionReference get _dnevniPutnici =>
      _firestore.collection('dnevni_putnici');

  /// Stream dnevnih putnika u realtime
  static Stream<List<DnevniPutnik>> dnevniPutniciStream([DateTime? datum]) {
    try {
      final targetDate = datum ?? DateTime.now();
      final dayStart =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      return _dnevniPutnici
          .where('datum', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('datum', isLessThan: Timestamp.fromDate(dayEnd))
          .orderBy('datum', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return DnevniPutnik.fromJson({...data, 'id': doc.id});
        }).toList();
      });
    } catch (e) {
      developer.log('RealtimeService.dnevniPutniciStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value([]);
    }
  }

  /// Stream svih putnika u realtime
  static Stream<List<Putnik>> putniciStream() {
    try {
      return _putnici.orderBy('ime').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Putnik.fromJson({...data, 'id': doc.id});
        }).toList();
      });
    } catch (e) {
      developer.log('RealtimeService.putniciStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value([]);
    }
  }

  /// Stream putnika sa dugovima u realtime
  static Stream<List<Putnik>> putniciSaDugovimStream() {
    try {
      return _putnici
          .where('duguje', isGreaterThan: 0)
          .orderBy('duguje', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Putnik.fromJson({...data, 'id': doc.id});
        }).toList();
      });
    } catch (e) {
      developer.log('RealtimeService.putniciSaDugovimStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value([]);
    }
  }

  /// Stream statistika danas u realtime
  static Stream<Map<String, dynamic>> statistikaDanasStream() {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      return _dnevniPutnici
          .where('datum',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('datum', isLessThan: Timestamp.fromDate(todayEnd))
          .snapshots()
          .map((snapshot) {
        int ukupnoPutnika = snapshot.docs.length;
        double ukupnaZarada = 0.0;
        Map<String, int> putniciPoLiniji = {};

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final dnevniPutnik = DnevniPutnik.fromJson(data);

          ukupnaZarada += dnevniPutnik.cena;

          String linija = dnevniPutnik.rutaId.isNotEmpty
              ? dnevniPutnik.rutaId
              : 'Nepoznata linija';
          putniciPoLiniji[linija] = (putniciPoLiniji[linija] ?? 0) + 1;
        }

        return {
          'ukupno_putnika': ukupnoPutnika,
          'ukupna_zarada': ukupnaZarada,
          'putnici_po_liniji': putniciPoLiniji,
          'poslednje_azuriranje': DateTime.now(),
        };
      });
    } catch (e) {
      developer.log('RealtimeService.statistikaDanasStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value({
        'ukupno_putnika': 0,
        'ukupna_zarada': 0.0,
        'putnici_po_liniji': <String, int>{},
        'poslednje_azuriranje': DateTime.now(),
      });
    }
  }

  /// Subscribe na promene određenog putnika
  static Stream<Putnik?> putnikStream(String putnikId) {
    try {
      return _putnici.doc(putnikId).snapshots().map((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          return Putnik.fromJson({...data, 'id': snapshot.id});
        }
        return null;
      });
    } catch (e) {
      developer.log('RealtimeService.putnikStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value(null);
    }
  }

  /// Subscribe na promene određenog dnevnog putnika
  static Stream<DnevniPutnik?> dnevniPutnikStream(String dnevniPutnikId) {
    try {
      return _dnevniPutnici.doc(dnevniPutnikId).snapshots().map((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          return DnevniPutnik.fromJson({...data, 'id': snapshot.id});
        }
        return null;
      });
    } catch (e) {
      developer.log('RealtimeService.dnevniPutnikStream: $e',
          name: 'RealtimeService', level: 1000);
      return Stream.value(null);
    }
  }

  /// Cleanup - dispose svih stream-ova
  static void dispose() {
    // Firebase streams se automatski cleanup-uju kada se ne koriste
    developer.log('RealtimeService.dispose: Firebase streams cleaned up',
        name: 'RealtimeService');
  }
}
