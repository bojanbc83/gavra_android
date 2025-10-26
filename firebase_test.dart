import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🔥 FIREBASE FCM TEST SCRIPT
/// Testira Firebase Cloud Messaging konfiguraciju i šalje test notifikaciju
void main() async {
  print('🔥 FIREBASE FCM TEST SCRIPT');
  print('================================\n');

  // Firebase project podaci
  const String projectId = 'gavra-notif-20250920162521';
  const String messagingSenderId = '208019335309';

  print('📋 FIREBASE PROJECT INFO:');
  print('Project ID: $projectId');
  print('Messaging Sender ID: $messagingSenderId');
  print('Package: com.gavra013.gavra_android\n');

  // Proveri google-services.json
  await _checkGoogleServicesJson();

  // Proveri Firebase opcije
  await _checkFirebaseOptions();

  // Test FCM konfiguracije (potreban je server key)
  await _testFCMConfiguration();

  print('\n🎯 ZAVRŠENO! Proveri rezultate iznad.');
}

/// Proveri google-services.json fajl
Future<void> _checkGoogleServicesJson() async {
  print('📄 PROVERAVAM google-services.json...');

  final file = File('android/app/google-services.json');
  if (!file.existsSync()) {
    print('❌ google-services.json NE POSTOJI!');
    return;
  }

  try {
    final content = file.readAsStringSync();
    final json = jsonDecode(content);

    final projectId = json['project_info']['project_id'];
    final appId = json['client'][0]['client_info']['mobilesdk_app_id'];
    final packageName =
        json['client'][0]['client_info']['android_client_info']['package_name'];

    print('✅ google-services.json OK');
    print('   Project ID: $projectId');
    print('   App ID: $appId');
    print('   Package: $packageName\n');
  } catch (e) {
    print('❌ Greška u čitanju google-services.json: $e\n');
  }
}

/// Proveri firebase_options.dart
Future<void> _checkFirebaseOptions() async {
  print('🔧 PROVERAVAM firebase_options.dart...');

  final file = File('lib/firebase_options.dart');
  if (!file.existsSync()) {
    print('❌ firebase_options.dart NE POSTOJI!');
    return;
  }

  try {
    final content = file.readAsStringSync();

    if (content.contains('gavra-notif-20250920162521') &&
        content.contains('208019335309') &&
        content.contains('AIzaSyCJBzCgsh9VkiUS_4xAPaiQlpkffX03FeA')) {
      print('✅ firebase_options.dart OK - svi podaci se poklapaju\n');
    } else {
      print('⚠️ firebase_options.dart - podaci se ne poklapaju!\n');
    }
  } catch (e) {
    print('❌ Greška u čitanju firebase_options.dart: $e\n');
  }
}

/// Test FCM konfiguracije (zahteva server key)
Future<void> _testFCMConfiguration() async {
  print('🌐 FCM TEST KONFIGURACIJA:');
  print('Za testiranje notifikacija trebaš:');
  print('');
  print('1. 🔑 SERVER KEY iz Firebase Console:');
  print(
      '   https://console.firebase.google.com/project/gavra-notif-20250920162521/settings/cloudmessaging');
  print('');
  print('2. 📨 TEST CURL KOMANDA:');
  print(_getTestCurlCommand());
  print('');
  print('3. 🎯 EXPECTED PAYLOAD za tvoju aplikaciju:');
  print(_getExpectedPayload());
  print('');
  print('4. 🧪 FLUTTER TEST iz aplikacije:');
  print(
      '   await RealtimeNotificationService.sendTestNotification("Test poruka");');
  print('');

  // Proveri da li je Http package dostupan za test
  try {
    final response = await http.get(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {'Authorization': 'key=TEST'},
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 401) {
      print('✅ FCM endpoint dostupan (401 = potreban valjan server key)');
    }
  } catch (e) {
    print('⚠️ FCM endpoint test neuspešan: $e');
  }
}

/// Generiši test CURL komandu
String _getTestCurlCommand() {
  return '''
curl -X POST https://fcm.googleapis.com/fcm/send \\
  -H "Authorization: key=YOUR_SERVER_KEY_HERE" \\
  -H "Content-Type: application/json" \\
  -d '{
    "to": "/topics/gavra_all_drivers",
    "data": {
      "type": "dodat",
      "datum": "${DateTime.now().toIso8601String().split('T')[0]}",
      "putnik": "{\\"ime\\": \\"Test Putnik\\", \\"id\\": \\"123\\"}"
    },
    "notification": {
      "title": "✅ Test Putnik Dodat",
      "body": "Test putnik je dodat za danas - Firebase test"
    }
  }'
''';
}

/// Expected payload format
String _getExpectedPayload() {
  return '''
{
  "type": "dodat" | "otkazan" | "novi_putnik" | "otkazan_putnik",
  "datum": "YYYY-MM-DD" (mora biti današnji!),
  "putnik": "JSON string sa podatcima o putniku"
}
''';
}
