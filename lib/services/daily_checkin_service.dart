import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 📅 DAILY CHECK-IN SERVICE - SharedPreferences implementacija
class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';
  static const String _reportPrefix = 'daily_report_';

  /// 📡 STREAM ZA PRAĆENJE KUSURA
  static Stream<double> streamTodayAmount(String vozac) async* {
    // Prvo pošalji trenutnu vrednost
    final current = await getTodayAmount(vozac);
    yield current;

    // Zatim posmatraj promene svake sekunde
    yield* Stream.periodic(const Duration(seconds: 1), (_) async {
      return await getTodayAmount(vozac);
    }).asyncMap((future) => future);
  }

  /// 💾 SAČUVAJ CHECK-IN
  static Future<void> saveCheckIn(String vozac, double iznos,
      {double dnevniPazari = 0.0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final key = '$_checkInPrefix${vozac}_$dateKey';

      final data = {
        'vozac': vozac,
        'datum': dateKey,
        'sitan_novac': iznos,
        'dnevni_pazari': dnevniPazari,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(key, json.encode(data));

      // Takođe sačuvaj kao "today" za brži pristup
      final todayKey = '${_checkInPrefix}today_$vozac';
      await prefs.setString(todayKey, json.encode(data));
    } catch (e) {
      throw Exception('Greška pri čuvanju check-in-a: $e');
    }
  }

  /// 📊 DOBIJ DANAŠNJI CHECK-IN
  static Future<Map<String, dynamic>?> getTodayCheckIn(String vozac) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = '${_checkInPrefix}today_$vozac';
      final dataStr = prefs.getString(todayKey);

      if (dataStr != null) {
        final data = json.decode(dataStr) as Map<String, dynamic>;
        final timestamp = DateTime.parse(data['timestamp'] as String);
        final today = DateTime.now();

        // Proveri da li je stvarno iz danas
        if (timestamp.year == today.year &&
            timestamp.month == today.month &&
            timestamp.day == today.day) {
          return data;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 💰 DOBIJ IZNOS ZA DANAS
  static Future<double> getTodayAmount(String vozac) async {
    try {
      final data = await getTodayCheckIn(vozac);
      if (data == null) return 0.0;

      final amount = data['sitan_novac'];
      if (amount is num) return amount.toDouble();
      if (amount is String) return double.tryParse(amount) ?? 0.0;
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// ✅ PROVERI DA LI JE URADIO CHECK-IN DANAS
  static Future<bool> hasCheckedInToday(String vozac) async {
    final data = await getTodayCheckIn(vozac);
    return data != null;
  }

  /// 📊 DOBIJ POSLEDNJI DAILY REPORT
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('${_reportPrefix}$vozac'))
          .toList();

      if (keys.isEmpty) return null;

      // Sortiraj po datumu i uzmi najnoviji
      keys.sort((a, b) => b.compareTo(a));
      final latestKey = keys.first;
      final dataStr = prefs.getString(latestKey);

      if (dataStr != null) {
        return json.decode(dataStr) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🤖 GENERIŠI AUTOMATSKI REPORT
  static Future<Map<String, dynamic>?> generateAutomaticReport(
      String vozac, DateTime targetDate) async {
    try {
      // Generiši simulirani report za test
      final report = {
        'datum': targetDate.toIso8601String().split('T')[0],
        'vozac': vozac,
        'tip': 'automatski',
        'ukupanPazar': 15000.0 + (vozac.hashCode % 5000), // Simulacija
        'dodatiPutnici': 8 + (vozac.hashCode % 5),
        'pokupljeniPutnici': 7 + (vozac.hashCode % 4),
        'naplaceniPutnici': 6 + (vozac.hashCode % 3),
        'otkazaniPutnici': 1 + (vozac.hashCode % 2),
        'dugoviPutnici': vozac.hashCode % 3,
        'mesecneKarte': 2 + (vozac.hashCode % 4),
        'kilometraza': 85.0 + (vozac.hashCode % 20),
        'sitanNovac': 2000.0 + (vozac.hashCode % 1000),
        'generated_at': DateTime.now().toIso8601String(),
      };

      return report;
    } catch (e) {
      return null;
    }
  }

  /// 💾 SAČUVAJ DAILY REPORT
  static Future<void> saveDailyReport(
      String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey =
          '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
      final key = '$_reportPrefix${vozac}_$dateKey';

      podaci['saved_at'] = DateTime.now().toIso8601String();
      await prefs.setString(key, json.encode(podaci));
    } catch (e) {
      throw Exception('Greška pri čuvanju daily report-a: $e');
    }
  }

  /// 🔗 REALTIME LISTENER (placeholder)
  static dynamic initializeRealtimeForDriver(String vozac) {
    // Za sada vraća null jer koristimo SharedPreferences
    return null;
  }
}
