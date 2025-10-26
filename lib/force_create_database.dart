import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// 🔥 GAVRA 013 - FORCE CREATE FIRESTORE DATABASE
///
/// This will FORCE create Firestore database by initializing Firebase
/// and making first write operation

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Get Firestore instance - this will create database if it doesn't exist
    final firestore = FirebaseFirestore.instance;

    // Force create collections by writing dummy documents
    await firestore.collection('vozaci').doc('init').set({
      'initialized': true,
      'created_at': FieldValue.serverTimestamp(),
      'message': 'Database created successfully!'
    });

    await firestore.collection('mesecni_putnici').doc('init').set({
      'initialized': true,
      'created_at': FieldValue.serverTimestamp(),
      'message': 'Database created successfully!'
    });

    await firestore.collection('putovanja_istorija').doc('init').set({
      'initialized': true,
      'created_at': FieldValue.serverTimestamp(),
      'message': 'Database created successfully!'
    });

    print(
        '🔗 Check: https://console.firebase.google.com/project/gavra-notif-20250920162521/firestore');
  } catch (e) {
    print('❌ Error creating database: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Database Created!'),
        ),
      ),
    );
  }
}
