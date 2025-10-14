import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 🚀 CACHE SERVICE - Centralizovano cache-ovanje za performanse
class CacheService {
  static SharedPreferences? _prefs;
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};

  /// Inicijalizuj cache servis
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 📝 MEMORY CACHE - Za brz pristup u runtime-u
  static T? getFromMemory<T>(
    String key, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final timestamp = _cacheTimestamp[key];
    if (timestamp != null && DateTime.now().difference(timestamp) < maxAge) {
      return _memoryCache[key] as T?;
    }

    // Ukloni expired cache
    if (timestamp != null) {
      _memoryCache.remove(key);
      _cacheTimestamp.remove(key);
    }

    return null;
  }

  /// 💾 Sacuvaj u memory cache
  static void saveToMemory<T>(String key, T value) {
    _memoryCache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
    // Logger removed
  }

  /// 🗂️ PERSISTENT CACHE - Za dugoročno čuvanje
  static Future<T?> getFromDisk<T>(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    if (_prefs == null) return null;

    try {
      final timestampKey = '${key}_timestamp';
      final timestamp = _prefs!.getInt(timestampKey);

      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) > maxAge) {
          // Expired - ukloni
          await clearFromDisk(key);
          return null;
        }
      }

      final cachedData = _prefs!.getString(key);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData);
        // Logger removed
        return decoded as T;
      }
    } catch (e) {
      // Logger removed
    }

    return null;
  }

  /// 💾 Sacuvaj na disk
  static Future<void> saveToDisk<T>(String key, T value) async {
    if (_prefs == null) return;

    try {
      final timestampKey = '${key}_timestamp';
      final encoded = jsonEncode(value);

      await _prefs!.setString(key, encoded);
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 🗑️ Ukloni iz cache-a
  static Future<void> clearFromDisk(String key) async {
    if (_prefs == null) return;

    final timestampKey = '${key}_timestamp';
    await _prefs!.remove(key);
    await _prefs!.remove(timestampKey);
  }

  /// 🧹 Očisti sav cache
  static Future<void> clearAll() async {
    _memoryCache.clear();
    _cacheTimestamp.clear();

    if (_prefs != null) {
      await _prefs!.clear();
    }

    // Logger removed
  }

  /// 📊 Cache statistike
  static Map<String, dynamic> getStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'oldest_memory_cache': _cacheTimestamp.values.isNotEmpty
          ? _cacheTimestamp.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
          : 'N/A',
      'disk_cache_available': _prefs != null,
    };
  }
}

/// 🏷️ CACHE KEYS - Centralizovane konstante
class CacheKeys {
  // Geocoding cache
  static String geocoding(String address) => 'geocoding_$address';

  // Putnici cache
  static const String putnici = 'putnici_list';
  static String putniksByDay(String day) => 'putnici_$day';

  // Statistike cache
  static String statistikeVozac(String vozac, String period) => 'stats_${vozac}_$period';
  static String ukupneStatistike(String period) => 'total_stats_$period';

  // Adrese cache
  static String adrese(String grad) => 'adrese_$grad';

  // GPS cache
  static String gpsLokacije(String vozac) => 'gps_$vozac';

  // Mesečne karte cache
  static String mesecneKarte(String mesec) => 'mesecne_karte_$mesec';
}



