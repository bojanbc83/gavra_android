// Firebase Service - DISABLED FOR iOS BUILDS
// This service is replaced with OneSignal for iOS compatibility
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class FirebaseService {
  static final Logger _logger = Logger();

  /// iOS Compatible - No Firebase initialization needed
  static Future<void> initialize() async {
    _logger.i('🍎 FirebaseService DISABLED for iOS - using OneSignal instead');
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

  /// iOS Compatible - No FCM setup needed
  static Future<void> setupFCMNotifications() async {
    _logger.i('🍎 FCM Setup DISABLED for iOS - using OneSignal');
  }

  /// iOS Compatible - No FCM listeners needed
  static void setupForegroundNotificationListener(BuildContext context) {
    _logger.i('🍎 FCM Listeners DISABLED for iOS - using OneSignal');
  }

  /// iOS Compatible - No FCM background handler needed
  static void setupBackgroundNotificationHandler() {
    _logger.i('🍎 FCM Background DISABLED for iOS - using OneSignal');
  }

  /// iOS Compatible - Mock function for compatibility
  static Future<void> subscribeToTopic(String topic) async {
    _logger.i('🍎 Topic subscription DISABLED for iOS: $topic');
  }

  /// iOS Compatible - Mock function for compatibility
  static Future<void> unsubscribeFromTopic(String topic) async {
    _logger.i('🍎 Topic unsubscription DISABLED for iOS: $topic');
  }

  /// iOS Compatible - Mock function for compatibility
  static Future<String?> getToken() async {
    _logger.i('🍎 FCM Token DISABLED for iOS - using OneSignal');
    return null;
  }
}
