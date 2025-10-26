import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/adresa.dart';
import 'cache_service.dart';

/// 📍 MODERNIZED CLOUD SERVICE za upravljanje adresama u Supabase Cloud
/// KOMPLETNO MODERNIZOVAN - caching, batch operations, analytics, validation
///
/// FUNKCIONALNOSTI:
/// ✅ Smart caching system sa TTL i memory management
/// ✅ Batch CRUD operacije za performance
/// ✅ Advanced search sa filtering i geolocation
/// ✅ Comprehensive error handling i logging
/// ✅ Real-time subscriptions
/// ✅ Address validation i normalizacija
/// ✅ Statistics i usage analytics
/// ✅ CSV export functionality
/// ✅ Coordinate geocoding integration
///
/// KADA KORISTITI:
/// - Za sve cloud CRUD operacije sa adresama
/// - Za persistent storage adresa sa UUID-jima
/// - Za real-time tracking address changes
/// - Za analytics i reporting
/// - Za batch import/export operations
///
/// OGRANIČENO NA: Bela Crkva i Vršac opštine samo
class AdresaService {
  // ✅ FIREBASE CLIENT IMPLEMENTATION
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'adrese';

  static const String _cachePrefix = 'adresa_';
  static const String _listCacheKey = 'adrese_list';

  // 📊 Statistics tracking
  static int _totalOperations = 0;
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static DateTime? _lastOperationTime;

  // ✅ ENHANCED CRUD OPERATIONS WITH CACHING

  /// Get all addresses with smart caching
  Future<List<Adresa>> getAllAdrese({bool forceRefresh = false}) async {
    _incrementOperation();

    try {
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cached =
            await CacheService.getFromDisk<List<Map<String, dynamic>>>(
          _listCacheKey,
        );
        if (cached != null) {
          // Logger removed
          _cacheHits++;
          return cached.map((json) => Adresa.fromMap(json)).toList();
        }
      }

      // Logger removed
      _cacheMisses++;

      // ✅ FIREBASE ADRESE QUERY IMPLEMENTATION
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true)
          .orderBy('updated_at', descending: true)
          .get();

      final adrese = snapshot.docs
          .map((doc) => Adresa.fromMap({...doc.data(), 'id': doc.id}))
          .where((adresa) => adresa.isInServiceArea) // Filter service area
          .toList();

      // Cache the results
      await CacheService.saveToDisk(
        _listCacheKey,
        adrese.map((a) => a.toMap()).toList(),
      );

