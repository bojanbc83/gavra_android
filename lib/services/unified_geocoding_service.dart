import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cache_service.dart';

/// 🚀 UNIFIED GEOCODING SERVICE
/// Konsoliduje: geocoding_service.dart + advanced_geocoding_service.dart + geocoding_stats_service.dart
/// Enterprise-level geocoding sa cache optimizacijom i multi-provider fallback
class UnifiedGeocodingService {
  static const String _cachePrefix = 'unified_geocoding_';

  // 🌍 MULTIPLE FREE GEOCODING PROVIDERS - failover sistem
  static const Map<String, String> _providers = {
    'nominatim': 'https://nominatim.openstreetmap.org/search',
    'photon': 'https://photon.komoot.io/api/',
  };

  // 🎯 SERBIAN CITY ALIASES - samo Bela Crkva i Vršac opštine
  static const Map<String, List<String>> _cityAliases = {
    'Bela Crkva': ['BC', 'Bela', 'Бела Црква', 'bela crkva', 'BELA CRKVA'],
    'Vršac': ['Vrsac', 'VS', 'Вршац', 'vrsac', 'VRSAC'],
  };

  // 🤖 AI FUZZY MATCHING - auto-ispravka grešaka
  static const Map<String, String> _commonTypos = {
    'ulica': 'ulica',
    'ulitse': 'ulice',
    'bul': 'bulevar',
    'blv': 'bulevar',
    'tr': 'trg',
    'bb': 'bez broja',
  };

  // 📊 STATS KEYS
  static const String _apiCallsKey = 'geocoding_api_calls';
  static const String _cacheHitsKey = 'geocoding_cache_hits';
  static const String _popularLocationsKey = 'geocoding_popular_locations';

  /// 🚀 UNIFIED GEOCODING FUNCTION
  /// Kombinuje sve funkcionalnosti iz 3 originalna servisa
  static Future<GeocodeResult?> getCoordinates({
    required String grad,
    required String adresa,
    bool useCache = true,
    bool enableFuzzyMatching = true,
    bool enableAutoCorrection = true,
    int maxRetries = 3,
  }) async {
    // 🚫 PROVERI DA LI JE GRAD DOZVOLJEN (samo Bela Crkva i Vršac)
    if (_isCityBlocked(grad)) {
      return null;
    }

    // Auto-correct grad ako je potrebno
    final correctedGrad = enableAutoCorrection ? _correctCityName(grad) : grad;
    final correctedAdresa =
        enableAutoCorrection ? _correctAddress(adresa) : adresa;

    final cacheKey = '${_cachePrefix}${correctedGrad}_$correctedAdresa';

    // 1. CACHE CHECK (ako je omogućen)
    if (useCache) {
      // Memory cache check
      final memoryCached = CacheService.getFromMemory<String>(
        cacheKey,
        maxAge: const Duration(hours: 6),
      );
      if (memoryCached != null) {
        await _incrementCacheHits();
        await _addPopularLocation('${correctedGrad}_$correctedAdresa');
        return GeocodeResult.fromCachedString(memoryCached);
      }

      // Disk cache check
      final diskCached = await CacheService.getFromDisk<String>(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (diskCached != null) {
        CacheService.saveToMemory(cacheKey, diskCached);
        await _incrementCacheHits();
        await _addPopularLocation('${correctedGrad}_$correctedAdresa');
        return GeocodeResult.fromCachedString(diskCached);
      }
    }

    // 2. API CALL sa multi-provider fallback
    await _incrementApiCalls();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      for (final provider in _providers.entries) {
        try {
          final result = await _geocodeWithProvider(
            provider.key,
            provider.value,
            correctedGrad,
            correctedAdresa,
            enableFuzzyMatching,
          );

          if (result != null) {
            // Cache successful result
            if (useCache) {
              final cacheValue = result.toCacheString();
              CacheService.saveToMemory(cacheKey, cacheValue);
              await CacheService.saveToDisk(cacheKey, cacheValue);
            }

            await _addPopularLocation('${correctedGrad}_$correctedAdresa');
            return result;
          }
        } catch (e) {
          // Try next provider
          continue;
        }
      }

      // Small delay before retry
      if (attempt < maxRetries - 1) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    return null;
  }

  /// 🔍 LEGACY COMPATIBILITY - stara getKoordinateZaAdresu funkcija
  static Future<String?> getKoordinateZaAdresu(
      String grad, String adresa) async {
    final result = await getCoordinates(grad: grad, adresa: adresa);
    return result?.toCoordinateString();
  }

  /// 🚀 GEOCODE sa određenim provajderom
  static Future<GeocodeResult?> _geocodeWithProvider(
    String providerName,
    String baseUrl,
    String grad,
    String adresa,
    bool enableFuzzyMatching,
  ) async {
    switch (providerName) {
      case 'nominatim':
        return await _geocodeWithNominatim(
            baseUrl, grad, adresa, enableFuzzyMatching);
      case 'photon':
        return await _geocodeWithPhoton(
            baseUrl, grad, adresa, enableFuzzyMatching);
      default:
        return null;
    }
  }

  /// 📍 NOMINATIM GEOCODING
  static Future<GeocodeResult?> _geocodeWithNominatim(
    String baseUrl,
    String grad,
    String adresa,
    bool enableFuzzyMatching,
  ) async {
    final query = '$adresa, $grad, Serbia';
    final url = Uri.parse(
        '$baseUrl?q=${Uri.encodeComponent(query)}&format=json&limit=5');

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;

      if (data.isNotEmpty) {
        final best = data.first as Map<String, dynamic>;
        final lat = double.parse(best['lat'].toString());
        final lon = double.parse(best['lon'].toString());
        final displayName = best['display_name'] as String? ?? '';

        return GeocodeResult(
          latitude: lat,
          longitude: lon,
          displayName: displayName,
          provider: 'nominatim',
          confidence: _calculateConfidence(displayName, grad, adresa),
        );
      }
    }

    return null;
  }

