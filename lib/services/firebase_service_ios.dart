// Firebase Service - FULL iOS SUPPORT
// Full Firebase implementation identical to Android for complete feature parity
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../screens/danas_screen.dart';
import '../screens/home_screen.dart';
import 'local_notification_service.dart';

class FirebaseService {
  static final Logger _logger = Logger();

  /// Full Firebase initialization for iOS - identical to Android
  static Future<void> initialize() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      _logger.i('🍎 Firebase messaging permissions granted for iOS');
    } catch (e) {
      _logger.e('🍎 Error initializing Firebase for iOS: $e');
    }
  }

  /// iOS Compatible - Returns stored driver or 'anonymous'
  static Future<String?> getCurrentDriver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driver = prefs.getString('current_driver') ?? 'anonymous';
      _logger.i('🍎 iOS Driver: $driver (from SharedPreferences)');
      return driver;
    } catch (e) {
      _logger.e('Error getting driver: $e');
      return 'anonymous';
    }
  }

  /// iOS Compatible - Stores driver in SharedPreferences
  static Future<void> setCurrentDriver(String driver) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_driver', driver);
      _logger.i('🍎 iOS Driver saved: $driver');
    } catch (e) {
      _logger.e('Error saving driver: $e');
    }
  }

  /// Full FCM setup for iOS - identical to Android
  static Future<void> setupFCMNotifications() async {
    try {
      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _logger.i('🍎 iOS FCM Token: ${token.substring(0, 50)}...');
      }

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        _logger.i('🍎 iOS FCM Token refreshed: ${token.substring(0, 50)}...');
      });
    } catch (e) {
      _logger.e('🍎 Error setting up FCM for iOS: $e');
    }
  }

  /// Full foreground notification listener for iOS - identical to Android
  static void setupForegroundNotificationListener(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i(
          '🍎 iOS Foreground message received: ${message.notification?.title}');

      // Show local notification with smart navigation
      LocalNotificationService.showRealtimeNotification(
        title: message.notification?.title ?? 'Gavra Bus',
        body: message.notification?.body ?? 'Nova notifikacija',
        payload: message.data.isNotEmpty
            ? message.data.toString()
            : '{"type": "general", "message": "${message.notification?.body ?? ""}"}',
      );
    });

    // Handle notification tap when app is in foreground/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('🍎 iOS Notification tapped: ${message.notification?.title}');
      _handleNotificationTap(context, message.data);
    });
  }

  /// Full background handler for iOS - identical to Android
  static void setupBackgroundNotificationHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  /// Background message handler for iOS
  static Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
    _logger.i('🍎 iOS Background message: ${message.notification?.title}');

    // Show notification with smart navigation data
    await LocalNotificationService.showRealtimeNotification(
      title: message.notification?.title ?? 'Gavra Bus',
      body: message.notification?.body ?? 'Nova notifikacija',
      payload: message.data.isNotEmpty
          ? message.data.toString()
          : '{"type": "general", "message": "${message.notification?.body ?? ""}"}',
    );
  }

  /// Handle notification tap with smart navigation for iOS
  static void _handleNotificationTap(
      BuildContext context, Map<String, dynamic> data) {
    try {
      // Parse notification data for smart navigation
      String? putnikIme = data['putnik_ime'];
      String? grad = data['grad'];
      String? vreme = data['vreme'];

      if (putnikIme != null || grad != null || vreme != null) {
        // Navigate to DanasScreen with auto-filters
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DanasScreen(
              highlightPutnikIme: putnikIme,
              filterGrad: grad,
              filterVreme: vreme,
            ),
          ),
        );
      } else {
        // Default navigation
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      _logger.e('🍎 Error handling notification tap: $e');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  /// Full topic subscription for iOS - identical to Android
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      _logger.i('🍎 iOS subscribed to topic: $topic');
    } catch (e) {
      _logger.e('🍎 Error subscribing to topic $topic: $e');
    }
  }

  /// Full topic unsubscription for iOS - identical to Android
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      _logger.i('🍎 iOS unsubscribed from topic: $topic');
    } catch (e) {
      _logger.e('🍎 Error unsubscribing from topic $topic: $e');
    }
  }

  /// Full FCM token retrieval for iOS - identical to Android
  static Future<String?> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _logger.i('🍎 iOS FCM Token retrieved: ${token.substring(0, 50)}...');
      }
      return token;
    } catch (e) {
      _logger.e('🍎 Error getting FCM token: $e');
      return null;
    }
  }
}