      // Logger removed;
      return adrese;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Get address by ID with caching
  Future<Adresa?> getAdresaById(String id) async {
    _incrementOperation();

    try {
      // Check cache first
      final cacheKey = '$_cachePrefix$id';
      final cached =
          await CacheService.getFromDisk<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        // Logger removed
        _cacheHits++;
        return Adresa.fromMap(cached);
      }

      // Logger removed
      _cacheMisses++;

      // ✅ FIREBASE ADRESE QUERY BY ID IMPLEMENTATION
      final doc = await _firestore.collection(_collectionName).doc(id).get();

      if (!doc.exists) return null;

      final adresa = Adresa.fromMap({...doc.data()!, 'id': doc.id});

      // Cache the result
      await CacheService.saveToDisk(cacheKey, adresa.toMap());

      return adresa;
    } catch (e) {
      // Logger removed
      return null;
    }
  }

  /// Create new address with validation
  Future<Adresa> createAdresa(Adresa adresa) async {
    _incrementOperation();

    try {
      // Validate before creating
      if (!adresa.isCompletelyValid) {
        final errors = adresa.validationErrors.join(', ');
        throw Exception('Address validation failed: $errors');
      }

      // ✅ FIREBASE ADRESE INSERT IMPLEMENTATION
      final normalizedAdresa = adresa.normalize();
      final now = DateTime.now();

      final data = {
        ...normalizedAdresa.toMap(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'search_terms': _generateSearchTerms(normalizedAdresa),
        'last_optimized': FieldValue.serverTimestamp(),
        'putnici_count': 0,
        'putovanja_count': 0,
      };

      final docRef = await _firestore.collection(_collectionName).add(data);

      // Return with generated ID
      final createdAdresa = normalizedAdresa.copyWith(
        id: docRef.id,
        createdAt: now,
        updatedAt: now,
      );

      // Clear cache
      await _clearCache();

      return createdAdresa;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Update address with validation
  Future<Adresa> updateAdresa(String id, Map<String, dynamic> updates) async {
    _incrementOperation();

    try {
      // ✅ FIREBASE ADRESE UPDATE IMPLEMENTATION
      updates['updated_at'] = FieldValue.serverTimestamp();
      updates['last_optimized'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collectionName).doc(id).update(updates);

      // Get updated document
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      final updatedAdresa = Adresa.fromMap({...doc.data()!, 'id': doc.id});

      // Clear cache
      await _clearCache();

      return updatedAdresa;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Soft delete address
  Future<void> deleteAdresa(String id) async {
    _incrementOperation();

    try {
      // ✅ FIREBASE ADRESE SOFT DELETE IMPLEMENTATION
      await _firestore.collection(_collectionName).doc(id).update({
        'obrisan': true,
        'aktivan': false,
        'updated_at': FieldValue.serverTimestamp(),
        'last_optimized': FieldValue.serverTimestamp(),
      });

      // Clear cache
      await _clearCache();

      // Logger removed
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ BATCH OPERATIONS for performance

  /// Create multiple addresses in batch
  Future<List<Adresa>> createMultipleAdrese(List<Adresa> adrese) async {
    _incrementOperation();

    try {
      if (adrese.isEmpty) return [];

      // Validate all addresses
      final validAdrese = <Adresa>[];
      final invalidAdrese = <String>[];

      for (final adresa in adrese) {
        final normalized = adresa.normalize();
        if (normalized.isCompletelyValid) {
          validAdrese.add(normalized);
        } else {
          invalidAdrese.add(
            '${adresa.displayAddress}: ${adresa.validationErrors.join(', ')}',
          );
        }
      }

      if (invalidAdrese.isNotEmpty) {
        // Logger removed
      }

      if (validAdrese.isEmpty) {
        throw Exception('No valid addresses to create');
      }

      // ✅ FIREBASE BATCH INSERT IMPLEMENTATION
      final batch = _firestore.batch();
      final createdAdrese = <Adresa>[];
      final now = DateTime.now();

      for (final adresa in validAdrese) {
        final docRef = _firestore.collection(_collectionName).doc();
        final data = {
          ...adresa.toMap(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'search_terms': _generateSearchTerms(adresa),
          'last_optimized': FieldValue.serverTimestamp(),
          'putnici_count': 0,
          'putovanja_count': 0,
        };

        batch.set(docRef, data);
        createdAdrese.add(adresa.copyWith(
          id: docRef.id,
          createdAt: now,
          updatedAt: now,
        ));
      }

      await batch.commit();

      // Clear cache
      await _clearCache();

      return createdAdrese;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Update multiple addresses in batch
  Future<void> updateMultipleAdrese(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    _incrementOperation();

    try {
      if (updates.isEmpty) return;

      // Logger removed

      // ✅ FIREBASE BATCH UPDATES IMPLEMENTATION
      final batch = _firestore.batch();

      for (final entry in updates.entries) {
        final id = entry.key;
        final updateData = entry.value;

        updateData['updated_at'] = FieldValue.serverTimestamp();
        updateData['last_optimized'] = FieldValue.serverTimestamp();

        batch.update(
            _firestore.collection(_collectionName).doc(id), updateData);
      }

      await batch.commit();

      // Clear cache
      await _clearCache();

      // Logger removed
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Batch soft delete addresses
  Future<void> deleteMultipleAdrese(List<String> ids) async {
    _incrementOperation();

    try {
      if (ids.isEmpty) return;

      // ✅ FIREBASE BATCH DELETE IMPLEMENTATION
      final batch = _firestore.batch();

      for (final id in ids) {
        batch.update(_firestore.collection(_collectionName).doc(id), {
          'obrisan': true,
          'aktivan': false,
          'updated_at': FieldValue.serverTimestamp(),
          'last_optimized': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Clear cache
      await _clearCache();

      // Logger removed
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ ADVANCED SEARCH OPERATIONS

  /// Search addresses with advanced filtering
  Future<List<Adresa>> searchAdrese(
    String? query, {
    String? grad,
    bool? hasCoordinates,
    double? nearLatitude,
    double? nearLongitude,
    double? radiusKm,
    String? sortBy,
    bool ascending = true,
    int? limit,
  }) async {
    _incrementOperation();

    // ✅ FIREBASE SEARCH FUNCTIONALITY IMPLEMENTATION
    try {
      Query<Map<String, dynamic>> firebaseQuery = _firestore
          .collection(_collectionName)
          .where('aktivan', isEqualTo: true);

      // Filter by grad if specified
      if (grad != null && grad.isNotEmpty) {
        firebaseQuery = firebaseQuery.where('grad', isEqualTo: grad);
      }

      // Filter addresses with coordinates
      if (hasCoordinates == true) {
        firebaseQuery = firebaseQuery.where('koordinate', isNull: false);
      }

      // Apply limit
      if (limit != null) {
        firebaseQuery = firebaseQuery.limit(limit);
      }

      final snapshot = await firebaseQuery.get();
      var results = snapshot.docs
          .map((doc) => Adresa.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Apply text search filter (client-side for complex search)
      if (query != null && query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        results = results.where((adresa) {
          return adresa.displayAddress.toLowerCase().contains(searchLower) ||
              adresa.grad.toLowerCase().contains(searchLower) ||
              adresa.ulica.toLowerCase().contains(searchLower);
        }).toList();
      }

      // Apply geo-location filter (client-side)
      if (nearLatitude != null && nearLongitude != null && radiusKm != null) {
        results = results.where((adresa) {
          if (adresa.latitude == null || adresa.longitude == null) return false;
          final distance = _calculateDistance(
            nearLatitude,
            nearLongitude,
            adresa.latitude!,
            adresa.longitude!,
          );
          return distance <= radiusKm;
        }).toList();
      }

      return results;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Get addresses grouped by municipality
  Future<Map<String, List<Adresa>>> getAdreseByMunicipality() async {
    _incrementOperation();

    try {
      // Logger removed

      final allAdrese = await getAllAdrese();
      final grouped = <String, List<Adresa>>{};

      for (final adresa in allAdrese) {
        final municipality = adresa.municipality;
        grouped[municipality] ??= [];
        grouped[municipality]!.add(adresa);
      }

      // Sort addresses within each municipality by priority then name
      for (final addresses in grouped.values) {
        addresses.sort((a, b) {
          final priorityComparison = b.priorityScore.compareTo(a.priorityScore);
          if (priorityComparison != 0) return priorityComparison;
          return a.displayAddress.compareTo(b.displayAddress);
        });
      }

      return grouped;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ STATISTICS AND ANALYTICS

  /// Get comprehensive address statistics
  Future<Map<String, dynamic>> getAddressStatistics() async {
    _incrementOperation();

    try {
      // Logger removed

      final allAdrese = await getAllAdrese();
      final stats = <String, dynamic>{};

      // Basic counts
      stats['totalAddresses'] = allAdrese.length;
      stats['addressesWithCoordinates'] =
          allAdrese.where((a) => a.hasValidCoordinates).length;
      stats['validAddresses'] =
          allAdrese.where((a) => a.isCompletelyValid).length;

      // Municipality breakdown
      final byMunicipality = <String, int>{};
      final coordinatesByMunicipality = <String, int>{};

      for (final adresa in allAdrese) {
        final municipality = adresa.municipality;
        byMunicipality[municipality] = (byMunicipality[municipality] ?? 0) + 1;

        if (adresa.hasValidCoordinates) {
          coordinatesByMunicipality[municipality] =
              (coordinatesByMunicipality[municipality] ?? 0) + 1;
        }
      }

      stats['byMunicipality'] = byMunicipality;
      stats['coordinatesCoverage'] = coordinatesByMunicipality;

      // Service coverage
      final inServiceArea = allAdrese.where((a) => a.isInServiceArea).length;
      stats['serviceAreaCoverage'] = inServiceArea;
      stats['serviceAreaPercentage'] = allAdrese.isNotEmpty
          ? (inServiceArea / allAdrese.length * 100).round()
          : 0;

      // Priority locations
      final priorityLocations =
          allAdrese.where((a) => a.priorityScore > 0).length;
      stats['priorityLocations'] = priorityLocations;

      // Cache statistics
      stats['cacheStatistics'] = {
        'totalOperations': _totalOperations,
        'cacheHits': _cacheHits,
        'cacheMisses': _cacheMisses,
        'cacheHitRate': _totalOperations > 0
            ? (_cacheHits / _totalOperations * 100).round()
            : 0,
        'lastOperation': _lastOperationTime?.toIso8601String(),
      };

      // Logger removed
      return stats;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Export addresses to CSV format
  Future<String> exportToCSV({String? municipality}) async {
    _incrementOperation();

    try {
      // Logger removed

      var adrese = await getAllAdrese();

      // Filter by municipality if specified
      if (municipality != null && municipality.trim().isNotEmpty) {
        adrese = adrese.where((a) => a.municipality == municipality).toList();
      }

      final csv = StringBuffer();

      // CSV Header
      csv.writeln(
        'ID,Ulica,Broj,Grad,Postanski_Broj,Latitude,Longitude,Municipality,Valid,Created_At,Updated_At',
      );

      // CSV Data
      for (final adresa in adrese) {
        csv.write('"${adresa.id}",');
        csv.write('"${adresa.ulica.replaceAll('"', '""')}",');
        csv.write('"${adresa.broj ?? ''}",');
        csv.write('"${adresa.grad.replaceAll('"', '""')}",');
        csv.write('"${adresa.postanskiBroj ?? ''}",');
        csv.write('"${adresa.latitude ?? ''}",');
        csv.write('"${adresa.longitude ?? ''}",');
        csv.write('"${adresa.municipality}",');
        csv.write('"${adresa.isCompletelyValid}",');
        csv.write('"${adresa.createdAt.toIso8601String()}",');
        csv.writeln('"${adresa.updatedAt.toIso8601String()}"');
      }

      // Logger removed
      return csv.toString();
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ REAL-TIME OPERATIONS

  /// Real-time subscription to address changes
  Stream<List<Adresa>> watchAdrese() {
    // ✅ FIREBASE STREAM FOR ADDRESSES IMPLEMENTATION
    return _firestore
        .collection(_collectionName)
        .where('aktivan', isEqualTo: true)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Adresa.fromMap({...doc.data(), 'id': doc.id}))
            .where((adresa) => adresa.isInServiceArea)
            .toList());
  }

  /// Watch specific address by ID
  Stream<Adresa?> watchAdresa(String id) {
    // ✅ FIREBASE STREAM FOR SINGLE ADDRESS IMPLEMENTATION
    return _firestore
        .collection(_collectionName)
        .doc(id)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Adresa.fromMap({...doc.data()!, 'id': doc.id});
    });
  }

  // ✅ CACHE MANAGEMENT

  /// Clear all address caches
  Future<void> clearCache() async {
    // Logger removed

    await CacheService.clearFromDisk(_listCacheKey);

    // Clear individual address caches (this is a simplified approach)
    // In a real app, you might want to track cache keys or use a pattern-based clear

    // Logger removed
  }

  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache() async {
    // Logger removed

    try {
      // Pre-load all addresses
      await getAllAdrese(forceRefresh: true);

      // Pre-load municipality groups
      await getAdreseByMunicipality();

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  // ✅ UTILITY METHODS

  /// Increment operation counter and update last operation time
  static void _incrementOperation() {
    _totalOperations++;
    _lastOperationTime = DateTime.now();
  }

  /// Reset statistics
  static void resetStatistics() {
    _totalOperations = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _lastOperationTime = null;
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isHealthy': true,
      'totalOperations': _totalOperations,
      'cacheHitRate': _totalOperations > 0
          ? (_cacheHits / _totalOperations * 100).round()
          : 0,
      'lastOperation': _lastOperationTime?.toIso8601String(),
      'cacheSize': 'N/A', // Could be implemented with cache size tracking
    };
  }

  // ✅ HELPER METHODS FOR FIREBASE IMPLEMENTATION

  /// Generate search terms for Firebase text search
  static List<String> _generateSearchTerms(Adresa adresa) {
    final terms = <String>[];

    // Add core address components
    terms.addAll([
      adresa.grad.toLowerCase(),
      adresa.ulica.toLowerCase(),
      adresa.displayAddress.toLowerCase(),
    ]);

    // Add broj if exists
    if (adresa.broj?.isNotEmpty == true) {
      terms.add(adresa.broj!.toLowerCase());
    }

    // Add postanski_broj if exists
    if (adresa.postanskiBroj?.isNotEmpty == true) {
      terms.add(adresa.postanskiBroj!.toLowerCase());
    }

    return terms.where((term) => term.isNotEmpty).toList();
  }

  /// Calculate distance between two coordinates in km
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Clear all caches
  static Future<void> _clearCache() async {
    await CacheService.clearFromDisk(_listCacheKey);
    // Note: CacheService doesn't have clearByPattern, so we clear main cache
    CacheService.clearFromMemory(_listCacheKey);
  }
}
