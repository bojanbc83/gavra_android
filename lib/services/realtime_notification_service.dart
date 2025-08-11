import 'package:flutter/material.dart';
// Firebase messaging imports - disabled for iOS
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_notification_service.dart';

class RealtimeNotificationService {
  /// Pozovi ovu metodu iz glavnog widgeta (npr. u initState) da bi popup i zvuk radili u foregroundu
  static void listenForForegroundNotifications(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Proveri da li je notifikacija za tekući dan
      final bool isForToday = _isNotificationForToday(message);

      if (isForToday) {
        // Heads-up popup sa custom zvukom i lock screen funkcionalnostima
        await LocalNotificationService.showRealtimeNotification(
          title: message.notification?.title ?? 'Gavra Transport',
          body: message.notification?.body ?? 'Nova notifikacija',
          payload: message.data.toString(),
          playCustomSound: true,
        );

        // Prikaži i in-app popup dialog ako je app otvoren
        if (context.mounted) {
          _showInAppPopup(context, message);
        }
      }
    });
  }

  /// Proveri da li je notifikacija za tekući dan
  static bool _isNotificationForToday(RemoteMessage message) {
    final today = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final todayName = dayNames[today.weekday - 1];

    // Proveri topic ili data payload
    final topic = message.data['topic'] ?? '';
    final dan = message.data['dan'] ?? '';
    final timestamp = message.data['timestamp'] ?? '';

    // Ako je eksplicitno za danas
    if (topic == 'danas' || dan == todayName || topic.contains('today')) {
      return true;
    }

    // Proverava da li je notifikacija poslata danas
    if (timestamp.isNotEmpty) {
      try {
        final notificationTime = DateTime.parse(timestamp);
        final isToday = notificationTime.year == today.year &&
            notificationTime.month == today.month &&
            notificationTime.day == today.day;
        return isToday;
      } catch (e) {
        // Greška pri parsiranju timestamp
      }
    }

    return false;
  }

  /// Prikaži in-app popup dialog
  static void _showInAppPopup(BuildContext context, RemoteMessage message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.notification?.title ?? 'Obaveštenje',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification?.body ?? 'Nova notifikacija',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Vreme: ${DateTime.now().toString().substring(0, 19)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zatvori'),
            ),
          ],
        );
      },
    );
  }

  /// Pretplata na topike za vozača - fokus na tekući dan
  static Future<void> subscribeToDriverTopics(String vozac) async {
    try {
      // Pretplati se na opšte teme - UVEK AKTIVNE
      await FirebaseMessaging.instance.subscribeToTopic('danas');
      await FirebaseMessaging.instance.subscribeToTopic('today');
      await FirebaseMessaging.instance.subscribeToTopic('all_drivers');

      // Pretplati se na vozač-specifične topike
      if (vozac.isNotEmpty && vozac != 'anonymous') {
        await FirebaseMessaging.instance.subscribeToTopic('driver_$vozac');
      }

      // Pretplati se na danas specifične teme
      final today = DateTime.now();
      final dayNames = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final todayName = dayNames[today.weekday - 1];
      await FirebaseMessaging.instance.subscribeToTopic('dan_$todayName');

      // Dodatno: pretplati se na basic topike koji rade uvek
      await FirebaseMessaging.instance.subscribeToTopic('svi_vozaci');
      await FirebaseMessaging.instance.subscribeToTopic('gavra_transport');
    } catch (e) {
      // Greška pri pretplati na topike
    }
  }

  /// Slanje real-time notifikacije za tekući dan
  static Future<void> sendRealtimeNotification({
    required String type,
    required dynamic putnik,
    String? fromDriver,
    String? toDriver,
    String? dodatneInfo,
  }) async {
    // OneSignal REST API endpoint
    const String oneSignalUrl = 'https://onesignal.com/api/v1/notifications';
    // NAPOMENA: U produkciji, API ključ treba pomeriti u sigurnu lokaciju
    const String restApiKey =
        'os_v2_app_j7kxv4kwrjc6bjzxhm4rrrhjfidymepwhpkubkfxhqhc4mlh2x7e7soki6fkvkzib2sxdbf7c6gzo77wlvn4x42jccwmoxzobvrjsaq';
    const String appId = '4fd57af1-568a-45e0-a737-3b3918c4e92a';

    // Pretvori putnik u mapu ako je moguće
    dynamic putnikIme;
    dynamic putnikJson;
    if (putnik is Map) {
      putnikIme = putnik['ime'] ?? putnik.toString();
      putnikJson = putnik;
    } else if (putnik != null && putnik.ime != null) {
      // Ako je Putnik objekat sa poljem ime
      putnikIme = putnik.ime;
      try {
        putnikJson =
            putnik.toJson != null ? putnik.toJson() : putnik.toString();
      } catch (_) {
        putnikJson = putnik.toString();
      }
    } else if (putnik != null && putnik.toJson != null) {
      try {
        putnikJson = putnik.toJson();
        putnikIme = putnikJson['ime'] ?? putnik.toString();
      } catch (_) {
        putnikIme = putnik.toString();
        putnikJson = putnik.toString();
      }
    } else {
      putnikIme = putnik?.toString();
      putnikJson = putnik?.toString();
    }

    // Build notification content sa fokus na tekući dan
    String title = '';
    String body = '';
    final today = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final todayName = dayNames[today.weekday - 1];

    if (type == 'novi_putnik') {
      title = '🆕 Novi putnik - $todayName';
      body = 'Dodat je novi putnik za danas: $putnikIme';
    } else if (type == 'otkazan_putnik') {
      title = '❌ Otkazan putnik - $todayName';
      body = 'Putnik otkazan za danas: $putnikIme';
    } else {
      title = '📢 Gavra Transport - $todayName';
      body = dodatneInfo ?? 'Novo obaveštenje za danas';
    }

    final data = {
      'app_id': appId,
      'included_segments': ['All'],
      'headings': {'en': title},
      'contents': {'en': body},
      'android_sound': 'default',
      'android_visibility': 1, // public - prikaži na lock screen
      'android_group': 'gavra_today',
      'android_group_message': {'en': 'Gavra notifikacije za danas'},
      'priority': 10, // max priority
      'ios_sound': 'default',
      'ios_badgeType': 'Increase',
      'ios_badgeCount': 1,
      'ios_interruption_level': 'critical', // Za lock screen na iOS
      'data': {
        'type': type,
        'putnik': putnikJson,
        'fromDriver': fromDriver,
        'toDriver': toDriver,
        'dodatneInfo': dodatneInfo,
        'topic': 'danas',
        'timestamp': DateTime.now().toIso8601String(),
        'dan': todayName,
      },
    };

    try {
      await http.post(
        Uri.parse(oneSignalUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $restApiKey',
        },
        body: jsonEncode(data),
      );
    } catch (e) {
      // Exception pri slanju notifikacije
    }
  }

  /// 🔧 INICIJALIZUJ REAL-TIME NOTIFIKACIJE
  static Future<void> initialize(String trenutniVozac) async {
    // Pretplati se na topike za vozača
    await subscribeToDriverTopics(trenutniVozac);

    // Handle background notifikacije - pozovi iz main.dart
    // FirebaseMessaging.onBackgroundMessage je pozvan iz main.dart

    // Kreiraj OneSignal kanale eksplicitno
    await _createOneSignalChannels();
  }

  /// Kreira OneSignal kanale za Android
  static Future<void> _createOneSignalChannels() async {
    // OneSignal automatski kreira default kanale
  }

  /// 📬 HANDLE BACKGROUND NOTIFIKACIJE
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    // Proveri da li je notifikacija za tekući dan
    final bool isForToday = _isNotificationForToday(message);

    if (isForToday) {
      // Prikaži lokalne notifikacije za background poruke
      await LocalNotificationService.showRealtimeNotification(
        title: message.notification?.title ?? 'Gavra Transport',
        body: message.notification?.body ?? 'Nova notifikacija za danas',
        payload: message.data.toString(),
        playCustomSound: true,
      );
    }
  }

  /// Simple test method to verify static methods work
  static void testMethod() {
    // Test method
  }

  /// Metoda za manual test slanje notifikacije
  static Future<void> sendTestNotification() async {
    await sendRealtimeNotification(
      type: 'novi_putnik',
      putnik: {'ime': 'Test Putnik', 'polazak': '14:00'},
      dodatneInfo: 'Test notifikacija za danas',
    );
  }
}
