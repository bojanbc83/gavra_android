# 📦 PLAN MIGRACIJE PODATAKA I TESTIRANJE

**Datum**: 24.10.2025  
**Status**: Kompletna strategija za data migration i validaciju  

---

## 📊 DATA MIGRATION STRATEGY

### **TRENUTNO STANJE PODATAKA**

#### **Supabase Database** (PostgreSQL)
```sql
-- Production tabele sa podacima
SELECT 
  schemaname,
  tablename,
  n_tup_ins as inserts,
  n_tup_upd as updates,
  n_tup_del as deletes
FROM pg_stat_user_tables 
WHERE schemaname = 'public';

-- Estimated data volumes:
-- vozaci:              ~10-15 records  
-- mesecni_putnici:     ~100-200 records
-- dnevni_putnici:      ~500-1000 records  
-- putovanja_istorija:  ~2000-5000 records
-- adrese:              ~50-100 records
-- vozila:              ~5-10 records
-- gps_lokacije:        ~10000+ records (time-series)
-- rute:                ~10-20 records
```

#### **Target Firebase** (Firestore)
```javascript
// Target collections structure
{
  drivers: {},           // vozaci
  monthly_passengers: {}, // mesecni_putnici
  daily_passengers: {},   // dnevni_putnici  
  travel_history: {},     // putovanja_istorija
  addresses: {},          // adrese
  vehicles: {},           // vozila
  gps_locations: {},      // gps_lokacije
  routes: {}              // rute
}
```

---

## 🚀 MIGRATION PHASES

### **PHASE 1: DATA EXPORT** (1 dan)

#### **Step 1.1: Supabase Data Export**
```bash
# Export using Supabase CLI
supabase db dump --data-only --file supabase_data_export.sql

# Or use REST API export
curl -H "apikey: $SUPABASE_SERVICE_KEY" \
  "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/vozaci?select=*" \
  > vozaci_export.json

curl -H "apikey: $SUPABASE_SERVICE_KEY" \
  "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/mesecni_putnici?select=*" \
  > mesecni_putnici_export.json

# Export all tables
tables=("vozaci" "mesecni_putnici" "dnevni_putnici" "putovanja_istorija" "adrese" "vozila" "gps_lokacije" "rute")
for table in "${tables[@]}"; do
  curl -H "apikey: $SUPABASE_SERVICE_KEY" \
    "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/$table?select=*" \
    > "${table}_export.json"
done
```

#### **Step 1.2: Data Validation & Cleanup**
```dart
// lib/scripts/data_validator.dart
class DataValidator {
  static Future<ValidationReport> validateSupabaseExport() async {
    final report = ValidationReport();
    
    // 1. Check data integrity
    final vozaci = await _loadJsonFile('vozaci_export.json');
    report.addCheck('vozaci_count', vozaci.length);
    
    // 2. Validate foreign keys
    final putnici = await _loadJsonFile('mesecni_putnici_export.json');
    for (final putnik in putnici) {
      if (putnik['adresa_id'] != null) {
        // Check if address exists
        final adresaExists = await _checkAdresaExists(putnik['adresa_id']);
        if (!adresaExists) {
          report.addError('missing_address', putnik['id']);
        }
      }
    }
    
    // 3. Validate data formats
    _validateDateFormats(putnici);
    _validateEmailFormats(vozaci);
    _validateCoordinates(addresses);
    
    return report;
  }
}
```

### **PHASE 2: DATA TRANSFORMATION** (1-2 dana)

