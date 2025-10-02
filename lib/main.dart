// import 'services/permission_service.dart'; // Moved to WelcomeScreen
import 'dart:async';

// Firebase imports - enabled for multi-channel notifications
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'firebase_options.dart';
// 🤖 GitHub Actions Android workflow for unlimited free APK delivery
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/gps_service.dart';
import 'services/local_notification_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/sms_service.dart';
import 'services/theme_service.dart';
import 'services/timer_manager.dart';
import 'services/realtime_notification_counter_service.dart';
import 'services/firebase_service.dart';
import 'supabase_client.dart';
import 'services/realtime_service.dart';
import 'config/app_config.dart';
import 'utils/gbox_detector.dart';

final _logger = Logger();

// Globalni navigator key za pristup navigation iz bilo kog dela aplikacije
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Globalna funkcija za menjanje teme
void Function()? globalThemeToggler;
// Globalna funkcija za osvežavanje teme kada se vozač promeni
void Function()? globalThemeRefresher;

/// 📬 GLOBALNI BACKGROUND MESSAGE HANDLER
/// Firebase background handler for multi-channel notifications
/// Ovo mora biti top-level funkcija da bi radila kad je app zatvoren
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize only if not already initialized in this isolate
    final alreadyInitialized = Firebase.apps.isNotEmpty;
    if (!alreadyInitialized) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Ignore duplicate-init or platform-specific errors in background isolate
  }
  // Pozovi background-safe helper da prika6e lokalnu notifikaciju iz background isolate
  try {
    await LocalNotificationService.showNotificationFromBackground(
      title: message.notification?.title ?? 'Gavra Notification',
      body: message.notification?.body ?? 'Nova poruka',
      payload: message.data['type'] ?? 'firebase_background',
    );
  } catch (e) {
    _logger.w('⚠️ Failed to show background notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔧 Detect GBox environment for Huawei devices
  await GBoxDetector.configureForEnvironment();

  // 🚀 CACHE UKLONJEN - koristi direktne Supabase pozive

  // OneSignal initialization (legacy API)
  try {
    OneSignal.initialize(AppConfig.oneSignalAppId);
    OneSignal.User.pushSubscription.addObserver((state) {
      try {
        // OneSignal player ID logged
      } catch (_) {}
    });
  } catch (e) {
    _logger.w('\u26a0\ufe0f OneSignal initialization failed: $e');
  }

  // Firebase initialization - PRILAGOĐENO za GBox/Huawei
  try {
    final shouldOptimize = await GBoxDetector.shouldOptimizeFirebase();
    final timeout =
        shouldOptimize ? Duration(seconds: 10) : Duration(seconds: 20);

    // Check if Firebase is already initialized
    final alreadyInitialized = Firebase.apps.isNotEmpty;
    if (!alreadyInitialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(timeout);
    }

    // Registruj background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      await RealtimeNotificationService.handleInitialMessage(initialMessage);
    } catch (e) {
      _logger.w('\u26a0\ufe0f Error handling initial FCM message: $e');
    }

    // Initialize notification counter service and FCM listeners
    try {
      RealtimeNotificationCounterService.initialize();
    } catch (e) {
      _logger.w('⚠️ RealtimeNotificationCounterService init failed: $e');
    }

    try {
      FirebaseService.setupFCMListeners();
    } catch (e) {
      _logger.w('⚠️ FirebaseService.setupFCMListeners failed: $e');
    }
  } catch (e) {
    _logger.e('❌ Firebase initialization failed: $e');
    // Nastavi bez Firebase ako ne može - aplikacija neće da krahira
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    _logger.e('❌ Supabase initialization failed: $e');
    // Continue without Supabase if it fails
  }

  // Initialize GraphQL client
  final HttpLink httpLink = HttpLink(
    'https://gjtabtwudbrmfeyjiicu.supabase.co/graphql/v1',
    defaultHeaders: {'apiKey': supabaseAnonKey},
  );
  final Link link = httpLink;
  ValueNotifier<GraphQLClient> client =
      ValueNotifier(GraphQLClient(link: link, cache: GraphQLCache()));

  runApp(GraphQLProvider(client: client, child: const MyApp()));
}

