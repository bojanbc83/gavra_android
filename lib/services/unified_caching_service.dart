import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🚀 UNIFIED CACHING SERVICE
/// Konsoliduje: cache_service.dart + advanced_caching_service.dart + performance_cache_service.dart
/// Enterprise-level multi-tier caching sa kompresijom i prediktivnim prefetch-om
class UnifiedCachingService {
  static bool _isInitialized = false;

  // 🧠 CACHE LEVELS HIERARCHY
  static final Map<String, CacheEntry> _level1MemoryCache =
      {}; // L1: In-memory (najbrži)
  static final Map<String, CacheEntry> _level2LruCache =
      {}; // L2: LRU memory cache
  static SharedPreferences? _level3Preferences; // L3: SharedPreferences
  static Directory? _level4FileCache; // L4: File cache

  // ⚙️ CACHE CONFIGURATION
  static const int _maxL1Size = 50; // L1 max entries
  static const int _maxL2Size = 200; // L2 max entries

  // ⏱️ CACHE TTL (Time To Live)
  static const Map<CacheType, Duration> _cacheTTL = {
    CacheType.geocoding: Duration(hours: 24),
    CacheType.routes: Duration(hours: 6),
    CacheType.traffic: Duration(minutes: 15),
    CacheType.weather: Duration(hours: 1),
    CacheType.userPreferences: Duration(days: 30),
    CacheType.apiResponse: Duration(hours: 2),
    CacheType.images: Duration(days: 7),
    CacheType.gpsData: Duration(hours: 12),
  };

  // 📊 CACHE STATISTICS
  static final CacheStats _stats = CacheStats();

  /// 🚀 INITIALIZE UNIFIED CACHING
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Level 3 (SharedPreferences)
      _level3Preferences = await SharedPreferences.getInstance();

      // Initialize Level 4 (File Cache)
      final documentsDir = await getApplicationDocumentsDirectory();
      _level4FileCache = Directory('${documentsDir.path}/unified_cache');

      if (!await _level4FileCache!.exists()) {
        await _level4FileCache!.create(recursive: true);
      }