#### **Step 2.1: Schema Mapping**
```dart
// lib/scripts/data_transformer.dart
class DataTransformer {
  
  // Transform vozaci -> drivers
  static Map<String, dynamic> transformVozac(Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'ime': supabaseData['ime'],
      'email': supabaseData['email'],
      'kusur': supabaseData['kusur'] ?? 0.0, // Default value
      'aktivan': supabaseData['aktivan'] ?? true,
      'boja': VozacBoja.getBojaForVozac(supabaseData['ime']),
      'created_at': _parseTimestamp(supabaseData['created_at']),
      'updated_at': _parseTimestamp(supabaseData['updated_at']),
      // Add Firebase-specific fields
      'firebase_uid': null, // Will be set during auth migration
    };
  }
  
  // Transform mesecni_putnici -> monthly_passengers  
  static Map<String, dynamic> transformMesecniPutnik(Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'putnik_ime': supabaseData['putnik_ime'],
      'tip': supabaseData['tip'] ?? 'radnik',
      
      // JSON -> Map conversion (KEY CHANGE!)
      'polasci_po_danu': _parsePolasciPoDanu(supabaseData['polasci_po_danu']),
      
      'datum_pocetka_meseca': _parseTimestamp(supabaseData['datum_pocetka_meseca']),
      'datum_kraja_meseca': _parseTimestamp(supabaseData['datum_kraja_meseca']),
      'aktivan': supabaseData['aktivan'] ?? true,
      'obrisan': supabaseData['obrisan'] ?? false,
      
      // Timestamp conversion
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
  
  // Transform adrese -> addresses (COORDINATE CONVERSION!)
  static Map<String, dynamic> transformAdresa(Map<String, dynamic> supabaseData) {
    return {
      'id': supabaseData['id'],
      'ulica': supabaseData['ulica'],
      'grad': supabaseData['grad'],
      'broj': supabaseData['broj'],
      'postanski_broj': supabaseData['postanski_broj'],
      
      // PostgreSQL POINT -> Firebase GeoPoint
      'koordinate': _parsePostgreSQLPoint(supabaseData['koordinate']),
      
      'created_at': _parseTimestamp(supabaseData['created_at']),
      'updated_at': _parseTimestamp(supabaseData['updated_at']),
    };
  }
  
  // Helper: Parse PostgreSQL POINT(lng lat) -> GeoPoint(lat, lng)
  static GeoPoint? _parsePostgreSQLPoint(String? pointString) {
    if (pointString == null) return null;
    
    // Parse "POINT(19.123456 44.789012)"
    final regex = RegExp(r'POINT\(([+-]?\d+\.?\d*) ([+-]?\d+\.?\d*)\)');
    final match = regex.firstMatch(pointString);
    
    if (match != null) {
      final lng = double.parse(match.group(1)!);
      final lat = double.parse(match.group(2)!);
      return GeoPoint(lat, lng); // Note: lat/lng order swap!
    }
    
    return null;
  }
  
  // Helper: Parse JSON string -> Map
  static Map<String, List<String>> _parsePolasciPoDanu(String? jsonString) {
    if (jsonString == null) return {};
    
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = <String, List<String>>{};
      
      decoded.forEach((day, times) {
        if (times is List) {
          result[day] = times.cast<String>();
        }
      });
      
      return result;
    } catch (e) {
      return {};
    }
  }
}
```

#### **Step 2.2: Batch Processing**
```dart
// Process data in batches to avoid memory issues
class BatchProcessor {
  static const int BATCH_SIZE = 100;
  
  static Future<void> processDataInBatches<T>(
    List<T> data,
    Future<void> Function(List<T>) processor,
  ) async {
    for (int i = 0; i < data.length; i += BATCH_SIZE) {
      final batch = data.sublist(
        i, 
        math.min(i + BATCH_SIZE, data.length)
      );
      
      await processor(batch);
      
      // Progress reporting
      final progress = ((i + batch.length) / data.length * 100).round();
      print('Progress: $progress% (${i + batch.length}/${data.length})');
      
      // Rate limiting to avoid Firebase quotas
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}
```

### **PHASE 3: FIREBASE IMPORT** (1 dan)

#### **Step 3.1: Firestore Batch Writes**
```dart
// lib/scripts/firebase_importer.dart
class FirebaseImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static Future<ImportResult> importToFirestore() async {
    final result = ImportResult();
    
    try {
      // 1. Import master data first (no dependencies)
      await _importDrivers(result);
      await _importAddresses(result);
      await _importRoutes(result);
      await _importVehicles(result);
      
      // 2. Import dependent data
      await _importMonthlyPassengers(result);
      await _importDailyPassengers(result);
      await _importTravelHistory(result);
      
      // 3. Import time-series data (large volume)
      await _importGPSLocations(result);
      
      result.success = true;
    } catch (e) {
      result.error = e.toString();
    }
    
    return result;
  }
  
  static Future<void> _importDrivers(ImportResult result) async {
    final driversData = await DataLoader.loadTransformedDrivers();
    
    await BatchProcessor.processDataInBatches(
      driversData,
      (batch) async {
        final writeBatch = _firestore.batch();
        
        for (final driver in batch) {
          final docRef = _firestore.collection('drivers').doc(driver['id']);
          writeBatch.set(docRef, driver);
        }
        
        await writeBatch.commit();
        result.importedDrivers += batch.length;
      }
    );
  }
  
  static Future<void> _importGPSLocations(ImportResult result) async {
    // Special handling for large time-series data
    final gpsData = await DataLoader.loadTransformedGPSLocations();
    
    // Subcollection strategy: vehicles/{vehicleId}/gps_locations/{locationId}
    await BatchProcessor.processDataInBatches(
      gpsData,
      (batch) async {
        final writeBatch = _firestore.batch();
        
        for (final location in batch) {
          final vehicleId = location['vozilo_id'];
          final locationId = location['id'];
          
          final docRef = _firestore
            .collection('vehicles')
            .doc(vehicleId)
            .collection('gps_locations')
            .doc(locationId);
            
          writeBatch.set(docRef, location);
        }
        
        await writeBatch.commit();
        result.importedGPSLocations += batch.length;
      }
    );
  }
}
```

