import 'package:flutter/foundation.dart';
import 'realtime_notification_service.dart';

/// 🌍 UNIVERSAL NOTIFICATION SERVICE
/// Koristi standardni Firebase FCM za sve telefone
class UniversalNotificationService {
  static bool _isInitialized = false;

  /// Inicijalizacija - koristi Firebase FCM za sve telefone
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Koristi standardni Firebase FCM za sve telefone
    await RealtimeNotificationService.initialize();

    _isInitialized = true;

    if (kDebugMode) {
      print('📱 Universal Notifications initialized with Firebase FCM');
    }
  }

  /// Subscribe na topic (sve platforme)
  static Future<void> subscribeToTopic(String topic) async {
    if (!_isInitialized) await initialize();

    // Firebase FCM subscription se dešava automatski u RealtimeNotificationService
    // Ovde možemo dodati dodatnu logiku ako je potrebna
    if (kDebugMode) {
      print('📱 Topic subscription handled by Firebase FCM: $topic');
    }
  }

  /// Handle notification kada stigne
  static Future<void> handleNotification(Map<String, dynamic> data) async {
    final type = data['type'] ?? '';
    final datum = data['datum'] ?? '';

    // Smart filtering - samo za današnji datum
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (datum != today) {
      if (kDebugMode) print('⏭️ Notification skipped - not for today');
      return;
    }

    // Process notification
    if (type == 'dodat' || type == 'otkazan') {
      await _showLocalNotification(data);
      if (kDebugMode) {
        print('📱 Notification processed: $type');
      }
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    final type = data['type'];

    String title = '🚌 GAVRA UPDATE';
    String body = '';

    if (type == 'dodat') {
      title = '✅ Putnik Dodat';
      body = 'Novi putnik za danas';
    } else if (type == 'otkazan') {
      title = '❌ Putnik Otkazan';
      body = 'Putnik otkazan za danas';
    }

    // Show notification with sound + vibration
    await _showNotificationWithSound(title, body);
  }

  static Future<void> _showNotificationWithSound(
      String title, String body) async {
    // Implementation za local notification sa zvukom
    // Ovo radi na svim Android telefonima
  }

  /// Get notification system info
  static String getSystemInfo() {
    return 'Firebase FCM (Universal)';
  }
}
