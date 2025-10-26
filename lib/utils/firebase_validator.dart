// Firebase diagnostic validator for Gavra project
// This file provides Firebase connection validation and diagnostic information

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseValidator {
  static bool _initialized = false;

  /// Check if Firebase is properly initialized
  static bool get isInitialized => _initialized;

  /// Validate Firebase configuration and connection
  static Future<Map<String, dynamic>> validateFirebaseSetup() async {
    final Map<String, dynamic> status = {
      'initialized': false,
      'auth_configured': false,
      'firestore_configured': false,
      'errors': <String>[],
      'project_id': null,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Check Firebase initialization
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _initialized = true;
      status['initialized'] = true;

      // Get project ID
      final app = Firebase.app();
      status['project_id'] = app.options.projectId;

      // Check Auth configuration
      try {
        final auth = FirebaseAuth.instance;
        status['auth_configured'] = auth.app.options.projectId.isNotEmpty;
      } catch (e) {
        status['errors'].add('Auth configuration error: ${e.toString()}');
      }

      // Check Firestore configuration
      try {
        final firestore = FirebaseFirestore.instance;
        status['firestore_configured'] =
            firestore.app.options.projectId.isNotEmpty;

        // Test basic Firestore connection
        await firestore.enableNetwork();
      } catch (e) {
        status['errors'].add('Firestore configuration error: ${e.toString()}');
      }
    } catch (e) {
      status['errors'].add('Firebase initialization error: ${e.toString()}');
    }

    return status;
  }

  /// Test Firestore connection with a simple read operation
  static Future<bool> testFirestoreConnection() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Try to read from a basic collection (this should work even if collection doesn't exist)
      await firestore.collection('test').limit(1).get();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get Firebase project information
  static Map<String, String?> getProjectInfo() {
    if (!_initialized || Firebase.apps.isEmpty) {
      return {'error': 'Firebase not initialized'};
    }

    final app = Firebase.app();
    return {
      'project_id': app.options.projectId,
      'api_key': app.options.apiKey,
      'app_id': app.options.appId,
      'messaging_sender_id': app.options.messagingSenderId,
    };
  }

  /// Check if running in emulator mode
  static bool isEmulatorMode() {
    try {
      // This is a basic check - in production you might want more sophisticated detection
      final firestore = FirebaseFirestore.instance;
      final settings = firestore.settings;

      // Check if connected to emulator (this is a simplified check)
      return settings.host?.contains('localhost') == true ||
          settings.host?.contains('127.0.0.1') == true;
    } catch (e) {
      return false;
    }
  }

  /// Force initialize Firebase with error handling
  static Future<bool> forceInitialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
      return true;
    } catch (e) {
      print('Force initialization failed: $e');
      return false;
    }
  }
}
