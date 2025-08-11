import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/putnik.dart';
// import 'firebase_service.dart';
import 'package:flutter/foundation.dart';

class SMSService {
  static Timer? _monthlyTimer;
  static bool _isServiceRunning = false;
  static final supabase = Supabase.instance.client;

  /// Pokretanje automatskog SMS servisa
  static void startAutomaticSMSService() {
    if (_isServiceRunning) return;

    _isServiceRunning = true;
    debugPrint(
        '🚀 SMS servis pokrenult - automatsko slanje predzadnjeg dana u mesecu u 20:00');

    // Provera svakih sat vremena
    _monthlyTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkAndSendMonthlySMS();
    });
  }

  /// Zaustavljanje automatskog SMS servisa
  static void stopAutomaticSMSService() {
    _monthlyTimer?.cancel();
    _monthlyTimer = null;
    _isServiceRunning = false;
    debugPrint('🛑 SMS servis zaustavljen');
  }

  /// Provera da li je vreme za slanje SMS-a
  static Future<void> _checkAndSendMonthlySMS() async {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);

    // Proverava da li je predzadnji dan u 20:00
    if (now.day == secondToLastDay.day &&
        now.hour == 20 &&
        now.minute >= 0 &&
        now.minute < 5) {
      // 5-minutni prozor

      debugPrint('📅 Predzadnji dan meseca u 20:00 - šaljem SMS poruke...');
      await sendSMSToUnpaidMonthlyPassengers();
    }
  }

  /// Računa predzadnji dan meseca
  static DateTime _getSecondToLastDayOfMonth(DateTime date) {
    // Poslednji dan meseca
    DateTime lastDay = DateTime(date.year, date.month + 1, 0);
    // Predzadnji dan meseca
    return lastDay.subtract(const Duration(days: 1));
  }

  /// Šalje SMS svim neplaćenim mesečnim putnicima
  static Future<void> sendSMSToUnpaidMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        debugPrint(
            '🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver');
        return;
      }

      debugPrint(
          '📱 Učitavam neplaćene mesečne putnike... (Vozač: $currentDriver)');

      // Učitaj sve mesečne putnike kojima ističe karta sutra
      DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
      String tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

      final response = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('mesecna_karta_do', tomorrowStr);

      List<Putnik> unpaidPassengers = (response as List)
          .map((data) => Putnik.fromMesecniPutnici(data))
          .where((putnik) =>
              putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty)
          .toList();

      debugPrint(
          '📋 Pronađeno ${unpaidPassengers.length} putnika kojima ističe karta sutra');

      int successCount = 0;
      int errorCount = 0;

      for (Putnik putnik in unpaidPassengers) {
        try {
          // Dobij statistike putovanja za putnika
          Map<String, dynamic> stats = await _getPaymentStats(putnik.id!);

          // Kreiraj SMS poruku
          String message = _createReminderSMS(
              putnik.ime,
              stats['lastPaymentDate'],
              stats['lastPaymentAmount'],
              stats['tripsSincePayment'],
              stats['cancellationsSincePayment']);

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;

          debugPrint('✅ SMS poslat: ${putnik.ime} (${putnik.brojTelefona})');

          // Pauza između SMS-ova (da se izbegne spam)
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          debugPrint('❌ Greška slanja SMS: ${putnik.ime} - $e');
        }
      }

      debugPrint('📊 SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      debugPrint('💥 Greška u SMS servisu: $e');
    }
  }

  /// Dobijanje statistika plaćanja za putnika
  static Future<Map<String, dynamic>> _getPaymentStats(String putnikId) async {
    try {
      // 1. Poslednja uplata
      final lastPaymentResponse = await supabase
          .from('putovanja_istorija')
          .select('datum_i_vreme, iznos_uplate')
          .eq('putnik_id', putnikId)
          .gt('iznos_uplate', 0)
          .order('datum_i_vreme', ascending: false)
          .limit(1);

      if (lastPaymentResponse.isEmpty) {
        return {
          'lastPaymentDate': 'Nema podataka',
          'lastPaymentAmount': 0,
          'tripsSincePayment': 0,
          'cancellationsSincePayment': 0,
        };
      }

      String lastPaymentDate = lastPaymentResponse[0]['datum_i_vreme'];
      int lastPaymentAmount = lastPaymentResponse[0]['iznos_uplate'];

      // 2. Putovanja od poslednje uplate
      final tripsResponse = await supabase
          .from('putovanja_istorija')
          .select('tip_promene')
          .eq('putnik_id', putnikId)
          .gte('datum_i_vreme', lastPaymentDate);

      // Brojanje putovanja i otkazivanja
      int putovanja =
          tripsResponse.where((t) => t['tip_promene'] == 'putovanje').length;

      int otkazivanja =
          tripsResponse.where((t) => t['tip_promene'] == 'otkazano').length;

      // Formatiranje datuma
      DateTime date = DateTime.parse(lastPaymentDate);
      String formattedDate = DateFormat('dd.MM.yyyy').format(date);

      return {
        'lastPaymentDate': formattedDate,
        'lastPaymentAmount': lastPaymentAmount,
        'tripsSincePayment': putovanja,
        'cancellationsSincePayment': otkazivanja,
      };
    } catch (e) {
      debugPrint('⚠️ Greška dobijanja statistika za putnika $putnikId: $e');
      return {
        'lastPaymentDate': 'Greška',
        'lastPaymentAmount': 0,
        'tripsSincePayment': 0,
        'cancellationsSincePayment': 0,
      };
    }
  }

  /// Kreiranje SMS poruke sa Gavra 013 potpisom
  static String _createReminderSMS(
    String ime,
    String datum,
    int iznos,
    int putovanja,
    int otkazivanja,
  ) {
    return "Poštovani $ime, mesečna karta ističe sutra.\n"
        "Poslednja uplata: $datum - $iznos RSD\n"
        "Od tada: $putovanja putovanja, $otkazivanja otkazivanja\n\n"
        "S pozdravom,\n"
        "Gavra 013";
  }

  /// Slanje SMS poruke
  static Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      // NAPOMENA: Automatsko slanje SMS-a NIJE MOGUĆE zbog Android ograničenja i namespace problema
      // Android ograničava automatsko SMS slanje iz bezbednosnih razloga
      // Ovaj pristup otvara SMS aplikaciju sa prethodno popunjenim podacima

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        debugPrint('📤 SMS aplikacija otvorena za: $phoneNumber');
        debugPrint('📝 Poruka pripremljena, korisnik mora ručno da pošalje');
      } else {
        throw Exception('Ne mogu da pokrenemo SMS aplikaciju');
      }
    } catch (e) {
      debugPrint('📵 Greška otvaranja SMS aplikacije za $phoneNumber: $e');
      rethrow;
    }
  }

  /// Manuelno slanje SMS-a (za testiranje)
  static Future<void> sendTestSMS() async {
    debugPrint('🧪 Test SMS funkcionalnosti...');
    await sendSMSToUnpaidMonthlyPassengers();
  }

  /// Provera da li je danas predzadnji dan meseca
  static bool isSecondToLastDayOfMonth() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    return now.day == secondToLastDay.day;
  }

  /// Info o sledećem slanju SMS-a
  static String getNextSMSInfo() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    String dateStr = DateFormat('dd.MM.yyyy').format(secondToLastDay);

    if (now.day <= secondToLastDay.day) {
      return 'Sledeći SMS: $dateStr u 20:00';
    } else {
      // Sledeći mesec
      DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
      DateTime nextSecondToLast = _getSecondToLastDayOfMonth(nextMonth);
      String nextDateStr = DateFormat('dd.MM.yyyy').format(nextSecondToLast);
      return 'Sledeći SMS: $nextDateStr u 20:00';
    }
  }
}