  /// 🌐 PHOTON GEOCODING
  static Future<GeocodeResult?> _geocodeWithPhoton(
    String baseUrl,
    String grad,
    String adresa,
    bool enableFuzzyMatching,
  ) async {
    final query = '$adresa $grad Serbia';
    final url = Uri.parse('$baseUrl?q=${Uri.encodeComponent(query)}&limit=5');

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      if (features.isNotEmpty) {
        final best = features.first as Map<String, dynamic>;
        final coordinates = best['geometry']['coordinates'] as List<dynamic>;
        final properties = best['properties'] as Map<String, dynamic>;

        return GeocodeResult(
          latitude: (coordinates[1] as num).toDouble(),
          longitude: (coordinates[0] as num).toDouble(),
          displayName: properties['name']?.toString() ?? '',
          provider: 'photon',
          confidence: _calculateConfidence(
              properties['name']?.toString() ?? '', grad, adresa),
        );
      }
    }

    return null;
  }

  /// 🤖 AUTO-CORRECT CITY NAME
  static String _correctCityName(String grad) {
    for (final alias in _cityAliases.entries) {
      if (alias.value.any((a) => a.toLowerCase() == grad.toLowerCase())) {
        return alias.key;
      }
    }
    return grad;
  }

  /// 🔧 AUTO-CORRECT ADDRESS
  static String _correctAddress(String adresa) {
    String corrected = adresa.toLowerCase();

    for (final typo in _commonTypos.entries) {
      corrected = corrected.replaceAll(typo.key, typo.value);
    }

    return corrected;
  }

  /// 🎯 CALCULATE CONFIDENCE SCORE
  static double _calculateConfidence(
      String displayName, String grad, String adresa) {
    double confidence = 0.5; // Base confidence

    if (displayName.toLowerCase().contains(grad.toLowerCase())) {
      confidence += 0.3;
    }

    if (displayName.toLowerCase().contains(adresa.toLowerCase())) {
      confidence += 0.2;
    }

    return math.min(confidence, 1.0);
  }

  /// 🚫 CHECK CITY BLOCKING
  static bool _isCityBlocked(String grad) {
    final allowedCities = _cityAliases.keys.toList();
    final allAliases =
        _cityAliases.values.expand((aliases) => aliases).toList();

    return !allowedCities.contains(grad) &&
        !allAliases.any((alias) => alias.toLowerCase() == grad.toLowerCase());
  }

  // 📊 STATISTICS METHODS (konsolidovano iz geocoding_stats_service.dart)

  /// Povećava brojač API poziva
  static Future<void> _incrementApiCalls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCalls = prefs.getInt(_apiCallsKey) ?? 0;
      await prefs.setInt(_apiCallsKey, currentCalls + 1);
    } catch (e) {
      // Ignore error
    }
  }

  /// Povećava brojač cache hit-ova
  static Future<void> _incrementCacheHits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentHits = prefs.getInt(_cacheHitsKey) ?? 0;
      await prefs.setInt(_cacheHitsKey, currentHits + 1);
    } catch (e) {
      // Ignore error
    }
  }

  /// Dodaje lokaciju u popularne lokacije
  static Future<void> _addPopularLocation(String location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList(_popularLocationsKey) ?? [];

      final existingIndex =
          locations.indexWhere((loc) => loc.startsWith('$location:'));

      if (existingIndex != -1) {
        final parts = locations[existingIndex].split(':');
        final count = int.tryParse(parts[1]) ?? 1;
        locations[existingIndex] = '$location:${count + 1}';
      } else {
        locations.add('$location:1');
      }

      await prefs.setStringList(_popularLocationsKey, locations);
    } catch (e) {
      // Ignore error
    }
  }

  /// Vraća statistike geocoding servisa
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiCalls = prefs.getInt(_apiCallsKey) ?? 0;
      final cacheHits = prefs.getInt(_cacheHitsKey) ?? 0;
      final locations = prefs.getStringList(_popularLocationsKey) ?? [];

      final totalRequests = apiCalls + cacheHits;
      final cacheHitRate =
          totalRequests > 0 ? (cacheHits / totalRequests * 100) : 0.0;

      return {
        'api_calls': apiCalls,
        'cache_hits': cacheHits,
        'total_requests': totalRequests,
        'cache_hit_rate': cacheHitRate.toStringAsFixed(2),
        'popular_locations': locations.take(10).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Reset statistika
  static Future<void> resetStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiCallsKey);
      await prefs.remove(_cacheHitsKey);
      await prefs.remove(_popularLocationsKey);
    } catch (e) {
      // Ignore error
    }
  }
}

/// 📍 GEOCODE RESULT CLASS
class GeocodeResult {
  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.provider,
    required this.confidence,
  });

  final double latitude;
  final double longitude;
  final String displayName;
  final String provider;
  final double confidence;

  /// Convert to coordinate string (legacy compatibility)
  String toCoordinateString() {
    return '$latitude,$longitude';
  }

  /// Convert to cache string
  String toCacheString() {
    return jsonEncode({
      'lat': latitude,
      'lon': longitude,
      'name': displayName,
      'provider': provider,
      'confidence': confidence,
    });
  }

  /// Create from cached string
  static GeocodeResult? fromCachedString(String cached) {
    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      return GeocodeResult(
        latitude: (data['lat'] as num).toDouble(),
        longitude: (data['lon'] as num).toDouble(),
        displayName: data['name']?.toString() ?? '',
        provider: data['provider']?.toString() ?? 'cached',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'GeocodeResult(lat: $latitude, lon: $longitude, provider: $provider, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// 🔑 CACHE KEYS HELPER
abstract class CacheKeys {
  static String geocoding(String key) => 'geocoding_$key';
}
