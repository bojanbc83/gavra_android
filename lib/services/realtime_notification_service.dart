import 'package:flutter/material.dart';
// Firebase messaging imports - disabled for iOS
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';
import 'package:logger/logger.dart';

class RealtimeNotificationService {
  static final Logger _logger = Logger();

  /// Initialize service (iOS compatible - no Firebase)
  static Future<void> initialize() async {
    _logger.i(
        '🔔 RealtimeNotificationService initialized for iOS - using OneSignal only');
  }

  /// DISABLED for iOS - Firebase messaging replaced with OneSignal only
  static void listenForForegroundNotifications(BuildContext context) {
    _logger.i('🔔 Firebase messaging DISABLED for iOS - using OneSignal only');
    // Firebase messaging functionality disabled for iOS builds
    // All notifications are handled by OneSignal instead
  }

  /// DISABLED for iOS - driver topics handled by OneSignal
  static Future<void> subscribeToDriverTopics(String? driverId) async {
    _logger.i(
        '🔔 Driver topics subscription DISABLED for iOS - using OneSignal only');
    // Driver topic subscription disabled for iOS builds
  }

  /// DISABLED for iOS - realtime notifications handled by OneSignal
  static void sendRealtimeNotification(
      String title, String body, Map<String, dynamic> data) {
    _logger.i(
        '🔔 Realtime notification sending DISABLED for iOS - using OneSignal only');
    // Realtime notification sending disabled for iOS builds
  }

  /// Test notification functionality (iOS compatible)
  static Future<void> sendTestNotification(String message) async {
    _logger.i('🔔 Test notification: $message (iOS compatible)');

    // Show local notification using OneSignal compatible method
    await LocalNotificationService.showRealtimeNotification(
      title: 'Gavra Test',
      body: message,
      payload: 'test_notification',
      playCustomSound: true,
    );
  }

  /// Check notification permissions (iOS compatible)
  static Future<bool> hasNotificationPermissions() async {
    _logger.i('🔔 Checking notification permissions (iOS compatible)');
    // Return true for now - actual permission check should be handled by OneSignal
    return true;
  }

  /// Request notification permissions (iOS compatible)
  static Future<bool> requestNotificationPermissions() async {
    _logger.i('🔔 Requesting notification permissions (iOS compatible)');
    // Return true for now - actual permission request should be handled by OneSignal
    return true;
  }
}
