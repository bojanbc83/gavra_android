import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';

// import 'package:supabase_flutter/supabase_flutter.dart'; // Firebase migration

import '../globals.dart';
import 'mesecni_putnik_service.dart';
import '../screens/danas_screen.dart';
// import 'supabase_safe.dart'; // Firebase migration

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap - navigate to today screen
        _handleNotificationTap(response);
      },
    );

    // Kreiraj kanal za heads-up notifikacije sa visokim prioritetom
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gavra_realtime_channel',
      'Gavra Realtime Notifikacije',
      description: 'Kanal za realtime heads-up notifikacije sa zvukom',
      importance: Importance.max,
      enableLights: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Permission requests are handled by RealtimeNotificationService
    // to avoid conflicts - no local permission requests here
  }

  /// Prikaz realtime notifikacije sa popup, zvuk i lock screen
  static Future<void> showRealtimeNotification({
    required String title,
    required String body,
    String? payload,
    bool playCustomSound = true,
  }) async {
    try {
      // 1. Prvo pusti custom zvuk
      if (playCustomSound) {
        await _playNotificationSound();
      }

      // 2. Vibracija da privuče pažnju
      await HapticFeedback.heavyImpact();

      // 3. Prikaz heads-up notifikacije
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription:
                'Kanal za realtime heads-up notifikacije sa zvukom',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false, // Mi ćemo custom zvuk
            enableLights: true,
            when: DateTime.now().millisecondsSinceEpoch,
            fullScreenIntent: true, // Za lock screen
            category: AndroidNotificationCategory.call, // Visok prioritet
            visibility: NotificationVisibility.public, // Prikaži na lock screen
            ticker: '$title - $body',
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
              summaryText: 'Gavra Transport',
              htmlFormatSummaryText: true,
            ),
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // Ignorišemo greške sa prikazivanjem notifikacija
    }
  }

  /// Pusti custom gavra.mp3 zvuk
  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.setAsset('assets/gavra.mp3');
      await _audioPlayer.setVolume(1.0); // Maksimalna glasnoća
      await _audioPlayer.play();
    } catch (e) {
      // Log the error to help diagnose issues like unsupported audio format
      try {
        // Use navigatorKey context-safe logger if available
      } catch (_) {}
    }
  }

  /// Background-safe helper to show a local notification from a background isolate
  /// This creates a fresh FlutterLocalNotificationsPlugin instance and shows a
  /// basic notification. Avoids UI and audio playback (audio not supported in background isolate).
  static Future<void> showNotificationFromBackground({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await plugin.initialize(initializationSettings);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'gavra_realtime_channel',
        'Gavra Realtime Notifikacije',
        channelDescription: 'Kanal za realtime heads-up notifikacije sa zvukom',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      // Can't do much in background isolate; swallow errors
    }
  }

  /// Handle notification tap - navigate to passenger with filters
  static Future<void> _handleNotificationTap(
    NotificationResponse response,
  ) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      // Parse payload to get passenger info
      String? putnikIme;
      String? notificationType;
      String? putnikGrad;
      String? putnikVreme;

      if (response.payload != null) {
        try {
          // Parse the payload JSON
          final Map<String, dynamic> payloadData =
              jsonDecode(response.payload!) as Map<String, dynamic>;

          notificationType = payloadData['type'] as String?;
          final putnikData = payloadData['putnik'];

          // Extract passenger name from different possible formats
          if (putnikData is Map<String, dynamic>) {
            putnikIme = (putnikData['ime'] ?? putnikData['name']) as String?;
            putnikGrad = putnikData['grad'] as String?;
            putnikVreme =
                (putnikData['vreme'] ?? putnikData['polazak']) as String?;
          } else if (putnikData is String) {
            // Try to parse if it's JSON string
            try {
              final putnikMap = jsonDecode(putnikData);
              if (putnikMap is Map<String, dynamic>) {
                putnikIme = (putnikMap['ime'] ?? putnikMap['name']) as String?;
                putnikGrad = putnikMap['grad'] as String?;
                putnikVreme =
                    (putnikMap['vreme'] ?? putnikMap['polazak']) as String?;
              }
            } catch (e) {
              // If not JSON, use as direct string
              putnikIme = putnikData;
            }
          }

          // 🔍 DOHVATI PUTNIK PODATKE IZ BAZE ako nisu u payload-u
          if (putnikIme != null &&
              (putnikGrad == null || putnikVreme == null)) {
            try {
              final putnikInfo = await _fetchPutnikFromDatabase(putnikIme);
              if (putnikInfo != null) {
                putnikGrad = putnikGrad ?? putnikInfo['grad'] as String?;
                putnikVreme = putnikVreme ??
                    (putnikInfo['polazak'] ?? putnikInfo['vreme_polaska'])
                        as String?;
              }
            } catch (e) {
              // Ignore database fetch errors - fallback to basic navigation
            }
          }
        } catch (e) {
          // If payload parsing fails, fall back to simple navigation
        }
      }

      // Navigate to dagens screen with filter parameters
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => DanasScreen(
              highlightPutnikIme: putnikIme,
              filterGrad: putnikGrad,
              filterVreme: putnikVreme,
            ),
          ),
        );
      }

      // Show info about the passenger if available
      if (putnikIme != null && context.mounted) {
        String message;
        Color bgColor;
        IconData icon;

        if (notificationType == 'novi_putnik') {
          message = '🆕 Dodat putnik: $putnikIme';
          bgColor = Colors.green;
          icon = Icons.person_add;
        } else if (notificationType == 'otkazan_putnik') {
          message = '❌ Otkazan putnik: $putnikIme';
          bgColor = Colors.red;
          icon = Icons.person_remove;
        } else {
          message = '📢 Putnik: $putnikIme';
          bgColor = Colors.blue;
          icon = Icons.info;
        }

        // Show snackbar with passenger info
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // Error handling notification tap - fallback to simple navigation
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const DanasScreen(),
          ),
        );
      }
    }
  }

  /// Legacy metoda za kompatibilnost
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await showRealtimeNotification(
      title: title,
      body: body,
    );
  }

  /// Očisti sve notifikacije
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Dispose audio player
  static Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  /// 🔍 FETCH PUTNIK DATA FROM DATABASE BY NAME
  static Future<Map<String, dynamic>?> _fetchPutnikFromDatabase(
    String putnikIme,
  ) async {
    try {
      // ✅ KORISTI POSTOJEĆI FIREBASE SERVIS
      final putnik =
          await MesecniPutnikService.getMesecniPutnikByIme(putnikIme);
      return putnik?.toMap();
    } catch (e) {
      return null;
    }
  }

  // Helper method removed due to Firebase migration
}
