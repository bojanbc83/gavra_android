import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/simple_usage_monitor.dart';
import 'services/theme_service.dart';
import 'supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📊 POKRETANJE MONITORING SERVISA
  try {
    await SimpleUsageMonitor.pokreni();
  } catch (e) {
    // Ignoriši greške u monitoring-u
  }

  // 🌐 SUPABASE INICIJALIZACIJA
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    // Continue without Supabase if it fails
  }

  runApp(const MyApp());
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 🚀 BRZA INICIJALIZACIJA
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Učitaj temu
      final nocniRezim = await ThemeService.isNocniRezim();

      if (mounted) {
        setState(() {
          _nocniRezim = nocniRezim;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gavra 013',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.svetlaTema(),
      darkTheme: ThemeService.tamnaTema(),
      themeMode: _nocniRezim ? ThemeMode.dark : ThemeMode.light,
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

    return const WelcomeScreen();
  }
}