#### **Step 3.2: Data Validation Post-Import**
```dart
class PostImportValidator {
  static Future<ValidationReport> validateFirestoreData() async {
    final report = ValidationReport();
    
    // 1. Count verification
    final driverCount = await _firestore.collection('drivers').count().get();
    report.addCheck('drivers_count', driverCount.count);
    
    // 2. Reference integrity
    final monthlyPassengers = await _firestore.collection('monthly_passengers').get();
    for (final doc in monthlyPassengers.docs) {
      final data = doc.data();
      if (data['adresa_id'] != null) {
        final addressExists = await _firestore.collection('addresses').doc(data['adresa_id']).get();
        if (!addressExists.exists) {
          report.addError('missing_address_reference', doc.id);
        }
      }
    }
    
    // 3. Data format verification
    await _validateGeoPoints(report);
    await _validateTimestamps(report);
    await _validatePolasciPoDanu(report);
    
    return report;
  }
  
  static Future<void> _validateGeoPoints(ValidationReport report) async {
    final addresses = await _firestore.collection('addresses').get();
    for (final doc in addresses.docs) {
      final data = doc.data();
      if (data['koordinate'] != null) {
        final geoPoint = data['koordinate'] as GeoPoint;
        if (geoPoint.latitude < -90 || geoPoint.latitude > 90 ||
            geoPoint.longitude < -180 || geoPoint.longitude > 180) {
          report.addError('invalid_geopoint', doc.id);
        }
      }
    }
  }
}
```

---

## 🧪 TESTING STRATEGY

### **PHASE 4: COMPREHENSIVE TESTING** (2-3 dana)

#### **Step 4.1: Unit Tests - Model Validation**
```dart
// test/models/mesecni_putnik_test.dart
void main() {
  group('MesecniPutnik Firebase Migration', () {
    test('should convert from Firestore document correctly', () {
      // Test data from actual Firebase document
      final firestoreData = {
        'putnik_ime': 'Marko Petrović',
        'tip': 'radnik',
        'polasci_po_danu': {
          'pon': ['07:00 BC', '15:00 VS'],
          'uto': ['07:00 BC']
        },
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      };
      
      final putnik = MesecniPutnik.fromFirestore(firestoreData);
      
      expect(putnik.putnikIme, equals('Marko Petrović'));
      expect(putnik.polasciPoDanu['pon'], contains('07:00 BC'));
      expect(putnik.polasciPoDanu['pon'], contains('15:00 VS'));
    });
    
    test('should handle missing polasci_po_danu gracefully', () {
      final firestoreData = {
        'putnik_ime': 'Test Putnik',
        'tip': 'radnik',
        // polasci_po_danu missing
      };
      
      final putnik = MesecniPutnik.fromFirestore(firestoreData);
      expect(putnik.polasciPoDanu, isEmpty);
    });
  });
}

// test/models/adresa_test.dart
void main() {
  group('Adresa GeoPoint Migration', () {
    test('should convert GeoPoint correctly', () {
      final firestoreData = {
        'ulica': 'Glavna',
        'grad': 'Bela Crkva',
        'koordinate': GeoPoint(44.898, 21.417),
      };
      
      final adresa = Adresa.fromFirestore(firestoreData);
      
      expect(adresa.koordinate!.latitude, closeTo(44.898, 0.001));
      expect(adresa.koordinate!.longitude, closeTo(21.417, 0.001));
    });
  });
}
```

#### **Step 4.2: Integration Tests - Service Layer**
```dart
// test/services/firestore_service_test.dart
void main() {
  group('FirestoreService Integration', () {
    late FirebaseFirestore firestore;
    
    setUpAll(() async {
      // Use Firebase Emulator for testing
      firestore = FirebaseFirestore.instance;
      firestore.useFirestoreEmulator('localhost', 8080);
    });
    
    test('should add and retrieve putnik correctly', () async {
      final putnik = Putnik(
        ime: 'Test Putnik',
        polazak: '07:00 BC',
        pokupljen: false,
      );
      
      final putnikId = await FirestoreService.addPutnik(putnik);
      expect(putnikId, isNotNull);
      
      final retrieved = await FirestoreService.getPutnikById(putnikId!);
      expect(retrieved, isNotNull);
      expect(retrieved!.ime, equals('Test Putnik'));
    });
    
    test('should handle realtime streams correctly', () async {
      final stream = FirestoreService.putniciStream();
      
      // Add a putnik
      final putnik = Putnik(ime: 'Stream Test', polazak: '08:00 BC');
      await FirestoreService.addPutnik(putnik);
      
      // Verify stream emits the new putnik
      final putnici = await stream.first;
      expect(putnici.any((p) => p.ime == 'Stream Test'), isTrue);
    });
  });
}
```

