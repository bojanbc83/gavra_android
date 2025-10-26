import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

class RealtimeNotificationService {
  /// Real-time notification service using Firebase FCM + Local notifications
  /// OneSignal removed for security and simplicity - Firebase FCM is sufficient

  /// Firebase FCM configuration - clean and secure

  /// Public helper to handle an initial/cold-start RemoteMessage (from getInitialMessage)
  static Future<void> handleInitialMessage(RemoteMessage? message) async {
    if (message == null) return;
    try {
      await _handleFirebaseNotificationTap(message);
    } catch (e) {
      // Logger removed
    }
  }

  /// Initialize service with Firebase FCM + Local notifications support
  static Future<void> initialize() async {}

  /// Setup foreground Firebase message listeners for real-time notifications
  static void listenForForegroundNotifications(BuildContext context) {
    // Logger removed

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Logger removed

      // Filtriraj notifikacije: samo za današnji dan i za tip "dodat"/"novi_putnik" ili "otkazan"/"otkazan_putnik"
      final data = message.data;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final datumString = (data['datum'] ?? data['date'] ?? '') as String;
      final danas = DateTime.now();
      bool isToday = false;
      if (datumString.isNotEmpty) {
        try {
          final datum = DateTime.parse(datumString);
          isToday = datum.year == danas.year &&
              datum.month == danas.month &&
              datum.day == danas.day;
        } catch (_) {
          isToday = false;
        }
      }

      if ((type == 'dodat' ||
              type == 'novi_putnik' ||
              type == 'otkazan' ||
              type == 'otkazan_putnik') &&
          isToday) {
        LocalNotificationService.showRealtimeNotification(
          title: message.notification?.title ?? 'Gavra Notification',
          body: message.notification?.body ?? 'Nova poruka',
          payload: (message.data['type'] as String?) ?? 'firebase_foreground',
        );
      } else {}
    });

    // Listen for message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Logger removed
      // Handle navigation based on message data
      _handleFirebaseNotificationTap(message);
    });
  }

  /// Subscribe to Firebase topics for driver-specific notifications
  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) {
      // Logger removed
      return;
    }

    try {
      // Logger removed

      // Subscribe to general topic
      await FirebaseMessaging.instance.subscribeToTopic('gavra_all_drivers');

      // Subscribe to driver-specific topic
      await FirebaseMessaging.instance
          .subscribeToTopic('gavra_driver_${driverId.toLowerCase()}');

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// Real-time notifications using Firebase + OneSignal + Local notifications
  static void sendRealtimeNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    // Logger removed

    try {
      // 1. Send local notification immediately (highest priority)
      // Convert data to JSON string payload for notification
      final String payloadJson = jsonEncode(data);

      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: payloadJson,
      );
      // Logger removed

      // 2. Firebase Cloud Messaging (server-side implementation needed)
      // Note: FCM sending is typically done from server, not client
      // Local notifications provide immediate delivery for now
      // OneSignal removed - Firebase FCM + Local notifications are sufficient
    } catch (e) {
      // Logger removed
    }
  }

  static Future<void> sendTestNotification(String message) async {
    // Show local notification
    await LocalNotificationService.showRealtimeNotification(
      title: 'Gavra Test - Firebase FCM',
      body: message,
      payload: 'test_notification',
    );
  }

  /// Check notification permissions for Firebase
  static Future<bool> hasNotificationPermissions() async {
    // Logger removed
    try {
      NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      bool hasPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      // Logger removed
      return hasPermission;
    } catch (e) {
      // Logger removed
      return false;
    }
  }

  /// Request notification permissions for Firebase
  static Future<bool> requestNotificationPermissions() async {
    // Logger removed
    try {
      // Check if Firebase is available first
      if (!Firebase.apps.isNotEmpty) {
        // Logger removed
        return false;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission()
          .timeout(const Duration(seconds: 10));

      bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      // Logger removed
      return granted;
    } catch (e) {
      // Logger removed
      // Return false but don't crash the app
      return false;
    }
  }

  /// Handle Firebase notification tap - navigate to specific passenger
  static Future<void> _handleFirebaseNotificationTap(
    RemoteMessage message,
  ) async {
    try {
      // Logger removed

      // Extract notification type and passenger data from Firebase message
      final notificationType = message.data['type'] ?? 'unknown';
      final putnikDataString = message.data['putnik'] as String?;

      if (putnikDataString != null) {
        // Parse passenger data from JSON string
        final Map<String, dynamic> putnikData =
            jsonDecode(putnikDataString) as Map<String, dynamic>;

        // Use NotificationNavigationService to show popup and navigate
        await NotificationNavigationService.navigateToPassenger(
          type: notificationType as String,
          putnikData: putnikData,
        );
      } else {
        // Logger removed
      }
    } catch (e) {
      // Logger removed
    }
  }
}
