import 'package:flutter/material.dart';

import '../theme.dart';

// 🎨 REGISTRY ZA SVE TEME - Lako dodavanje novih tema!
class ThemeRegistry {
  // 📝 Lista dostupnih tema
  static final Map<String, ThemeDefinition> _themes = {
    'triple_blue_fashion': ThemeDefinition(
      id: 'triple_blue_fashion',
      name: '⚡ Triple Blue Fashion',
      description: 'Electric + Ice + Neon kombinacija',
      colorScheme: tripleBlueFashionColorScheme,
      themeData: tripleBlueFashionTheme,
      styles: TripleBlueFashionStyles,
      gradient: tripleBlueFashionGradient,
      isDefault: true,
    ),
    'black_sapphire_metallic': ThemeDefinition(
      id: 'black_sapphire_metallic',
      name: '🖤 Black Sapphire Metallic',
      description: 'Dark seksi crni safir sa metalik šimmerima',
      colorScheme: blackSapphireMetallicColorScheme,
      themeData: blackSapphireMetallicTheme,
      styles: BlackSapphireMetallicStyles,
      gradient: blackSapphireMetallicGradient,
      tags: ['dark', 'metallic', 'elegant', 'sapphire'],
    ),
    // 🆕 Ovde ćemo dodavati nove teme...
  };

  /// Vraća sve dostupne teme
  static Map<String, ThemeDefinition> get allThemes => Map.unmodifiable(_themes);

  /// Vraća listu naziva tema za dropdown
  static List<String> get themeNames => _themes.keys.toList();

  /// Vraća listu display imena tema za dropdown
  static List<String> get themeDisplayNames => _themes.values.map((t) => t.name).toList();

  /// Vraća temu po ID-u
  static ThemeDefinition? getTheme(String themeId) => _themes[themeId];

  /// Vraća ThemeData po ID-u
  static ThemeData getThemeData(String themeId) {
    final theme = _themes[themeId];
    return theme?.themeData ?? _themes['triple_blue_fashion']!.themeData;
  }

  /// Vraća default temu
  static ThemeDefinition get defaultTheme {
    return _themes.values.firstWhere(
      (t) => t.isDefault,
      orElse: () => _themes['triple_blue_fashion']!,
    );
  }

  /// Registruje novu temu
  static void registerTheme(ThemeDefinition theme) {
    _themes[theme.id] = theme;
  }

  /// Proverava da li tema postoji
  static bool hasTheme(String themeId) => _themes.containsKey(themeId);

  /// Vraća ID teme po display imenu
  static String? getThemeIdByName(String displayName) {
    for (final entry in _themes.entries) {
      if (entry.value.name == displayName) {
        return entry.key;
      }
    }
    return null;
  }
}

// 🎭 Definicija teme - sve što treba za kompletnu temu
class ThemeDefinition {
  // za kategorije tema

  const ThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.colorScheme,
    required this.themeData,
    required this.styles,
    required this.gradient,
    this.isDefault = false,
    this.tags,
  });
  final String id;
  final String name;
  final String description;
  final ColorScheme colorScheme;
  final ThemeData themeData;
  final Type styles; // TripleBlueFashionStyles, itd.
  final LinearGradient gradient;
  final bool isDefault;
  final List<String>? tags;

  /// Kreira kopiju sa izmenjenim vrednostima
  ThemeDefinition copyWith({
    String? id,
    String? name,
    String? description,
    ColorScheme? colorScheme,
    ThemeData? themeData,
    Type? styles,
    LinearGradient? gradient,
    bool? isDefault,
    List<String>? tags,
  }) {
    return ThemeDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorScheme: colorScheme ?? this.colorScheme,
      themeData: themeData ?? this.themeData,
      styles: styles ?? this.styles,
      gradient: gradient ?? this.gradient,
      isDefault: isDefault ?? this.isDefault,
      tags: tags ?? this.tags,
    );
  }
}
