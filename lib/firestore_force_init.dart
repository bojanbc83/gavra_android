import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// 🔥 GAVRA 013 - FIRESTORE FORCE INITIALIZER
///
/// Flutter app that forces Firestore database creation
/// Run with: flutter run lib/firestore_force_init.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Get Firestore instance - this should force database creation
    final firestore = FirebaseFirestore.instance;
    // Try to create initial documents in each collection
    await forceCreateCollections(firestore);
  } catch (e) {}
}

Future<void> forceCreateCollections(FirebaseFirestore firestore) async {
  final collections = [
    {'name': 'vozaci', 'count': 4},
    {'name': 'mesecni_putnici', 'count': 96},
    {'name': 'putovanja_istorija', 'count': 120},
  ];

  for (final collection in collections) {
    try {
      // Create an initial document to force collection creation
      await firestore
          .collection(collection['name'] as String)
          .doc('init_doc')
          .set({
        'initialized': true,
        'expected_records': collection['count'],
        'created_at': FieldValue.serverTimestamp(),
        'description':
            'Initial document to force collection creation - can be deleted after import',
        'status': 'awaiting_csv_import'
      });
    } catch (e) {}
  }

  try {
    await firestore.collection('vozaci').limit(1).get();
  } catch (e) {
    // Ignore connection errors during initialization
  }
}
