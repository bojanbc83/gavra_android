import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔥 UNIFIED DATA SERVICE
/// Kompletni servis za prikazivanje svih podataka iz Firebase Firestore
/// Optimizovan za performanse sa caching i real-time updates
class UnifiedDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache za optimizaciju performansi
  static final Map<String, dynamic> _cache = {};

  /// 📊 DASHBOARD DATA - Sve ključne statistike
  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      developer.log('📊 Loading dashboard data...', name: 'UnifiedDataService');

      final futures = await Future.wait([
        _getVozaciStats(),
        _getMesecniPutniciStats(),
        _getPutovanjaStats(),
        _getFinancialStats(),
      ]);

      final dashboardData = {
        'vozaci': futures[0],
        'mesecni_putnici': futures[1],
        'putovanja': futures[2],
        'finansije': futures[3],
        'last_updated': DateTime.now().toIso8601String(),
      };

      developer.log('✅ Dashboard data loaded successfully',
          name: 'UnifiedDataService');
      return dashboardData;
    } catch (e) {
      developer.log('❌ Error loading dashboard data: $e',
          name: 'UnifiedDataService', level: 1000);
      rethrow;
    }
  }

  /// 👨‍💼 VOZACI STATISTICS
  static Future<Map<String, dynamic>> _getVozaciStats() async {
    final vozaciSnapshot = await _firestore
        .collection('vozaci')
        .where('aktivan', isEqualTo: true)
        .get();

    final vozaci = vozaciSnapshot.docs;
    double totalEarnings = 0;
    int totalPutovanja = 0;
    int totalPutnici = 0;

    for (final doc in vozaci) {
      final data = doc.data();
      totalEarnings += (data['total_earnings'] as num?)?.toDouble() ?? 0;
      totalPutovanja += (data['putovanja_count'] as int?) ?? 0;
      totalPutnici += (data['putnici_count'] as int?) ?? 0;
    }

    return {
      'ukupno_vozaca': vozaci.length,
      'ukupna_zarada': totalEarnings,
      'ukupno_putovanja': totalPutovanja,
      'ukupno_putnika': totalPutnici,
      'vozaci_lista': vozaci
          .map((doc) => {
                'id': doc.id,
                'ime': doc.data()['ime'] ?? '',
                'total_earnings': doc.data()['total_earnings'] ?? 0,
                'putovanja_count': doc.data()['putovanja_count'] ?? 0,
              })
          .toList(),
    };
  }

  /// 👥 MESECNI PUTNICI STATISTICS
  static Future<Map<String, dynamic>> _getMesecniPutniciStats() async {
    final putniciSnapshot = await _firestore
        .collection('mesecni_putnici')
        .where('aktivan', isEqualTo: true)
        .get();

    final putnici = putniciSnapshot.docs;

    // Group by tip (učenik/radnik)
    final tipStats = <String, int>{};
    final skolaStats = <String, int>{};
    double totalMesecneKarte = 0;

    for (final doc in putnici) {
      final data = doc.data();
      final tip = data['tip'] as String? ?? 'unknown';
      final tipSkole = data['tip_skole'] as String? ?? '';
      final cena = (data['cena'] as num?)?.toDouble() ?? 0;

      tipStats[tip] = (tipStats[tip] ?? 0) + 1;
      if (tipSkole.isNotEmpty) {
        skolaStats[tipSkole] = (skolaStats[tipSkole] ?? 0) + 1;
      }
      totalMesecneKarte += cena;
    }

    return {
      'ukupno_putnika': putnici.length,
      'tip_statistike': tipStats,
      'skola_statistike': skolaStats,
      'ukupna_vrednost_mesecnih_karata': totalMesecneKarte,
      'prosecna_cena_karte':
          putnici.isNotEmpty ? totalMesecneKarte / putnici.length : 0,
    };
  }

  /// 🚌 PUTOVANJA STATISTICS
  static Future<Map<String, dynamic>> _getPutovanjaStats() async {
    final currentMonth =
        DateTime.now().toIso8601String().substring(0, 7); // YYYY-MM

    final putovanjaSnapshot = await _firestore
        .collection('putovanja_istorija')
        .where('datum_putovanja', isGreaterThanOrEqualTo: '$currentMonth-01')
        .where('datum_putovanja', isLessThan: '$currentMonth-32')
        .get();

    final putovanja = putovanjaSnapshot.docs;
    double totalZarada = 0;
    final statusStats = <String, int>{};
    final dailyStats = <String, double>{};

    for (final doc in putovanja) {
      final data = doc.data();
      final cena = (data['cena'] as num?)?.toDouble() ?? 0;
      final status = data['status'] as String? ?? 'unknown';
      final datum = data['datum_putovanja'] as String? ?? '';

      totalZarada += cena;
      statusStats[status] = (statusStats[status] ?? 0) + 1;

      if (datum.isNotEmpty) {
        dailyStats[datum] = (dailyStats[datum] ?? 0) + cena;
      }
    }

    // Get last 7 days for trend
    final last7Days = <String, double>{};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date =
          now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      last7Days[date] = dailyStats[date] ?? 0;
    }

    return {
      'ukupno_putovanja_mesec': putovanja.length,
      'ukupna_zarada_mesec': totalZarada,
      'prosecna_zarada_po_putovanju':
          putovanja.isNotEmpty ? totalZarada / putovanja.length : 0,
      'status_statistike': statusStats,
      'poslednih_7_dana': last7Days,
      'trenutni_mesec': currentMonth,
    };
  }

  /// 💰 FINANCIAL STATISTICS
  static Future<Map<String, dynamic>> _getFinancialStats() async {
    // Get all time financial data
    final putovanjaSnapshot = await _firestore
        .collection('putovanja_istorija')
        .where('status', isEqualTo: 'placeno')
        .get();

    final putovanja = putovanjaSnapshot.docs;
    double ukupnaZarada = 0;
    final mesecnaZarada = <String, double>{};
    final vozacZarada = <String, double>{};

    for (final doc in putovanja) {
      final data = doc.data();
      final cena = (data['cena'] as num?)?.toDouble() ?? 0;
      final datum = data['datum_putovanja'] as String? ?? '';
      final mesec = datum.length >= 7 ? datum.substring(0, 7) : '';
      final vozacIme = data['vozac_ime'] as String? ?? 'Unknown';

      ukupnaZarada += cena;

      if (mesec.isNotEmpty) {
        mesecnaZarada[mesec] = (mesecnaZarada[mesec] ?? 0) + cena;
      }

      vozacZarada[vozacIme] = (vozacZarada[vozacIme] ?? 0) + cena;
    }

    // Get current month vs previous month
    final now = DateTime.now();
    final currentMonth = now.toIso8601String().substring(0, 7);
    final previousMonth =
        DateTime(now.year, now.month - 1).toIso8601String().substring(0, 7);

    return {
      'ukupna_zarada_sva_vremena': ukupnaZarada,
      'ukupno_placenih_putovanja': putovanja.length,
      'prosecna_zarada_po_putovanju':
          putovanja.isNotEmpty ? ukupnaZarada / putovanja.length : 0,
      'trenutni_mesec_zarada': mesecnaZarada[currentMonth] ?? 0,
      'prethodni_mesec_zarada': mesecnaZarada[previousMonth] ?? 0,
      'zarada_po_vozacima': vozacZarada,
      'mesecna_zarada_trend': mesecnaZarada,
      'valuta': 'RSD',
    };
  }

  /// 📱 GET FORMATTED DATA FOR UI
  static Future<Map<String, dynamic>> getFormattedDashboardData() async {
    final rawData = await getDashboardData();

    return {
      'cards': [
        {
          'title': 'Vozači',
          'value': rawData['vozaci']['ukupno_vozaca'].toString(),
          'subtitle': 'Aktivnih vozača',
          'icon': '👨‍💼',
          'color': 'blue',
        },
        {
          'title': 'Putnici',
          'value': rawData['mesecni_putnici']['ukupno_putnika'].toString(),
          'subtitle': 'Mesečnih putnika',
          'icon': '👥',
          'color': 'green',
        },
        {
          'title': 'Zarada (mesec)',
          'value': _formatCurrency(
              (rawData['putovanja']['ukupna_zarada_mesec'] as num?)
                      ?.toDouble() ??
                  0),
          'subtitle': 'RSD ovaj mesec',
          'icon': '💰',
          'color': 'orange',
        },
        {
          'title': 'Putovanja (mesec)',
          'value': rawData['putovanja']['ukupno_putovanja_mesec'].toString(),
          'subtitle': 'Ovaj mesec',
          'icon': '🚌',
          'color': 'purple',
        },
      ],
      'charts': {
        'daily_earnings': rawData['putovanja']['poslednih_7_dana'],
        'passenger_types': rawData['mesecni_putnici']['tip_statistike'],
        'driver_earnings': rawData['finansije']['zarada_po_vozacima'],
      },
      'summary': {
        'total_all_time': _formatCurrency(
            (rawData['finansije']['ukupna_zarada_sva_vremena'] as num?)
                    ?.toDouble() ??
                0),
        'average_per_trip': _formatCurrency(
            (rawData['finansije']['prosecna_zarada_po_putovanju'] as num?)
                    ?.toDouble() ??
                0),
        'monthly_cards_value': _formatCurrency((rawData['mesecni_putnici']
                    ['ukupna_vrednost_mesecnih_karata'] as num?)
                ?.toDouble() ??
            0),
      }
    };
  }

  /// 🔍 SEARCH FUNCTIONALITY
  static Future<List<Map<String, dynamic>>> searchAll(String query) async {
    if (query.isEmpty) return [];

    final searchTerms = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    try {
      // Search mesecni_putnici
      final putniciQuery = await _firestore
          .collection('mesecni_putnici')
          .where('search_terms',
              isGreaterThanOrEqualTo: searchTerms.toLowerCase())
          .where('search_terms',
              isLessThanOrEqualTo: '${searchTerms.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      for (final doc in putniciQuery.docs) {
        results.add({
          'type': 'putnik',
          'id': doc.id,
          'title': doc.data()['putnik_ime'] ?? '',
          'subtitle': '${doc.data()['tip']} - ${doc.data()['tip_skole'] ?? ''}',
          'data': doc.data(),
        });
      }

      // Search vozaci
      final vozaciQuery = await _firestore
          .collection('vozaci')
          .where('search_terms',
              isGreaterThanOrEqualTo: searchTerms.toLowerCase())
          .where('search_terms',
              isLessThanOrEqualTo: '${searchTerms.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      for (final doc in vozaciQuery.docs) {
        results.add({
          'type': 'vozac',
          'id': doc.id,
          'title': doc.data()['ime'] ?? '',
          'subtitle':
              'Vozač - ${_formatCurrency((doc.data()['total_earnings'] as num?)?.toDouble() ?? 0)} zarada',
          'data': doc.data(),
        });
      }

      return results;
    } catch (e) {
      developer.log('❌ Search error: $e',
          name: 'UnifiedDataService', level: 1000);
      return [];
    }
  }

  /// 📊 REAL-TIME LISTENERS
  static Stream<Map<String, dynamic>> getDashboardStream() {
    return Stream<Map<String, dynamic>>.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getDashboardData());
  }

  static Stream<List<Map<String, dynamic>>> getMesecniPutniciStream() {
    return _firestore
        .collection('mesecni_putnici')
        .where('aktivan', isEqualTo: true)
        .orderBy('putnik_ime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getVozaciStream() {
    return _firestore
        .collection('vozaci')
        .where('aktivan', isEqualTo: true)
        .orderBy('ime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// 💱 CURRENCY FORMATTING
  static String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  /// 🧹 CACHE MANAGEMENT
  static void clearCache() {
    _cache.clear();
  }

  /// 📈 ANALYTICS HELPERS
  static Future<Map<String, dynamic>> getMonthlyAnalytics(String month) async {
    final putovanjaSnapshot = await _firestore
        .collection('putovanja_istorija')
        .where('datum_putovanja', isGreaterThanOrEqualTo: '$month-01')
        .where('datum_putovanja', isLessThan: '$month-32')
        .get();

    final putovanja = putovanjaSnapshot.docs;
    double totalRevenue = 0;
    final dailyData = <String, Map<String, dynamic>>{};

    for (final doc in putovanja) {
      final data = doc.data();
      final datum = data['datum_putovanja'] as String? ?? '';
      final cena = (data['cena'] as num?)?.toDouble() ?? 0;

      totalRevenue += cena;

      if (dailyData[datum] == null) {
        dailyData[datum] = {'putovanja': 0, 'zarada': 0.0};
      }

      dailyData[datum]!['putovanja'] += 1;
      dailyData[datum]!['zarada'] += cena;
    }

    return {
      'mesec': month,
      'ukupno_putovanja': putovanja.length,
      'ukupna_zarada': totalRevenue,
      'prosecna_dnevna_zarada':
          dailyData.isNotEmpty ? totalRevenue / dailyData.length : 0,
      'dnevni_podaci': dailyData,
    };
  }
}