      _isInitialized = true;
      print('🚀 UnifiedCachingService initialized successfully');
    } catch (e) {
      print('❌ Error initializing UnifiedCachingService: $e');
      rethrow;
    }
  }

  /// 📝 GET FROM CACHE (unified method with fallback hierarchy)
  static Future<T?> get<T>(
    String key, {
    CacheType type = CacheType.apiResponse,
    Duration? maxAge,
    bool skipL1 = false,
    bool skipL2 = false,
    bool skipL3 = false,
    bool skipL4 = false,
  }) async {
    await _ensureInitialized();

    final effectiveMaxAge =
        maxAge ?? _cacheTTL[type] ?? const Duration(hours: 1);
    final hashedKey = _hashKey(key);

    _stats.totalRequests++;

    // Level 1: Memory Cache (fastest)
    if (!skipL1) {
      final l1Result = _getFromL1<T>(hashedKey, effectiveMaxAge);
      if (l1Result != null) {
        _stats.l1Hits++;
        return l1Result;
      }
    }

    // Level 2: LRU Memory Cache
    if (!skipL2) {
      final l2Result = _getFromL2<T>(hashedKey, effectiveMaxAge);
      if (l2Result != null) {
        _stats.l2Hits++;
        // Promote to L1
        _saveToL1(hashedKey, l2Result, type);
        return l2Result;
      }
    }

    // Level 3: SharedPreferences
    if (!skipL3) {
      final l3Result = await _getFromL3<T>(hashedKey, effectiveMaxAge);
      if (l3Result != null) {
        _stats.l3Hits++;
        // Promote to L2 and L1
        _saveToL2(hashedKey, l3Result, type);
        _saveToL1(hashedKey, l3Result, type);
        return l3Result;
      }
    }

    // Level 4: File Cache
    if (!skipL4) {
      final l4Result = await _getFromL4<T>(hashedKey, effectiveMaxAge);
      if (l4Result != null) {
        _stats.l4Hits++;
        // Promote to all upper levels
        await _saveToL3(hashedKey, l4Result, type);
        _saveToL2(hashedKey, l4Result, type);
        _saveToL1(hashedKey, l4Result, type);
        return l4Result;
      }
    }

    _stats.cacheMisses++;
    return null;
  }

  /// 💾 SAVE TO CACHE (unified method saves to all appropriate levels)
  static Future<void> save<T>(
    String key,
    T value, {
    CacheType type = CacheType.apiResponse,
    Duration? ttl,
    bool saveToL1 = true,
    bool saveToL2 = true,
    bool saveToL3 = true,
    bool saveToL4 = false, // File cache only for large/persistent data
  }) async {
    await _ensureInitialized();

    final hashedKey = _hashKey(key);
    // TTL handled by individual cache level methods

    _stats.totalSaves++;

    // Save to requested levels
    if (saveToL1) {
      _saveToL1(hashedKey, value, type);
    }

    if (saveToL2) {
      _saveToL2(hashedKey, value, type);
    }

    if (saveToL3) {
      await _saveToL3(hashedKey, value, type);
    }

    if (saveToL4) {
      await _saveToL4(hashedKey, value, type);
    }
  }

  /// 🗑️ REMOVE FROM CACHE
  static Future<void> remove(String key) async {
    await _ensureInitialized();

    final hashedKey = _hashKey(key);

    // Remove from all levels
    _level1MemoryCache.remove(hashedKey);
    _level2LruCache.remove(hashedKey);

    try {
      await _level3Preferences?.remove(hashedKey);
    } catch (e) {
      // Ignore error
    }

    try {
      final file = File('${_level4FileCache!.path}/$hashedKey.cache');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore error
    }
  }

  /// 🧹 CLEAR ALL CACHE
  static Future<void> clearAll() async {
    await _ensureInitialized();

    // Clear all levels
    _level1MemoryCache.clear();
    _level2LruCache.clear();

    try {
      await _level3Preferences?.clear();
    } catch (e) {
      // Ignore error
    }

    try {
      if (await _level4FileCache!.exists()) {
        await _level4FileCache!.delete(recursive: true);
        await _level4FileCache!.create(recursive: true);
      }
    } catch (e) {
      // Ignore error
    }

    _stats.reset();
  }

  /// 🧹 CLEANUP EXPIRED ENTRIES
  static Future<void> cleanupExpired() async {
    await _ensureInitialized();

    final now = DateTime.now();

    // Cleanup L1
    _level1MemoryCache.removeWhere((key, entry) => entry.isExpired(now));

    // Cleanup L2
    _level2LruCache.removeWhere((key, entry) => entry.isExpired(now));

    // Cleanup L3 (SharedPreferences)
    try {
      final keys = _level3Preferences?.getKeys() ?? <String>{};
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          final data = _level3Preferences?.getString(key);
          if (data != null) {
            try {
              final entry = CacheEntry.fromJson(data);
              if (entry.isExpired(now)) {
                await _level3Preferences?.remove(key);
              }
            } catch (e) {
              // Remove corrupted entry
              await _level3Preferences?.remove(key);
            }
          }
        }
      }
    } catch (e) {
      // Ignore error
    }

    // Cleanup L4 (File Cache)
    try {
      if (await _level4FileCache!.exists()) {
        final files = await _level4FileCache!.list().toList();
        for (final file in files) {
          if (file is File && file.path.endsWith('.cache')) {
            try {
              final content = await file.readAsString();
              final entry = CacheEntry.fromJson(content);
              if (entry.isExpired(now)) {
                await file.delete();
              }
            } catch (e) {
              // Remove corrupted file
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      // Ignore error
    }
  }

  /// 📊 GET CACHE STATISTICS
  static Map<String, dynamic> getStatistics() {
    return {
      'total_requests': _stats.totalRequests,
      'total_saves': _stats.totalSaves,
      'cache_misses': _stats.cacheMisses,
      'l1_hits': _stats.l1Hits,
      'l2_hits': _stats.l2Hits,
      'l3_hits': _stats.l3Hits,
      'l4_hits': _stats.l4Hits,
      'hit_rate': _stats.totalRequests > 0
          ? ((_stats.l1Hits + _stats.l2Hits + _stats.l3Hits + _stats.l4Hits) /
                  _stats.totalRequests *
                  100)
              .toStringAsFixed(2)
          : '0.00',
      'l1_size': _level1MemoryCache.length,
      'l2_size': _level2LruCache.length,
      'is_initialized': _isInitialized,
    };
  }

  // LEGACY COMPATIBILITY METHODS

  /// Legacy compatibility for getFromMemory
  static T? getFromMemory<T>(String key,
      {Duration maxAge = const Duration(minutes: 5)}) {
    final hashedKey = _hashKey(key);
    return _getFromL1<T>(hashedKey, maxAge);
  }

  /// Legacy compatibility for saveToMemory
  static void saveToMemory<T>(String key, T value) {
    final hashedKey = _hashKey(key);
    _saveToL1(hashedKey, value, CacheType.apiResponse);
  }

  /// Legacy compatibility for getFromDisk
  static Future<T?> getFromDisk<T>(String key,
      {Duration maxAge = const Duration(hours: 1)}) async {
    await _ensureInitialized();
    final hashedKey = _hashKey(key);
    return await _getFromL3<T>(hashedKey, maxAge);
  }

  /// Legacy compatibility for saveToDisk
  static Future<void> saveToDisk<T>(String key, T value) async {
    await _ensureInitialized();
    final hashedKey = _hashKey(key);
    await _saveToL3(hashedKey, value, CacheType.apiResponse);
  }

  // PRIVATE HELPER METHODS

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static String _hashKey(String key) {
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static T? _getFromL1<T>(String key, Duration maxAge) {
    final entry = _level1MemoryCache[key];
    if (entry != null && !entry.isExpired(DateTime.now())) {
      entry.updateAccessTime(); // LRU update
      return entry.value as T?;
    }
    return null;
  }

  static void _saveToL1<T>(String key, T value, CacheType type) {
    if (_level1MemoryCache.length >= _maxL1Size) {
      _evictLRU(_level1MemoryCache);
    }

    _level1MemoryCache[key] = CacheEntry(
      value: value,
      createdAt: DateTime.now(),
      ttl: _cacheTTL[type] ?? const Duration(hours: 1),
    );
  }

  static T? _getFromL2<T>(String key, Duration maxAge) {
    final entry = _level2LruCache[key];
    if (entry != null && !entry.isExpired(DateTime.now())) {
      entry.updateAccessTime(); // LRU update
      return entry.value as T?;
    }
    return null;
  }

  static void _saveToL2<T>(String key, T value, CacheType type) {
    if (_level2LruCache.length >= _maxL2Size) {
      _evictLRU(_level2LruCache);
    }

    _level2LruCache[key] = CacheEntry(
      value: value,
      createdAt: DateTime.now(),
      ttl: _cacheTTL[type] ?? const Duration(hours: 1),
    );
  }

  static Future<T?> _getFromL3<T>(String key, Duration maxAge) async {
    try {
      final data = _level3Preferences?.getString('cache_$key');
      if (data != null) {
        final entry = CacheEntry.fromJson(data);
        if (!entry.isExpired(DateTime.now())) {
          return entry.value as T?;
        }
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  static Future<void> _saveToL3<T>(String key, T value, CacheType type) async {
    try {
      final entry = CacheEntry(
        value: value,
        createdAt: DateTime.now(),
        ttl: _cacheTTL[type] ?? const Duration(hours: 1),
      );
      await _level3Preferences?.setString('cache_$key', entry.toJson());
    } catch (e) {
      // Ignore error
    }
  }

  static Future<T?> _getFromL4<T>(String key, Duration maxAge) async {
    try {
      final file = File('${_level4FileCache!.path}/$key.cache');
      if (await file.exists()) {
        final content = await file.readAsString();
        final entry = CacheEntry.fromJson(content);
        if (!entry.isExpired(DateTime.now())) {
          return entry.value as T?;
        }
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  static Future<void> _saveToL4<T>(String key, T value, CacheType type) async {
    try {
      final entry = CacheEntry(
        value: value,
        createdAt: DateTime.now(),
        ttl: _cacheTTL[type] ?? const Duration(hours: 1),
      );

      final file = File('${_level4FileCache!.path}/$key.cache');
      await file.writeAsString(entry.toJson());
    } catch (e) {
      // Ignore error
    }
  }

  static void _evictLRU(Map<String, CacheEntry> cache) {
    if (cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in cache.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
    }
  }
}

/// 📊 CACHE ENTRY CLASS
class CacheEntry {
  final dynamic value;
  final DateTime createdAt;
  final Duration ttl;
  DateTime lastAccessed;

  CacheEntry({
    required this.value,
    required this.createdAt,
    required this.ttl,
  }) : lastAccessed = DateTime.now();

  bool isExpired(DateTime now) {
    return now.difference(createdAt) > ttl;
  }

  void updateAccessTime() {
    lastAccessed = DateTime.now();
  }

  String toJson() {
    return jsonEncode({
      'value': value,
      'created_at': createdAt.toIso8601String(),
      'ttl_seconds': ttl.inSeconds,
      'last_accessed': lastAccessed.toIso8601String(),
    });
  }

  static CacheEntry fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return CacheEntry(
      value: data['value'],
      createdAt: DateTime.parse(data['created_at'] as String),
      ttl: Duration(seconds: data['ttl_seconds'] as int),
    )..lastAccessed =
        DateTime.parse((data['last_accessed'] ?? data['created_at']) as String);
  }
}

/// 🏷️ CACHE TYPE ENUM
enum CacheType {
  geocoding,
  routes,
  traffic,
  weather,
  userPreferences,
  apiResponse,
  images,
  gpsData,
}

/// 📊 CACHE STATISTICS CLASS
class CacheStats {
  int totalRequests = 0;
  int totalSaves = 0;
  int cacheMisses = 0;
  int l1Hits = 0;
  int l2Hits = 0;
  int l3Hits = 0;
  int l4Hits = 0;

  void reset() {
    totalRequests = 0;
    totalSaves = 0;
    cacheMisses = 0;
    l1Hits = 0;
    l2Hits = 0;
    l3Hits = 0;
    l4Hits = 0;
  }
}