// Simple helper instead of FirebaseService.getCurrentDriver()
Future<String?> getCurrentDriver() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('current_driver');
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  String? _initError;
  bool _nocniRezim = false;
  String? _currentDriver; // Dodano za temu
  // bool _permissionsRequested = false; // Removed - permissions now handled in WelcomeScreen

  @override
  void initState() {
    super.initState();
    _initializeTheme();
    _initializeCurrentDriver(); // Dodano

    // Postavi globalnu funkciju za theme toggle
    globalThemeToggler = toggleTheme;
    // Postavi globalnu funkciju za theme refresh
    globalThemeRefresher = refreshThemeForDriver;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Store context to check if widget is still mounted
      if (!mounted) return;

      // INICIJALIZUJ NOTIFIKACIJE SEKVENCIJALNO da izbegneš konflikte
      try {
        // 1. Prvo inicijalizuj lokalne notifikacije (bez permission zahteva)
        await LocalNotificationService.initialize(context);

        // 2. Zatim zatraži permissions jednom kroz Firebase sistem
        await RealtimeNotificationService.requestNotificationPermissions()
            .timeout(const Duration(seconds: 15));

        // 3. Inicijalizuj realtime notifikacije
        await RealtimeNotificationService.initialize();
        // Podesi URL servera koji forwarduje OneSignal pozive (postavi svoj URL ovde)
        RealtimeNotificationService.setOneSignalServerUrl(
            'http://localhost:3000/api/onesignal/notify');
        if (mounted) {
          RealtimeNotificationService.listenForForegroundNotifications(context);
        }

        // 4. Pretplati se na topike na osnovu vozača
        final vozacId = await getCurrentDriver();

        // Pokreni centralizovane realtime pretplate
        try {
          RealtimeService.instance.startForDriver(vozacId);

          // Forsiraj početno učitavanje podataka
          await RealtimeService.instance.refreshNow();
        } catch (e) {
          _logger.w('⚠️ RealtimeService.startForDriver failed: $e');
          // Pokušaj da pokreneš bez vozača kao fallback
          try {
            RealtimeService.instance.startForDriver(null);
            await RealtimeService.instance.refreshNow();
          } catch (fallbackError) {
            _logger.e('❌ RealtimeService fallback failed: $fallbackError');
          }
        }

        if (vozacId != null && vozacId.isNotEmpty) {
          await RealtimeNotificationService.subscribeToDriverTopics(vozacId);
        } else {
          _logger.w('⚠️ Nema logovanog vozača - notifikacije neće raditi');
          await RealtimeNotificationService.subscribeToDriverTopics(null);
        }
      } catch (e) {
        _logger.w('⚠️ Notification system error: $e');
        // Continue without notifications if they fail
      }

      // 📱 POKRETANJE SMS SERVISA za automatsko slanje poruka
      SMSService.startAutomaticSMSService();
    });

    _startPeriodicGpsSending();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔐 POZOVI PERMISSION SETUP kada je MaterialApp spreman
    _requestPermissionsWhenReady();
  }

  Future<void> _requestPermissionsWhenReady() async {
    // ⚠️ Permissions se sada pozivaju iz WelcomeScreen ili HomeScreen umesto odavde
    // jer ovaj context nije unutar MaterialApp strukture i izaziva MaterialLocalizations grešku
  }

  void _startPeriodicGpsSending() {
    // 🕐 KORISTI TIMER MANAGER za GPS slanje - SPREČAVA MEMORY LEAK
    (() async {
      final vozacId = await getCurrentDriver();
      if (vozacId == null || vozacId.isEmpty) return;

      // Otkaži postojeći GPS timer ako postoji
      TimerManager.cancelTimer('gps_periodic_sender');

      // Kreiraj novi timer sa Timer Manager-om
      TimerManager.createTimer(
        'gps_periodic_sender',
        const Duration(minutes: 1),
        () async {
          final currentVozacId = await getCurrentDriver();
          if (currentVozacId != null && currentVozacId.isNotEmpty) {
            GpsService.sendCurrentLocation(vozacId: currentVozacId);
          }
        },
        isPeriodic: true,
      );

      // Pošalji odmah na startu
      GpsService.sendCurrentLocation(vozacId: vozacId);
    })();
  }

  @override
  void dispose() {
    // 🧹 CLEANUP SVIH TIMER-A - SPREČAVA MEMORY LEAK
    TimerManager.cancelAllTimers();

    // 📱 ZAUSTAVITI SMS SERVIS
    SMSService.stopAutomaticSMSService();

    // Stop centralized realtime subscriptions
    try {
      RealtimeService.instance.stopForDriver();
    } catch (e) {
      _logger.w('⚠️ Error stopping RealtimeService: $e');
    }

    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Kratka pauza da se UI prikaže
      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 CACHE JE UKLONJEN - koristi direktne Supabase pozive

      // 🔐 INICIJALNI SETUP DOZVOLA se pomerio u didChangeDependencies()
      // da se izvrši kada je MaterialApp potpuno spreman

      // 🔄 RESETUJ KARTICE MESEČNIH PUTNIKA SVAKI PETAK
      try {
        // PutnikStatistike servis je uklonjen - placeholder
        // final putnikStatistike = PutnikStatistike();
        // await putnikStatistike.proveriIResetujKartice();
      } catch (e) {
        _logger.w('⚠️ Weekly card reset failed: $e');
        // Ne prekidaj inicijalizaciju aplikacije zbog greške u resetovanju
      }

      // Schema test removed to prevent startup crashes
      // await _testSchemaStructure();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _logger.e('❌ App initialization failed: $e');
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _initializeTheme() async {
    final nocniRezim = await ThemeService.isNocniRezim();
    if (mounted) {
      setState(() {
        _nocniRezim = nocniRezim;
      });
    }
  }

  Future<void> _initializeCurrentDriver() async {
    final driver = await getCurrentDriver();
    if (mounted) {
      setState(() {
        _currentDriver = driver;
      });
      // 💖 Tema se koristi
      if (driver?.toLowerCase() == 'svetlana') {
        // Pink theme activated
      } else {
        // Default blue theme activated
      }
    }
  }

  // 🎨 Javna funkcija za osvežavanje teme kada se vozač promeni
  void refreshThemeForDriver() async {
    await _initializeCurrentDriver();
  }

  void toggleTheme() async {
    final newTheme = await ThemeService.toggleNocniRezim();
    if (mounted) {
      setState(() {
        _nocniRezim = newTheme;
      });
    }
  }

  // 🎨 Javni getter za pristup theme toggle funkcionalnosti iz drugih delova app-a
  void Function() get themeToggler => toggleTheme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gavra 013',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Dodaj globalni navigator key
      theme: ThemeService.svetlaTema(
          driverName: _currentDriver), // 🎨 Svetla tema sa vozačem
      darkTheme: ThemeService.tamnaTema(), // 🎨 Tamna tema za noć
      themeMode: _nocniRezim
          ? ThemeMode.dark
          : ThemeMode.light, // 🎨 Dinamičko prebacivanje teme
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return LoadingScreen(error: _initError);
    }

    if (!_isInitialized) {
      return const LoadingScreen();
    }

    // Za testiranje GPS ekrana, zameni WelcomeScreen sa GpsDemoScreen
    // Kada završiš test, vrati WelcomeScreen
    return const WelcomeScreen(); // <- zameni sa GpsDemoScreen() za demo
    // return GpsDemoScreen();
  }
}
