import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class UpdateChecker {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static Timer? _dailyTimer;

  /// Inicijalizuje notification system i pokreće daily timer
  static Future<void> initializeAutoUpdates() async {
    debugPrint('🚨 INICIJALIZUJEM UPDATE CHECKER...');

    try {
      // WAIT dodatnih 2 sekunde da se app_links završi
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('⏳ Čekao sam 2 sekunde da se app_links završi...');

      // Initialize notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      debugPrint('🔔 FORCIRAM registraciju notification callback-a...');
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      debugPrint('✅ Notification callback FORSIRAN!');

      // Kreiraj notification channels eksplicitno
      await _createNotificationChannels();

      // Pokreni daily timer za 22:00
      _startDailyUpdateCheck();

      debugPrint('✅ UpdateChecker inicijalizovan uspešno');
    } catch (e) {
      debugPrint('❌ GREŠKA pri inicijalizaciji UpdateChecker-a: $e');
      // U test okruženju ili ako notifikacije nisu dostupne, samo nastavi
    }
  }

  /// Kreira notification channels eksplicitno
  static Future<void> _createNotificationChannels() async {
    try {
      // Channel za update notifikacije
      const AndroidNotificationChannel updateChannel =
          AndroidNotificationChannel(
        'gavra_updates',
        'Gavra Updates',
        description: 'Notifications for app updates',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      // Channel za install status notifikacije
      const AndroidNotificationChannel installChannel =
          AndroidNotificationChannel(
        'gavra_install',
        'Gavra Install Status',
        description: 'Status notifikacije za instalaciju',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(updateChannel);

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(installChannel);

      debugPrint('✅ Notification channels kreiran');
    } catch (e) {
      debugPrint('❌ Greška pri kreiranju notification channels: $e');
    }
  }

  /// Manuelni update check - pozove se iz UI
  static Future<void> checkForUpdates() async {
    await _performBackgroundUpdateCheck();
  }

  /// Manuelni update check sa UI feedback-om
  static Future<String> checkForUpdatesWithFeedback() async {
    debugPrint('🚨🚨🚨 MANUAL UPDATE CHECK POZVAN! 🚨🚨🚨');
    try {
      // Preuzmi verzije
      final info = await PackageInfo.fromPlatform();
      final currentVersion = '${info.version}+${info.buildNumber}'.trim();
      debugPrint('🔍 Trenutna verzija: $currentVersion');

      const url =
          'https://www.dropbox.com/scl/fi/2hyeqzk02xb432zl7dr5c/latest_version.txt?rlkey=8be5byaibvzkex6ehiy1c9yh1&st=v7ytg2na&dl=1';
      debugPrint('🌐 Proveravam URL: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final latestVersion =
            response.body.trim().replaceAll(RegExp(r'\s+'), '');
        final normalizedCurrent =
            currentVersion.trim().replaceAll(RegExp(r'\s+'), '');

        debugPrint('🔍 Najnovija verzija: $latestVersion');
        debugPrint('🔍 Trenutna verzija (normalized): $normalizedCurrent');
        debugPrint(
            '🔍 Da li su različite: ${latestVersion != normalizedCurrent}');

        if (latestVersion != normalizedCurrent) {
          debugPrint('🎉 NOVA VERZIJA PRONAĐENA! Pokrećem download...');
          // Ima novi update - downloaduj APK i pošalji notification
          await _downloadAndNotify(latestVersion);

          // Détectuj tip uređaja za poruku
          final isHuawei = await _isHuaweiDevice();
          final isGBox = await _isGBoxInstalled();
          final isSamsung = await _isSamsungDevice();
          if (isHuawei || isGBox || isSamsung) {
            String deviceType = 'Standard';
            if (isGBox) {
              deviceType = 'Huawei/GBox';
            } else if (isHuawei) {
              deviceType = 'Huawei/Honor';
            } else if (isSamsung) {
              deviceType = 'Samsung/Knox';
            }

            return 'USPEŠNO! Nova verzija $latestVersion je downloadovana i instalacija je pokrenuta automatski jer imate $deviceType uređaj. Prati dijalog na ekranu!';
          } else {
            return 'USPEŠNO! Nova verzija $latestVersion je downloadovana! TAP NA NOTIFIKACIJU da pokreneš instalaciju. Neće se ništa desiti dok ne tap-uješ notifikaciju!';
          }
        } else {
          debugPrint('ℹ️ Verzije su iste - nema update-a');
          return 'Već imaš najnoviju verziju ($currentVersion). Sve je ažurno - nema novih update-ova! 😊';
        }
      } else {
        debugPrint('❌ HTTP status: ${response.statusCode}');
        return 'Ne mogu da kontaktiram server za proveru verzije (greška ${response.statusCode}). Proveri internet konekciju i pokušaj ponovo.';
      }
    } catch (e) {
      debugPrint('❌ Exception u checkForUpdatesWithFeedback: $e');
      return 'Dogodila se greška pri proveri update-a: ${e.toString()}. Pokušaj ponovo ili proveri internet konekciju.';
    }
  }

  /// Callback kada korisnik tap-uje notification - POPRAVLJENO PROTIV APP_LINKS
  static void _onNotificationTap(NotificationResponse response) async {
    debugPrint('🚨🚨🚨 NOTIFICATION CALLBACK POZVAN! 🚨🚨🚨');
    debugPrint('🔔 Response ID: ${response.id}');
    debugPrint('🔔 Response payload: ${response.payload}');
    debugPrint('🔔 Response actionId: ${response.actionId}');
    debugPrint('🔔 Response input: ${response.input}');
    debugPrint(
        '🔔 Response notificationResponseType: ${response.notificationResponseType}');

    // HMS PROVERA - dodaj debug info za Huawei uređaje
    final isHuawei = await _isHuaweiDevice();
    if (isHuawei) {
      debugPrint(
          '📱 HUAWEI/HMS UREĐAJ - možda HMS blokira notification callbacks!');
      debugPrint('🔧 Ovo objašnjava zašto notification tap možda ne radi');
    }

    try {
      // Prihvati bilo koji tap na notification (bez obzira na actionId)
      debugPrint('✅ USAO U NOTIFICATION HANDLER');

      if (response.payload != null && response.payload!.isNotEmpty) {
        final payload = response.payload!;
        debugPrint('✅ PAYLOAD POSTOJI: $payload');

        // Parsiranje local payload-a (izbegava app_links)
        if (payload.startsWith('LOCAL_INSTALL:')) {
          final apkPath = payload.substring('LOCAL_INSTALL:'.length);
          debugPrint('🚀 POKRETAM LOKALNU INSTALACIJU SA PUTANJOM: $apkPath');
          debugPrint(
              '👆 OBJAŠNJENJE: Notification tap je uspešan! Pokrećem Android installer...');
          await _installApk(apkPath);
          debugPrint(
              '✅ INSTALACIJA FUNKCIJA ZAVRŠENA - prati dijalog na ekranu!');
        }
        // Stari format za kompatibilnost
        else if (payload.startsWith('GAVRA_INSTALL:')) {
          final apkPath = payload.substring('GAVRA_INSTALL:'.length);
          debugPrint(
              '🚀 POKRETAM INSTALACIJU SA PUTANJOM (stari format): $apkPath');
          debugPrint(
              '👆 OBJAŠNJENJE: Notification tap je uspešan! Pokrećem Android installer...');
          await _installApk(apkPath);
          debugPrint(
              '✅ INSTALACIJA FUNKCIJA ZAVRŠENA - prati dijalog na ekranu!');
        } else {
          debugPrint('❌ NEPOZNAT PAYLOAD FORMAT: $payload');
        }
      } else {
        debugPrint('❌ PAYLOAD JE NULL ILI PRAZAN!');
        debugPrint('❌ response.payload: ${response.payload}');

        if (isHuawei) {
          debugPrint(
              '📱 HMS OBJAŠNJENJE: HMS možda blokira payload prosleđivanje u notifikacijama');
          debugPrint(
              '🔧 Zato smo implementirali direktnu instalaciju za Huawei uređaje');
        }
      }
    } catch (e) {
      debugPrint('💥 GREŠKA U NOTIFICATION CALLBACK: $e');
      debugPrint('💥 STACK TRACE: ${e.toString()}');

      if (isHuawei) {
        debugPrint(
            '📱 HMS GREŠKA: Možda je HMS blokirao notification callback');
      }
    }

    debugPrint('🏁 NOTIFICATION CALLBACK ZAVRŠEN');
  }

  /// Pokreće timer koji proverava svaki dan u 22:00
  static void _startDailyUpdateCheck() {
    // Izračunaj koliko vremena do sledećih 20:00
    final now = DateTime.now();
    DateTime next20 = DateTime(now.year, now.month, now.day, 20, 0);

    // Ako je već prošlo 20:00 danas, uzmi sutra
    if (now.isAfter(next20)) {
      next20 = next20.add(const Duration(days: 1));
    }

    final timeUntil20 = next20.difference(now);

    // Pokreni timer
    Timer(timeUntil20, () {
      _performBackgroundUpdateCheck();

      // Zatim svaka 24h - čuva referencu u _dailyTimer za cleanup
      _dailyTimer = Timer.periodic(const Duration(days: 1), (timer) {
        _performBackgroundUpdateCheck();
      });
    });
  }

  /// Otkazuje daily timer (za cleanup)
  static void dispose() {
    _dailyTimer?.cancel();
    _dailyTimer = null;
  }

  /// Background provera bez UI - samo notification ako treba
  static Future<void> _performBackgroundUpdateCheck() async {
    try {
      // Proveri da li je već proveravano danas
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString('last_update_check');
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (lastCheck == today) return; // Već proveravano danas

      // Preuzmi verzije
      final info = await PackageInfo.fromPlatform();
      final currentVersion = '${info.version}+${info.buildNumber}'.trim();

      const url =
          'https://www.dropbox.com/scl/fi/2hyeqzk02xb432zl7dr5c/latest_version.txt?rlkey=8be5byaibvzkex6ehiy1c9yh1&st=v7ytg2na&dl=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final latestVersion =
            response.body.trim().replaceAll(RegExp(r'\s+'), '');
        final normalizedCurrent =
            currentVersion.trim().replaceAll(RegExp(r'\s+'), '');

        if (latestVersion != normalizedCurrent) {
          // Ima novi update - downloaduj APK i pošalji notification
          await _downloadAndNotify(latestVersion);
        }

        // Sačuvaj da je proveravano danas
        await prefs.setString('last_update_check', today);
      }
    } catch (e) {
      // Silent fail za background check
    }
  }

  /// KOMPLETNO - proveri update, downloda i direktno instaliraj (ALL-IN-ONE)
  static Future<String> checkDownloadAndInstall({
    Function(String message, double progress)? onProgress,
  }) async {
    debugPrint('🚀🚀🚀 ALL-IN-ONE UPDATE PROCESS POKRENUT! 🚀🚀🚀');

    try {
      // KORAK 0: Detektuj tip uređaja na početku
      final isHuawei = await _isHuaweiDevice();
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      debugPrint(
          '📱 DEVICE INFO: ${deviceInfo.manufacturer} ${deviceInfo.model} ${deviceInfo.brand}');
      debugPrint('📱 Android verzija: ${deviceInfo.version.release}');
      debugPrint('📱 SDK level: ${deviceInfo.version.sdkInt}');
      debugPrint('📱 HUAWEI uređaj: $isHuawei');

      if (isHuawei) {
        onProgress?.call(
            '📱 Detektovan Huawei/Honor uređaj - koristi specijalne metode',
            0.05);
        debugPrint('🔧 HUAWEI POSEBAN HANDLING AKTIVIRAN');
      }

      // KORAK 1: Proveri da li ima novih verzija
      onProgress?.call('🔍 Čitam trenutnu verziju aplikacije...', 0.1);
      debugPrint('📋 KORAK 1: Proveravam da li ima novih verzija...');
      final info = await PackageInfo.fromPlatform();
      final currentVersion = '${info.version}+${info.buildNumber}'.trim();
      debugPrint('🔍 Trenutna verzija: $currentVersion');

      onProgress?.call(
          '📡 Povezujem se sa serverom za proveru novih verzija...', 0.2);
      const url =
          'https://www.dropbox.com/scl/fi/2hyeqzk02xb432zl7dr5c/latest_version.txt?rlkey=8be5byaibvzkex6ehiy1c9yh1&st=v7ytg2na&dl=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        onProgress?.call(
            '❌ Server ne odgovara - proverite internet konekciju', 0.0);
        return 'Greška pri proveri verzije. Pokušaj ponovo kasnije.';
      }

      final latestVersion = response.body.trim().replaceAll(RegExp(r'\s+'), '');
      final normalizedCurrent =
          currentVersion.trim().replaceAll(RegExp(r'\s+'), '');

      debugPrint('🔍 Najnovija verzija: $latestVersion');
      debugPrint(
          '🔍 Da li su različite: ${latestVersion != normalizedCurrent}');

      // KORAK 2: Ako nema update-a, možda ima već downloadovan APK
      if (latestVersion == normalizedCurrent) {
        onProgress?.call(
            '✅ Imaš najnoviju verziju! Proveravam stare fajlove...', 0.3);
        debugPrint(
            'ℹ️ Verzije su iste - proveravam downloadovane APK fajlove...');

        // Proveri da li ima downloadovan APK za buduću instalaciju
        final directory = await getExternalStorageDirectory();
        final files = await Directory(directory!.path).list().toList();

        for (var file in files) {
          if (file.path.contains('gavra_update') &&
              file.path.endsWith('.apk')) {
            debugPrint('🎯 Pronašao postojeći APK: ${file.path}');
            onProgress?.call(
                '📦 Našao sam stariji APK za instalaciju - pokrećem...', 0.8);
            await _installApk(file.path, onProgress);
            onProgress?.call('✅ Instalacija starije verzije pokrenuta!', 1.0);
            return 'Instalacija postojećeg APK-a pokrenuta!';
          }
        }

        onProgress?.call('✅ Sve je najnovije - nema posla za mene! 😊', 1.0);
        return 'Imaš najnoviju verziju ($currentVersion). Nema novih ažuriranja.';
      }

      // KORAK 3: Ima nova verzija - downloda APK
      onProgress?.call(
          '🎉 Super! Nova verzija $latestVersion! Downloadujem sada...', 0.4);
      debugPrint(
          '🎉 NOVA VERZIJA PRONAĐENA! Downloadujem verziju $latestVersion...');

      const apkUrl =
          'https://www.dropbox.com/scl/fi/zh4s3qmeldvlo1mw0rim4/app-release.apk?rlkey=4xjudkl0jmdxbj1gj8pdgvb9b&dl=1';

      onProgress?.call('⬇️ Preuzimam novi APK fajl sa servera...', 0.5);
      final apkResponse = await http.get(Uri.parse(apkUrl));

      if (apkResponse.statusCode != 200) {
        onProgress?.call('❌ Ne mogu da preuznem APK - server problem', 0.0);
        return 'Greška pri download-u APK fajla. Pokušaj ponovo.';
      }

      // KORAK 4: Sačuvaj APK fajl
      onProgress?.call('💾 Snimam APK na telefon - skoro gotovo...', 0.7);
      final directory = await getExternalStorageDirectory();
      final apkPath = '${directory!.path}/gavra_update_$latestVersion.apk';
      final apkFile = File(apkPath);
      await apkFile.writeAsBytes(apkResponse.bodyBytes);

      debugPrint('✅ APK downloadovan na: $apkPath');
      debugPrint('📊 APK veličina: ${apkResponse.bodyBytes.length} bytes');

      // HUAWEI BACKUP: Kopiraj i u Downloads folder
      if (isHuawei) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final publicApkPath =
              '/storage/emulated/0/Download/gavra_update_$latestVersion.apk';
          await File(apkPath).copy(publicApkPath);
          debugPrint(
              '📂 HUAWEI BACKUP: APK kopiran i u Downloads: $publicApkPath');
        } catch (e) {
          debugPrint('⚠️ Greška pri kopiranju u Downloads: $e');
        }
      }

      // KORAK 5: Odmah instaliraj downloadovani APK
      onProgress?.call(
          '🚀 APK spreman! Otvaraju se postavke za instalaciju...', 0.9);
      debugPrint('🚀 ODMAH POKRETAM INSTALACIJU...');
      await _installApk(apkPath, onProgress);

      onProgress?.call('✅ Gotovo! Prati dijalog na ekranu za instalaciju', 1.0);
      final extraMessage = isHuawei
          ? '\nAko se installer nije otvorio na Huawei Mate 40 Pro, pronađi gavra_update_$latestVersion.apk u Downloads folderu.'
          : '\nSledite Android dijalog za instalaciju.';
      return 'Nova verzija $latestVersion downloadovana i instalacija pokrenuta!$extraMessage';
    } catch (e) {
      debugPrint('❌ Greška u kompletnom update procesu: $e');
      onProgress?.call('❌ Greška pri update-u', 0.0);
      return 'Greška pri update procesu: $e';
    }
  }

  /// Direktno instaliraj APK bez čekanja notification callback-a
  static Future<String> installLatestUpdate() async {
    debugPrint('🚨🚨🚨 DIREKTNO POZIVAM INSTALACIJU! 🚨🚨🚨');

    try {
      // Pronađi najnoviji APK fajl
      final directory = await getExternalStorageDirectory();
      final files = await Directory(directory!.path).list().toList();

      debugPrint('📂 Tražim APK fajlove u: ${directory.path}');

      String? latestApkPath;
      for (var file in files) {
        if (file.path.contains('gavra_update') && file.path.endsWith('.apk')) {
          latestApkPath = file.path;
          debugPrint('🎯 Pronašao APK: $latestApkPath');
          break;
        }
      }

      if (latestApkPath != null) {
        debugPrint('✅ POZIVAM DIREKTNU INSTALACIJU!');
        await _installApk(latestApkPath);
        return 'Instalacija pokrenuta! Sledite Android dijalog za instalaciju.';
      } else {
        debugPrint('❌ Nema downloadovanih APK fajlova');
        debugPrint('📁 Listam sve fajlove:');
        for (var file in files) {
          debugPrint('   - ${file.path}');
        }
        return 'Nema downloadovanih APK fajlova za instalaciju.\nPrvo kliknite "Proveri Update" da downloadujete novu verziju.';
      }
    } catch (e) {
      debugPrint('❌ Greška u direktnoj instalaciji: $e');
      return 'Greška pri instalaciji: $e';
    }
  }

  static Future<void> _downloadAndNotify(String newVersion) async {
    debugPrint('🚨🚨🚨 DOWNLOAD AND NOTIFY POZVANO! 🚨🚨🚨');
    try {
      debugPrint('📥 Početak download procesa za verziju: $newVersion');

      // Download APK
      const apkUrl =
          'https://www.dropbox.com/scl/fi/zh4s3qmeldvlo1mw0rim4/app-release.apk?rlkey=4xjudkl0jmdxbj1gj8pdgvb9b&dl=1';
      debugPrint('📥 APK URL: $apkUrl');
      final response = await http.get(Uri.parse(apkUrl));

      debugPrint('📊 HTTP status za APK: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Sačuvaj APK fajl
        final directory = await getExternalStorageDirectory();
        debugPrint('📂 Storage directory: ${directory!.path}');
        final apkPath = '${directory.path}/gavra_update_$newVersion.apk';
        final apkFile = File(apkPath);
        await apkFile.writeAsBytes(response.bodyBytes);

        debugPrint('✅ APK downloadovan na: $apkPath');
        debugPrint('📊 APK veličina: ${response.bodyBytes.length} bytes');

        // Proveri da li fajl postoji
        if (await apkFile.exists()) {
          debugPrint('✅ APK fajl POSTOJI na disk-u');
        } else {
          debugPrint('❌ APK fajl NE POSTOJI nakon pisanja!');
        }

        // HUAWEI/GBOX/SAMSUNG FIX: Odmah pokreni instalaciju bez čekanja notification tap-a
        final isHuawei = await _isHuaweiDevice();
        final isGBoxInstalled = await _isGBoxInstalled();
        final isSamsung = await _isSamsungDevice();
        if (isHuawei || isGBoxInstalled || isSamsung) {
          debugPrint(
              '📱 HUAWEI/HMS/GBOX/SAMSUNG DETEKTOVAN - pokretam direktnu instalaciju umesto notification-a!');
          debugPrint(
              '🔧 RAZLOG: HMS (Huawei Mobile Services), GBox i Samsung Knox mogu blokirati notification callbacks');
          if (isGBoxInstalled) {
            debugPrint(
                '📦 GBox Store detektovan - koristi GBox optimizovane metode');
          }
          if (isSamsung) {
            debugPrint(
                '🔒 Samsung Knox detektovan - koristi Samsung optimizovane metode');
          }

          // DODATNO za Huawei: Kopiraj APK i u Downloads folder kao backup
          try {
            final downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            final publicApkPath =
                '/storage/emulated/0/Download/gavra_update_$newVersion.apk';
            await File(apkPath).copy(publicApkPath);
            debugPrint(
                '📂 HUAWEI BACKUP: APK kopiran i u Downloads: $publicApkPath');
          } catch (e) {
            debugPrint('⚠️ Greška pri kopiranju u Downloads: $e');
          }

          await _installApk(apkPath);

          // Pošalji informativnu notifikaciju (bez payload-a za HMS)
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'gavra_install',
            'Gavra Install Status',
            channelDescription: 'Status notifikacije za instalaciju',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            autoCancel: true,
            // HMS specifične postavke
            enableVibration: false, // HMS može blokirati vibracije
            playSound: false, // HMS može blokirati zvukove
          );

          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          await _notifications.show(
            1,
            '📱 Gavra App - Huawei/GBox/Samsung uređaj detektovan',
            'OBJAŠNJENJE: Verzija $newVersion je downloadovana i instalacija je automatski pokrenuta! Na Huawei, GBox i Samsung uređajima notification tap često ne radi zbog HMS (Huawei Mobile Services) ili Samsung Knox, zato sam odmah otvorio installer. Ako se nije otvorio, idi u Downloads folder i pronađi gavra_update_$newVersion.apk fajl.',
            platformChannelSpecifics,
          );
        } else {
          // Za ostale uređaje - koristi standardni notification sa payload
          debugPrint(
              '📱 STANDARDNI UREĐAJ - šaljem notification sa payload-om');

          // Pošalji notification sa LOCAL:// payload da app_links ne presreće
          debugPrint('🔔 Pokušavam da pošaljem notifikaciju...');
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'gavra_updates',
            'Gavra Updates',
            channelDescription: 'Notifications for app updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            autoCancel: false,
            enableVibration: true,
            playSound: true,
            // Ukloni actions da ne trigguje app_links intent filtere
            category: AndroidNotificationCategory.status,
          );

          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          await _notifications.show(
            0,
            'Gavra App - Nova verzija $newVersion spremna!',
            'INSTRUKCIJE: Download je završen! Tap (dodirni) ovu notifikaciju da pokreneš instalaciju. Neće se ništa desiti dok ne tap-uješ!',
            platformChannelSpecifics,
            payload: 'LOCAL_INSTALL:$apkPath',
          );

          debugPrint(
              '🔔 Notification poslata sa payload: LOCAL_INSTALL:$apkPath');
        }
      } else {
        debugPrint('❌ Download failed sa statusom: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Exception u _downloadAndNotify: $e');
      debugPrint('❌ Stack trace: ${e.toString()}');
    }
  }

  /// Detektuje da li je uređaj Huawei ili Honor (koji koriste HarmonyOS/EMUI)
  static Future<bool> _isHuaweiDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      final model = androidInfo.model.toLowerCase();

      debugPrint('📱 Device manufacturer: $manufacturer');
      debugPrint('📱 Device brand: $brand');
      debugPrint('📱 Device model: $model');

      // Standardno Huawei/Honor detektovanje
      final isHuaweiDevice = manufacturer.contains('huawei') ||
          brand.contains('huawei') ||
          manufacturer.contains('honor') ||
          brand.contains('honor') ||
          model.contains('huawei') ||
          model.contains('honor');

      debugPrint('📱 Huawei/Honor device detected: $isHuaweiDevice');
      return isHuaweiDevice;
    } catch (e) {
      debugPrint('❌ Error detecting Huawei device: $e');
      return false;
    }
  }

  /// Detektuje da li je GBox App Store instaliran na uređaju
  static Future<bool> _isGBoxInstalled() async {
    try {
      // Poznati package names za GBox i slične Huawei app store-ove
      final gboxPackages = [
        'com.huawei.appmarket', // AppGallery (glavni Huawei store)
        'com.huawei.gbox', // GBox (ako postoji specifičan package)
        'com.hihonor.appmarket', // Honor App Market
        'com.huawei.hwid', // Huawei ID (obično ide uz app store)
        'com.huawei.hms.core', // HMS Core
      ];

      for (String packageName in gboxPackages) {
        try {
          final result =
              await Process.run('pm', ['list', 'packages', packageName]);
          if (result.exitCode == 0 &&
              result.stdout.toString().contains(packageName)) {
            debugPrint('📦 GBox/HMS store detektovan: $packageName');
            return true;
          }
        } catch (e) {
          // Continue checking other packages
        }
      }

      debugPrint('📦 GBox/HMS store NIJE detektovan');
      return false;
    } catch (e) {
      debugPrint('❌ Error detecting GBox: $e');
      return false;
    }
  }

  /// Detektuje da li je Samsung Galaxy uređaj (koji može imati Samsung Knox probleme)
  static Future<bool> _isSamsungDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      final model = androidInfo.model.toLowerCase();

      debugPrint('📱 Samsung detection - Manufacturer: $manufacturer');
      debugPrint('📱 Samsung detection - Brand: $brand');
      debugPrint('📱 Samsung detection - Model: $model');

      // Samsung detektovanje
      final isSamsungDevice = manufacturer.contains('samsung') ||
          brand.contains('samsung') ||
          model.contains('galaxy') ||
          model.contains('sm-') || // Samsung model prefix
          model.contains('note') ||
          model.contains('a0') || // Galaxy A series
          model.contains('a1') ||
          model.contains('a2') ||
          model.contains('a3') ||
          model.contains('a5') ||
          model.contains('s2') || // Galaxy S series
          model.contains('s1') ||
          model.contains('fold') ||
          model.contains('flip');

      // Dodatno proveri Samsung Knox sigurnosne pakete
      try {
        final knoxPackages = [
          'com.sec.android.app.samsungapps', // Galaxy Store
          'com.samsung.android.knox', // Samsung Knox
          'com.sec.enterprise.knox', // Knox Enterprise
          'com.samsung.android.authfw', // Samsung Auth Framework
        ];

        for (String packageName in knoxPackages) {
          try {
            final result =
                await Process.run('pm', ['list', 'packages', packageName]);
            if (result.exitCode == 0 &&
                result.stdout.toString().contains(packageName)) {
              debugPrint('🔒 Samsung Knox component detected: $packageName');
              debugPrint('📱 Samsung device with Knox detected: true');
              return true;
            }
          } catch (e) {
            // Continue checking
          }
        }
      } catch (e) {
        debugPrint('⚠️ Knox package check failed: $e');
      }

      debugPrint('📱 Samsung device detected: $isSamsungDevice');
      return isSamsungDevice;
    } catch (e) {
      debugPrint('❌ Error detecting Samsung device: $e');
      return false;
    }
  }

  /// Otvara Android installer za APK
  static Future<void> _installApk(String apkPath,
      [Function(String message, double progress)? onProgress]) async {
    debugPrint('🚨🚨🚨 _INSTALLAPK FUNKCIJA POZVANA! 🚨🚨🚨');
    debugPrint('🔧 APK PATH: $apkPath');

    try {
      onProgress?.call('🔧 Pripremam APK za instalaciju...', 0.85);
      debugPrint('🔧 Pokušavam instalaciju APK: $apkPath');

      // KORAK 1: Detektuj tip uređaja sa detaljnim info
      final isHuawei = await _isHuaweiDevice();
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      debugPrint('📱 DEVICE DETAILS:');
      debugPrint('   Manufacturer: ${deviceInfo.manufacturer}');
      debugPrint('   Model: ${deviceInfo.model}');
      debugPrint('   Brand: ${deviceInfo.brand}');
      debugPrint('   Android: ${deviceInfo.version.release}');
      debugPrint('   SDK: ${deviceInfo.version.sdkInt}');
      debugPrint('   Huawei detection: $isHuawei');

      // KORAK 2: Proveri permissions za Android 10+ (SDK 29+)
      if (deviceInfo.version.sdkInt >= 29) {
        debugPrint(
            '🔐 Android 10+ detektovan - proveravam REQUEST_INSTALL_PACKAGES permission...');
        try {
          final status = await Permission.requestInstallPackages.status;
          debugPrint('🔐 REQUEST_INSTALL_PACKAGES status: $status');

          if (status != PermissionStatus.granted) {
            debugPrint(
                '⚠️ REQUEST_INSTALL_PACKAGES permission NIJE dozvoljen!');
            onProgress?.call('🔐 Tražim dozvolu za instalaciju...', 0.87);

            final result = await Permission.requestInstallPackages.request();
            debugPrint('🔐 Permission request rezultat: $result');

            if (result != PermissionStatus.granted) {
              debugPrint(
                  '❌ Korisnik je odbio REQUEST_INSTALL_PACKAGES permission!');
              onProgress?.call(
                  '❌ Potrebna dozvola za instalaciju aplikacija', 0.0);
              await _showInstallErrorNotification(
                  'Morate omogućiti instalaciju aplikacija iz nepoznatih izvora u Android postavkama.');
              return;
            }
          }

          debugPrint('✅ REQUEST_INSTALL_PACKAGES permission OK!');
        } catch (e) {
          debugPrint('⚠️ Greška pri proveri permissions: $e');
        }
      }

      // KORAK 3: Proveri da li APK fajl postoji
      final file = File(apkPath);
      debugPrint('📁 Proveravam da li fajl postoji...');

      if (!await file.exists()) {
        debugPrint('❌ APK fajl ne postoji na putanji: $apkPath');
        onProgress?.call('❌ APK fajl nije pronađen', 0.0);
        await _showInstallErrorNotification('APK fajl nije pronađen');
        return;
      }

      final fileSize = await file.length();
      debugPrint('✅ APK fajl pronađen na: $apkPath');
      debugPrint('📊 Veličina fajla: $fileSize bytes');

      // Proveri da li je fajl valjan (minimalno 1MB za APK)
      if (fileSize < 1000000) {
        debugPrint('⚠️ APK fajl je sumnjivo mali ($fileSize bytes)');
        onProgress?.call('⚠️ APK fajl možda nije ispravan', 0.5);
      }

      if (isHuawei) {
        onProgress?.call(
            '📱 Huawei uređaj - koristim specijalne metode instalacije...',
            0.9);
        debugPrint('🔧 HUAWEI DEVICE - koristim specijalne metode');
      } else {
        onProgress?.call(
            '📱 Otvaram Android installer - čekaj da se pojavi dijalog...',
            0.95);
      }

      // METOD 0: Jednostavan pristup - direktno pozovi Package Installer
      try {
        debugPrint(
            '🚀 METOD 0: Pokušavam jednostavan Package Installer intent...');

        final intent = AndroidIntent(
          action: 'android.intent.action.INSTALL_PACKAGE',
          data: Uri.file(apkPath).toString(),
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );

        await intent.launch();
        debugPrint('✅ Package Installer intent pozvan uspešno!');
        onProgress?.call(
            '✅ Android installer je otvoren! Prati dijalog na ekranu', 1.0);
        await _showInstallSuccessNotification();
        return;
      } catch (e, stackTrace) {
        debugPrint('❌ Package Installer intent failed: $e');
        debugPrint('   Stack trace: $stackTrace');
      }

      // METOD 0A: Standardni VIEW intent za APK
      try {
        debugPrint('🚀 METOD 0A: Pokušavam standardni VIEW intent...');
        debugPrint('   File URI: ${Uri.file(apkPath)}');

        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: Uri.file(apkPath).toString(),
          type: 'application/vnd.android.package-archive',
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );

        await intent.launch();
        debugPrint('✅ VIEW Intent pozvan uspešno!');
        onProgress?.call(
            '✅ Uspešno! Sada prati Android dijalog za instalaciju', 1.0);
        await _showInstallSuccessNotification();
        return;
      } catch (e, stackTrace) {
        debugPrint('❌ VIEW Intent failed: $e');
        debugPrint('   Stack trace: $stackTrace');
      }

      // METOD 0B: Za Huawei - probaj bez MIME type
      if (isHuawei) {
        try {
          debugPrint('🔗 METOD 0B: Huawei - probaj bez MIME type...');

          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: Uri.file(apkPath).toString(),
            // Ne postavljamo type za Huawei
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
              Flag.FLAG_GRANT_WRITE_URI_PERMISSION,
            ],
          );

          await intent.launch();
          debugPrint('✅ Huawei no-type intent uspešan!');
          onProgress?.call('✅ Huawei installer otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e, stackTrace) {
          debugPrint('❌ Huawei no-type intent failed: $e');
          debugPrint('   Stack trace: $stackTrace');
        }
      }

      // METOD 0C: Probaj sa ContentResolver pristupom
      try {
        debugPrint('🔗 METOD 0C: Pokušavam sa content resolver...');

        // Kreiraj fajl URI u Android/data folder
        final androidDataPath = apkPath.replaceFirst('/storage/emulated/0/',
            '/Android/data/com.example.gavra_android/files/');
        debugPrint('   Android data path: $androidDataPath');

        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: Uri.file(androidDataPath).toString(),
          type: 'application/vnd.android.package-archive',
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );

        await intent.launch();
        debugPrint('✅ Content resolver intent uspešan!');
        onProgress?.call('✅ Content resolver installer otvoren!', 1.0);
        await _showInstallSuccessNotification();
        return;
      } catch (e, stackTrace) {
        debugPrint('❌ Content resolver intent failed: $e');
        debugPrint('   Stack trace: $stackTrace');
      }

      // METOD 1: OpenFileX - najbolji za APK instalaciju
      try {
        debugPrint('📱 METOD 1: Pokušavam OpenFileX...');
        final result = await OpenFilex.open(apkPath);
        debugPrint('📱 OpenFileX rezultat: ${result.type} - ${result.message}');

        if (result.type == ResultType.done) {
          debugPrint('✅ APK uspešno otvoren za instalaciju!');
          onProgress?.call('✅ Android installer otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } else {
          debugPrint('⚠️ OpenFileX nije uspeo: ${result.message}');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ OpenFileX failed: $e');
        debugPrint('   Stack trace: $stackTrace');
      }

      // METOD 2: URL Launcher sa različitim modovima
      final launchModes = [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
        LaunchMode.externalNonBrowserApplication,
      ];

      for (int i = 0; i < launchModes.length; i++) {
        try {
          debugPrint('📱 Pokušavam URL Launcher (mod ${i + 1})...');
          final success = await launchUrl(
            Uri.parse('file://$apkPath'),
            mode: launchModes[i],
          );

          if (success) {
            debugPrint('✅ URL Launcher pozvan uspešno (mod ${i + 1})');
            onProgress?.call('✅ Android installer otvoren!', 1.0);
            await _showInstallSuccessNotification();
            return;
          } else {
            debugPrint('⚠️ URL Launcher mod ${i + 1} nije uspeo');
          }
        } catch (e) {
          debugPrint('❌ URL Launcher mod ${i + 1} failed: $e');
        }
      }

      // METOD 3: Specifično za Huawei - pokušaj sa intent://
      if (isHuawei) {
        try {
          debugPrint('📱 Pokušavam Huawei intent metod...');
          final huaweiUri =
              'intent:///$apkPath#Intent;action=android.intent.action.VIEW;type=application/vnd.android.package-archive;end';
          final success = await launchUrl(
            Uri.parse(huaweiUri),
            mode: LaunchMode.externalApplication,
          );

          if (success) {
            debugPrint('✅ Huawei intent metod uspešan!');
            onProgress?.call('✅ Huawei installer otvoren!', 1.0);
            await _showInstallSuccessNotification();
            return;
          }
        } catch (e) {
          debugPrint('❌ Huawei intent metod failed: $e');
        }

        // DODATNI HUAWEI METODI za Mate 40 Pro
        try {
          debugPrint('📱 METOD 3A: Pokušavam Huawei File Manager...');
          await launchUrl(
            Uri.parse(
                'android-app://com.huawei.hidisk/content/apk?path=$apkPath'),
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ Huawei File Manager pozvan!');
          onProgress?.call('✅ Huawei File Manager otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ Huawei File Manager metod failed: $e');
        }

        // SPECIJALNO ZA MATE 40 PRO - HarmonyOS intent
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        if (deviceInfo.model.toLowerCase().contains('mate 40')) {
          try {
            debugPrint(
                '📱 METOD 3B: HarmonyOS specifični metod za Mate 40 Pro...');
            await launchUrl(
              Uri.parse('harmony://install?path=$apkPath'),
              mode: LaunchMode.externalApplication,
            );
            debugPrint('✅ HarmonyOS intent pozvan!');
            onProgress?.call('✅ HarmonyOS installer otvoren!', 1.0);
            await _showInstallSuccessNotification();
            return;
          } catch (e) {
            debugPrint('❌ HarmonyOS intent failed: $e');
          }

          // Pokušaj sa HiSuite adb bridge
          try {
            debugPrint('📱 METOD 3C: HiSuite ADB bridge...');
            await launchUrl(
              Uri.parse('hisuite://install?source=$apkPath'),
              mode: LaunchMode.externalApplication,
            );
            debugPrint('✅ HiSuite ADB pozvan!');
            onProgress?.call('✅ HiSuite installer pozvan!', 1.0);
            await _showInstallSuccessNotification();
            return;
          } catch (e) {
            debugPrint('❌ HiSuite ADB failed: $e');
          }
        }

        // Pokušaj sa EMUI package installer
        try {
          debugPrint('📱 METOD 3D: Pokušavam EMUI Package Installer...');
          await launchUrl(
            Uri.parse('package://install?source=external&path=$apkPath'),
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ EMUI Package Installer pozvan!');
          onProgress?.call('✅ EMUI installer otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ EMUI Package Installer failed: $e');
        }
      }

      // METOD 4: Specifično za Samsung Galaxy - pokušaj sa Samsung Galaxy Store intent
      final isSamsung = await _isSamsungDevice();
      if (isSamsung) {
        try {
          debugPrint('📱 METOD 4A: Pokušavam Samsung Galaxy Store intent...');
          await launchUrl(
            Uri.parse('samsungapps://ProductDetail/$apkPath'),
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ Samsung Galaxy Store intent pozvan!');
          onProgress?.call('✅ Samsung Galaxy Store otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ Samsung Galaxy Store intent failed: $e');
        }

        // Samsung Knox specific metod
        try {
          debugPrint(
              '📱 METOD 4B: Pokušavam Samsung Knox package installer...');
          final intent = AndroidIntent(
            action: 'com.samsung.android.knox.intent.action.INSTALL_PACKAGE',
            data: Uri.file(apkPath).toString(),
            type: 'application/vnd.android.package-archive',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
            ],
          );
          await intent.launch();
          debugPrint('✅ Samsung Knox installer pozvan!');
          onProgress?.call('✅ Samsung Knox installer otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ Samsung Knox installer failed: $e');
        }

        // Samsung My Files app
        try {
          debugPrint('📱 METOD 4C: Pokušavam Samsung My Files app...');
          await launchUrl(
            Uri.parse('com.sec.android.app.myfiles://files?path=$apkPath'),
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ Samsung My Files pozvan!');
          onProgress?.call('✅ Samsung My Files otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ Samsung My Files failed: $e');
        }

        // Samsung One UI specific intent
        try {
          debugPrint('📱 METOD 4D: Pokušavam One UI Package Installer...');
          final intent = AndroidIntent(
            action:
                'com.samsung.android.packageinstaller.action.INSTALL_PACKAGE',
            data: Uri.file(apkPath).toString(),
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
            ],
          );
          await intent.launch();
          debugPrint('✅ One UI Package Installer pozvan!');
          onProgress?.call('✅ One UI installer otvoren!', 1.0);
          await _showInstallSuccessNotification();
          return;
        } catch (e) {
          debugPrint('❌ One UI Package Installer failed: $e');
        }
      }

      // METOD DESPERATION: Kopiraj APK u javnu Downloads folder
      try {
        debugPrint('� METOD DESPERATION: Kopiram APK u Downloads folder...');

        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        const publicApkPath = '/storage/emulated/0/Download/gavra_update.apk';
        await File(apkPath).copy(publicApkPath);

        debugPrint('✅ APK kopiran u: $publicApkPath');

        // Pokušaj instalaciju iz javnog foldera
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: Uri.file(publicApkPath).toString(),
          type: 'application/vnd.android.package-archive',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint('✅ Public Downloads installer pozvan!');
        onProgress?.call('✅ Installer iz Downloads foldera otvoren!', 1.0);
        await _showInstallSuccessNotification();
        return;
      } catch (e) {
        debugPrint('❌ Public Downloads metod failed: $e');
      }

      // METOD SUPER-SIMPLE: Samo otvori fajl bez intenta
      try {
        debugPrint('📂 METOD SUPER-SIMPLE: Jednostavno otvori fajl...');
        await launchUrl(Uri.file(apkPath));
        debugPrint('✅ Fajl otvoren!');
        onProgress?.call('✅ Fajl otvoren!', 1.0);
        await _showInstallSuccessNotification();
        return;
      } catch (e) {
        debugPrint('❌ Super simple metod failed: $e');
      }

      // METOD 5: Za Huawei - pokušaj sa system file manager intent
      if (isHuawei) {
        try {
          debugPrint('📂 METOD 5: Huawei System File Manager intent...');
          final intent = AndroidIntent(
            action: 'android.intent.action.GET_CONTENT',
            type: '*/*',
            data: Uri.file(apkPath).toString(),
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
          debugPrint('✅ System File Manager pozvan!');
          onProgress?.call(
              '✅ File Manager otvoren - PRONAĐI I TAP-UJ APK FAJL', 1.0);
          await _showHuaweiManualInstallNotification();
          return;
        } catch (e) {
          debugPrint('❌ System File Manager intent failed: $e');
        }

        try {
          debugPrint('📂 METOD 6: Eksplicitni Files app intent...');
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            type: 'resource/folder',
            data: Uri.parse('file://${Directory(apkPath).parent.path}')
                .toString(),
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
          debugPrint('✅ Files app pozvan!');
          onProgress?.call(
              '✅ Files app otvoren - PRONAĐI gavra_update APK FAJL', 1.0);
          await _showHuaweiManualInstallNotification();
          return;
        } catch (e) {
          debugPrint('❌ Files app intent failed: $e');
        }
      }

      // Poslednja opcija - prikaži detaljne instrukcije korisniku
      debugPrint(
          '💡 INSTRUKCIJE: Idi u Downloads folder i instaliraj APK manuelno');
      if (isHuawei) {
        onProgress?.call(
            '📋 INSTRUKCIJE ZA HUAWEI: Otvori File Manager → Downloads folder → pronađi gavra_update_*.apk → tap na fajl → Instaliraj',
            1.0);
        await _showHuaweiManualInstallNotification();
      } else {
        onProgress?.call(
            '💡 INSTRUKCIJE: Idi u Downloads folder i manuelno tap-uj na gavra_update_*.apk fajl',
            1.0);
        await _showInstallFailedNotification();
      }
    } catch (e) {
      debugPrint('❌ GREŠKA pri instalaciji APK: $e');
      onProgress?.call('❌ Greška pri instalaciji', 0.0);
      await _showInstallErrorNotification('Neočekivana greška: $e');
    }
  }

  /// Prikazuje notifikaciju kada je instalacija uspešna
  static Future<void> _showInstallSuccessNotification() async {
    try {
      final isHuawei = await _isHuaweiDevice();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'gavra_install',
        'Gavra Install Status',
        channelDescription: 'Status notifikacije za instalaciju',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final message = isHuawei
          ? 'USPEŠNO! Installer je otvoren na Huawei uređaju. INSTRUKCIJE: Ako se pita za dozvole, tap DOZVOITI. Potom tap INSTALIRAJ. Ako se installer nije pojavio, idi u Downloads folder i pronađi gavra_update_*.apk fajl.'
          : 'USPEŠNO! Android installer je otvoren. INSTRUKCIJE: Tap INSTALIRAJ na dijalogu koji se pojavio. Prati korake na ekranu.';

      await _notifications.show(
        2,
        '✅ Gavra App - Instalacija u toku',
        message,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Greška pri prikazivanju success notifikacije: $e');
    }
  }

  /// Prikazuje notifikaciju kada instalacija potpuno ne radi
  static Future<void> _showInstallFailedNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'gavra_install',
        'Gavra Install Status',
        channelDescription: 'Status notifikacije za instalaciju',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notifications.show(
        4,
        '❌ Gavra App - Potrebne su manuelne instrukcije',
        'INSTRUKCIJE ZA INSTALACIJU: 1) Otvori File Manager aplikaciju 2) Idi u Downloads folder 3) Pronađi fajl gavra_update_*.apk 4) Tap na fajl 5) Tap INSTALIRAJ 6) Ako pita za dozvole - tap DOZVOITI',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Greška pri prikazivanju failed notifikacije: $e');
    }
  }

  /// Prikazuje notifikaciju za specifične greške
  static Future<void> _showInstallErrorNotification(String errorMessage) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'gavra_install',
        'Gavra Install Status',
        channelDescription: 'Status notifikacije za instalaciju',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notifications.show(
        5,
        '⚠️ Gavra App - Greška instalacije',
        errorMessage,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Greška pri prikazivanju error notifikacije: $e');
    }
  }

  /// Prikazuje specifičnu notifikaciju za Huawei manuелnu instalaciju
  static Future<void> _showHuaweiManualInstallNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'gavra_install',
        'Gavra Install Status',
        channelDescription: 'Status notifikacije za instalaciju',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notifications.show(
        6,
        '📱 Gavra App - HUAWEI/HONOR specifične instrukcije',
        'DETALJNE INSTRUKCIJE ZA HUAWEI UREĐAJE:\n\n1. Otvori "File Manager" aplikaciju (ikona foldera)\n2. Tap na "Downloads" folder\n3. Pronaći fajl koji počinje sa "gavra_update" i završava sa ".apk"\n4. TAP na taj APK fajl\n5. Ako pita "Dozvoliti instalaciju iz nepoznatih izvora" - tap DOZVOITI\n6. Tap INSTALIRAJ dugme\n7. Čekaj da se instalacija završi\n\nAko ne vidiš APK fajl, možda je u "Internal storage" folderu.',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Greška pri prikazivanju Huawei notifikacije: $e');
    }
  }
}
