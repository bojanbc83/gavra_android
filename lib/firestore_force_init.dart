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

  print('🔥 GAVRA 013 - FIRESTORE FORCE INITIALIZER');
  print('=' * 50);

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // Get Firestore instance - this should force database creation
    final firestore = FirebaseFirestore.instance;
    print('✅ Firestore instance obtained');

    // Try to create initial documents in each collection
    await forceCreateCollections(firestore);

    print('');
    print('🎉 FIRESTORE DATABASE FORCED CREATION COMPLETE!');
    print(
        '🔗 Check Firebase Console: https://console.firebase.google.com/project/gavra-notif-20250920162521/firestore');
  } catch (e) {
    print('❌ Error: $e');
    print('');
    print('🔧 FALLBACK: Manual Firebase Console setup required');
  }
}

Future<void> forceCreateCollections(FirebaseFirestore firestore) async {
  final collections = [
    {'name': 'vozaci', 'count': 4},
    {'name': 'mesecni_putnici', 'count': 96},
    {'name': 'putovanja_istorija', 'count': 120},
  ];

  for (final collection in collections) {
    try {
      print('📝 Creating collection: ${collection['name']}');

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

      print(
          '   ✅ Collection ${collection['name'] as String} created with init document');
    } catch (e) {
      print('   ❌ Error creating ${collection['name']}: $e');
    }
  }

  // Test basic query to ensure database is working
  try {
    print('🔍 Testing database connectivity...');
    final snapshot = await firestore.collection('vozaci').limit(1).get();
    print(
        '   ✅ Database query successful - ${snapshot.docs.length} document(s) found');
  } catch (e) {
    print('   ❌ Database query failed: $e');
  }
}