#### **Step 4.3: End-to-End Tests - Complete Workflows**
```dart
// test/e2e/migration_workflow_test.dart
void main() {
  group('Complete Migration Workflow', () {
    test('should migrate vozac with all dependencies', () async {
      // 1. Create test data in Supabase format
      final supabaseVozac = {
        'id': 'test-vozac-1',
        'ime': 'Test Vozač',
        'email': 'test@gavra013.rs',
        'kusur': 150.0,
        'created_at': '2025-01-01T00:00:00Z',
      };
      
      // 2. Transform to Firebase format
      final firebaseVozac = DataTransformer.transformVozac(supabaseVozac);
      
      // 3. Import to Firestore
      await FirestoreService.addVozac(firebaseVozac);
      
      // 4. Verify data integrity
      final retrieved = await FirestoreService.getVozacById('test-vozac-1');
      expect(retrieved.ime, equals('Test Vozač'));
      expect(retrieved.kusur, equals(150.0));
      expect(retrieved.email, equals('test@gavra013.rs'));
    });
    
    test('should handle complete passenger workflow', () async {
      // Test: Add monthly passenger -> Generate daily passenger -> Mark as picked up
      
      // 1. Add monthly passenger
      final mesecniPutnik = MesecniPutnik(
        putnikIme: 'E2E Test Putnik',
        polasciPoDanu: {
          'pon': ['07:00 BC', '15:00 VS'],
        },
        // ... other fields
      );
      
      final mesecniId = await FirestoreService.addMesecniPutnik(mesecniPutnik);
      
      // 2. Generate daily passenger for today
      final dnevniPutnik = DnevniPutnik.fromMesecni(mesecniPutnik, DateTime.now());
      final dnevniId = await FirestoreService.addDnevniPutnik(dnevniPutnik);
      
      // 3. Mark as picked up
      await FirestoreService.oznaciPokupljen(dnevniId, 'Test Vozač');
      
      // 4. Verify workflow completion
      final updated = await FirestoreService.getDnevniPutnikById(dnevniId);
      expect(updated.pokupljen, isTrue);
      expect(updated.pokupioVozac, equals('Test Vozač'));
    });
  });
}
```

#### **Step 4.4: Performance Tests**
```dart
// test/performance/firestore_performance_test.dart
void main() {
  group('Firestore Performance', () {
    test('should handle large data queries efficiently', () async {
      final stopwatch = Stopwatch()..start();
      
      // Query large dataset
      final putnici = await FirestoreService.getAllPutnici();
      
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // < 2 seconds
      expect(putnici.length, greaterThan(0));
    });
    
    test('should handle concurrent operations', () async {
      final futures = <Future>[];
      
      // Create 10 concurrent operations
      for (int i = 0; i < 10; i++) {
        futures.add(FirestoreService.addPutnik(
          Putnik(ime: 'Concurrent Test $i', polazak: '07:00 BC')
        ));
      }
      
      final results = await Future.wait(futures);
      
      // All operations should succeed
      expect(results.every((id) => id != null), isTrue);
    });
  });
}
```

#### **Step 4.5: Error Handling Tests**
```dart
// test/error_handling/migration_error_test.dart
void main() {
  group('Migration Error Handling', () {
    test('should handle invalid GeoPoint data gracefully', () async {
      final invalidAdresa = {
        'ulica': 'Test',
        'grad': 'Test',
        'koordinate': 'INVALID_COORDINATES', // Invalid data
      };
      
      expect(
        () => DataTransformer.transformAdresa(invalidAdresa),
        returnsNormally,
      );
      
      final transformed = DataTransformer.transformAdresa(invalidAdresa);
      expect(transformed['koordinate'], isNull);
    });
    
    test('should handle missing foreign keys', () async {
      final putnikWithInvalidAdresa = {
        'ime': 'Test Putnik',
        'adresa_id': 'non-existent-address',
      };
      
      // Should not crash, but should be flagged in validation
      final validation = await DataValidator.validateForeignKeys([putnikWithInvalidAdresa]);
      expect(validation.hasErrors, isTrue);
      expect(validation.errors, contains('missing_address'));
    });
  });
}
```

