import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_registry.dart';
import 'analytics_service.dart';

// 🎯 THEME MANAGER - Upravljanje trenutnom temom
class ThemeManager extends ChangeNotifier {
  factory ThemeManager() => _instance;
  ThemeManager._internal();
  static final ThemeManager _instance = ThemeManager._internal();

  static const String _selectedThemeKey = 'selected_theme_id';

  String _currentThemeId = 'triple_blue_fashion';
  ThemeDefinition? _currentTheme;

  /// Trenutna tema ID
  String get currentThemeId => _currentThemeId;

  /// Trenutna tema definicija
  ThemeDefinition get currentTheme {
    _currentTheme ??= ThemeRegistry.getTheme(_currentThemeId) ?? ThemeRegistry.defaultTheme;
    return _currentTheme!;
  }

  /// Trenutni ThemeData
  ThemeData get currentThemeData => currentTheme.themeData;

  /// Trenutni gradient
  LinearGradient get currentGradient => currentTheme.gradient;

  /// Initialize - učitaj poslednju selekciju
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString(_selectedThemeKey);

    if (savedThemeId != null && ThemeRegistry.hasTheme(savedThemeId)) {
      _currentThemeId = savedThemeId;
      _currentTheme = ThemeRegistry.getTheme(_currentThemeId);
    } else {
      // Fallback na default temu
      final defaultTheme = ThemeRegistry.defaultTheme;
      _currentThemeId = defaultTheme.id;
      _currentTheme = defaultTheme;
    }

    notifyListeners();
  }

  /// Promeni temu
  Future<void> changeTheme(String themeId) async {
    if (!ThemeRegistry.hasTheme(themeId)) {
      throw Exception('Tema $themeId ne postoji!');
    }

    final oldThemeId = _currentThemeId;
    _currentThemeId = themeId;
    _currentTheme = ThemeRegistry.getTheme(themeId);

    // Sačuvaj u SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedThemeKey, themeId);

    // Analytics - loguj promenu teme
    await _logThemeChange(oldThemeId, themeId);

    // Obavesti listenere
    notifyListeners();

    debugPrint('🎨 Tema promenjena: $oldThemeId → $themeId');
  }

  /// Promeni temu po display imenu
  Future<void> changeThemeByName(String displayName) async {
    final themeId = ThemeRegistry.getThemeIdByName(displayName);
    if (themeId != null) {
      await changeTheme(themeId);
    } else {
      throw Exception('Tema "$displayName" ne postoji!');
    }
  }

  /// Sledeća tema u listi (za cycling)
  Future<void> nextTheme() async {
    final themeNames = ThemeRegistry.themeNames;
    final currentIndex = themeNames.indexOf(_currentThemeId);
    final nextIndex = (currentIndex + 1) % themeNames.length;
    await changeTheme(themeNames[nextIndex]);
  }

  /// Prethodna tema u listi (za cycling)
  Future<void> previousTheme() async {
    final themeNames = ThemeRegistry.themeNames;
    final currentIndex = themeNames.indexOf(_currentThemeId);
    final previousIndex = (currentIndex - 1 + themeNames.length) % themeNames.length;
    await changeTheme(themeNames[previousIndex]);
  }

  /// Reset na default temu
  Future<void> resetToDefault() async {
    final defaultTheme = ThemeRegistry.defaultTheme;
    await changeTheme(defaultTheme.id);
  }

  /// Loguj promenu teme u analytics
  Future<void> _logThemeChange(String oldThemeId, String newThemeId) async {
    try {
      await AnalyticsService.logCustomEvent('tema_promenjena', {
        'stara_tema': oldThemeId,
        'nova_tema': newThemeId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('❌ Greška pri logovanju promene teme: $e');
    }
  }
}