---

## 📊 MONITORING & VALIDATION

### **Real-time Migration Dashboard**
```dart
class MigrationDashboard {
  static Stream<MigrationStatus> monitorProgress() {
    return Stream.periodic(Duration(seconds: 5), (_) async {
      return MigrationStatus(
        exportedRecords: await _countSupabaseRecords(),
        transformedRecords: await _countTransformedFiles(),
        importedRecords: await _countFirestoreRecords(),
        validationErrors: await _getValidationErrors(),
        currentPhase: await _getCurrentPhase(),
      );
    }).asyncMap((future) => future);
  }
}
```

### **Data Integrity Checks**
```dart
class IntegrityChecker {
  static Future<IntegrityReport> performFullCheck() async {
    final report = IntegrityReport();
    
    // 1. Record counts comparison
    await _compareRecordCounts(report);
    
    // 2. Sample data verification
    await _verifySampleData(report);
    
    // 3. Foreign key integrity
    await _checkForeignKeys(report);
    
    // 4. Data format validation
    await _validateDataFormats(report);
    
    return report;
  }
}
```

---

## 🎯 SUCCESS CRITERIA

### **Data Migration Success**
- ✅ **100% data transferred** without loss
- ✅ **All foreign keys intact** and validated
- ✅ **Coordinate conversion accurate** (PostgreSQL POINT → GeoPoint)
- ✅ **JSON structure preserved** (polasci_po_danu)
- ✅ **Timestamp formats consistent** (ISO 8601 → Firestore Timestamp)

### **Performance Benchmarks**
- ✅ **Query performance** equal or better than Supabase
- ✅ **Migration time** under 4 hours for full dataset
- ✅ **Error rate** less than 0.1% during migration
- ✅ **Rollback capability** within 30 minutes if needed

### **Functionality Validation**
- ✅ **All app features working** after migration
- ✅ **Realtime updates functioning** correctly
- ✅ **Authentication preserved** for existing users
- ✅ **Offline capability** working properly

---

## 🚨 ROLLBACK STRATEGY

### **Emergency Rollback Plan**
```dart
class RollbackManager {
  static Future<void> emergencyRollback() async {
    // 1. Stop Firebase traffic
    await FirebaseService.disableFirebaseRouting();
    
    // 2. Restore Supabase routing  
    await SupabaseService.enableSupabaseRouting();
    
    // 3. Validate Supabase connectivity
    final isHealthy = await SupabaseService.healthCheck();
    if (!isHealthy) {
      throw RollbackException('Supabase not responding');
    }
    
    // 4. Notify monitoring systems
    await AlertingService.sendRollbackAlert();
    
    print('✅ Emergency rollback completed successfully');
  }
}
```

---

## 📅 TIMELINE SUMMARY

### **Total Migration Time: 4-5 dana**

| Phase | Duration | Activities |
|-------|----------|------------|
| **Day 1** | Export & Validation | Supabase data export, validation, cleanup |
| **Day 2** | Transformation | Schema mapping, data transformation, batch processing |  
| **Day 3** | Import & Validation | Firebase import, post-import validation |
| **Day 4-5** | Testing | Unit tests, integration tests, E2E testing |

### **Risk Mitigation**
- ✅ **Parallel environments** - Keep both Supabase and Firebase running
- ✅ **Feature flags** - Gradual traffic migration
- ✅ **Monitoring** - Real-time health checks
- ✅ **Rollback plan** - Emergency fallback to Supabase

---

## 🏁 FINAL RECOMMENDATION

### **MIGRATION READINESS**: ✅ **EXCELLENT**

**Podaci mogu da se bezbedno migriraju sa Supabase na Firebase jer:**

1. **Struktura podataka je kompatibilna** - Minor transformations needed
2. **Firebase implementacija je već testirana** - Auth i Realtime rade
3. **Rollback strategija je definisana** - Emergency fallback ready
4. **Testiranje je sveobuhvatno** - Unit, integration, E2E tests planned

### **PREPORUČENA STRATEGIJA**: Incremental migration sa feature flags

**RISK LEVEL**: 🟡 Medium-Low (dobro planirana migracija)  
**SUCCESS PROBABILITY**: 🟢 95%+ (na osnovu postojeće Firebase implementacije)

---

**STATUS**: ✅ Migration plan completed  
**NEXT ACTION**: Execute migration during low-traffic period  
**ESTIMATED DOWNTIME**: < 30 minutes (feature flag switch)