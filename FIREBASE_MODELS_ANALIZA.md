# 🧩 ANALIZA MODELA PODATAKA - FIREBASE MIGRACIJA

**Datum**: 24.10.2025  
**Status**: Detaljnu analizu svih model klasa  

---

## 📋 PREGLED MODELA

### **Trenutno stanje**: 11 model klasa za Supabase (PostgreSQL)
### **Cilj**: Adaptacija za Firebase Firestore (NoSQL)

---

## 🔄 MODEL-BY-MODEL ANALIZA

### 1. **Putnik** → Firebase ready ✅
```dart
// Trenutno: SUPABASE optimizovan
class Putnik {
  String id;
  String ime;
  String polazak;
  bool pokupljen;
  DateTime? vremeDodavanja;
  // toMap(), fromMap() metode ✅
}

// Potrebno: FIRESTORE prilagođenje
// ✅ Već ima Firestore toMap() metodu
// ✅ Timestamp conversion ready
// ✅ Minimal changes needed
```

### 2. **MesecniPutnik** → Kompleksna migracija ⚠️
```dart
// Trenutno: PostgreSQL JSON struktura
{
  'polasci_po_danu': jsonEncode({
    'pon': ['07:00 BC', '15:00 VS'],
    'uto': ['07:00 BC']
  })
}

// Firebase: Native Map struktura
{
  'polasci_po_danu': {
    'pon': ['07:00 BC', '15:00 VS'],
    'uto': ['07:00 BC']
  }
}

// Potrebne izmene:
// 🔄 Remove jsonEncode/jsonDecode
// 🔄 Direct Map<String, List<String>> support
// ✅ MesecniHelpers.parsePolasciPoDanu() već postoji
```

### 3. **DnevniPutnik** → Medium changes 🟡
```dart
// Trenutno: Foreign key references
{
  'adresa_id': 'uuid',
  'ruta_id': 'uuid'
}

// Firebase: DocumentReference ili denormalization
{
  'adresa_id': 'uuid', // Keep as string reference
  'ruta_id': 'uuid',
  // Denormalized data for performance:
  'adresa_naziv': 'Bela Crkva, Centar',
  'ruta_naziv': 'BC-VS',
  'ruta_cena': 200.0
}

// Potrebne izmene:
// 🔄 Add denormalized fields
// 🔄 Enum handling (DnevniPutnikStatus)
// ✅ DateTime fields already compatible
```

### 4. **PutovanjaIstorija** → Minor changes ✅
```dart
// Trenutno: Well structured for NoSQL
// Potrebne izmene:
// ✅ Already NoSQL friendly
// ✅ DateTime fields compatible
// 🔄 Minor enum adjustments only
```

### 5. **Adresa** → Geographic data handling 🗺️
```dart
// Trenutno: PostgreSQL POINT type
{
  'koordinate': 'POINT(19.123 44.456)' // PostgreSQL format
}

// Firebase: GeoPoint type
{
  'koordinate': {
    'latitude': 44.456,
    'longitude': 19.123
  }
}

// Potrebne izmene:
// 🔄 PostgreSQL POINT → Firebase GeoPoint
// 🔄 String parsing → structured coordinates
// ✅ UUID handling compatible
```

### 6. **Vozac** → Simple migration ✅
```dart
// Trenutno: Basic structure
// Firebase: Add kusur field + auth reference
{
  'id': 'uuid',
  'ime': 'string',
  'email': 'string',
  'kusur': 'number', // ⭐ ADD from separate query
  'firebase_uid': 'string' // ⭐ ADD auth reference
}

// Potrebne izmene:
// 🔄 Add kusur field (currently separate table)
// 🔄 Add Firebase Auth UID reference
// ✅ Basic structure compatible
```

### 7. **Vozilo** → GPS integration 🚗
```dart
// Trenutno: Basic vehicle data
// Firebase: Add current GPS position
{
  'id': 'uuid',
  'registracija': 'string',
  'trenutna_pozicija': { // ⭐ ADD from gps_lokacije
    'latitude': 'number',
    'longitude': 'number',
    'timestamp': 'timestamp'
  }
}

// Potrebne izmene:
// 🔄 Denormalize current GPS position
// ✅ Basic structure compatible
```

### 8. **GPSLokacija** → GeoPoint migration 🛰️
```dart
// Trenutno: Separate lat/lng fields
// Firebase: GeoPoint + improved structure
{
  'pozicija': GeoPoint(latitude, longitude), // ⭐ CHANGE
  'brzina': 'number',
  'pravac': 'number',
  'timestamp': 'timestamp'
}

// Potrebne izmene:
// 🔄 Combine lat/lng into GeoPoint
// 🔄 Better timestamp handling
// ✅ Business logic methods compatible
```

### 9. **Ruta** → Add pricing denormalization 💰
```dart
// Trenutno: Basic route data
// Firebase: Add denormalized pricing
{
  'id': 'uuid',
  'naziv': 'string',
  'cena': 'number', // ⭐ ADD denormalized pricing
  'aktivne_cene': { // ⭐ ADD for different passenger types
    'radnik': 200,
    'ucenik': 150
  }
}

// Potrebne izmene:
// 🔄 Add pricing fields
// ✅ Validation logic already excellent
// ✅ Helper methods compatible
```

### 10. **RealtimeRouteData** → Stream optimization 📡
```dart
// Trenutno: Real-time tracking data
// Firebase: Firestore streams native support
// ✅ No structural changes needed
// ✅ Already optimized for real-time updates
```

### 11. **TurnByTurnInstruction** → Navigation data ⚠️
```dart
// Trenutno: Complex navigation structure
// Firebase: Consider Cloud Storage for large datasets
// 🔄 May need restructuring for large route datasets
// ✅ Basic structure compatible
```

---

## 🔧 FIREBASE ADAPTACIJA STRATEGIJE

### **HIGH PRIORITY Changes**

#### 1. **Timestamp Conversion**
```dart
// Old: DateTime.toIso8601String()
'created_at': DateTime.now().toIso8601String()

// New: Firestore Timestamp
'created_at': FieldValue.serverTimestamp()
```

#### 2. **JSON Field Handling**
```dart
// Old: jsonEncode/jsonDecode
'polasci_po_danu': jsonEncode(polasciMap)

// New: Direct Map support
'polasci_po_danu': polasciMap
```

#### 3. **GeoPoint Migration**
```dart
// Old: String coordinates
'koordinate': 'POINT(19.123 44.456)'

// New: GeoPoint
'koordinate': GeoPoint(44.456, 19.123)
```

### **MEDIUM PRIORITY Changes**

#### 1. **Denormalization Strategy**
```dart
// Add frequently queried data to reduce joins
class DnevniPutnik {
  // Existing fields...
  String? adresaNaziv; // Denormalized from adrese
  String? rutaNaziv;   // Denormalized from rute
  double? rutaCena;    // Denormalized for quick access
}
```

#### 2. **Reference Management**
```dart
// Keep IDs for relationships, add names for performance
{
  'adresa_id': 'uuid-123',
  'adresa_naziv': 'Bela Crkva, Centar', // Denormalized
  'ruta_id': 'uuid-456',
  'ruta_naziv': 'BC-VS'                 // Denormalized
}
```

### **LOW PRIORITY Changes**

#### 1. **Enhanced Validation**
```dart
// Add Firestore-specific validation
bool get isValidForFirestore {
  return isValid && 
         id.isNotEmpty && 
         !containsInvalidFirestoreChars();
}
```

#### 2. **Subcollection Support**
```dart
// Consider subcollections for large datasets
// vozila/{voziloId}/gps_lokacije/{lokacijaId}
// putnici/{putnikId}/putovanja/{putovanjeId}
```

---

## 🚀 MIGRATION PLAN

### **Phase 1: Core Models (1-2 dana)**
1. ✅ Putnik - minimal changes
2. 🔄 Vozac - add kusur + auth fields
3. 🔄 Adresa - GeoPoint conversion
4. 🔄 Ruta - add pricing fields

### **Phase 2: Complex Models (2-3 dana)**
1. 🔄 MesecniPutnik - JSON → Map conversion
2. 🔄 DnevniPutnik - denormalization
3. 🔄 GPSLokacija - GeoPoint migration
4. ✅ PutovanjaIstorija - minimal changes

### **Phase 3: Specialized Models (1 dan)**
1. ✅ RealtimeRouteData - ready
2. 🔄 TurnByTurnInstruction - potential restructure
3. ✅ Vozilo - add GPS denormalization

---

## 🛠️ KODOVA PRIMER - Firebase Adaptacije

### **MesecniPutnik Firebase Version**
```dart
class MesecniPutnik {
  // Existing fields...
  
  // 🔥 FIREBASE SPECIFIC
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'putnik_ime': putnikIme,
      'polasci_po_danu': polasciPoDanu, // Direct Map, no JSON
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      // ... other fields
    };
  }
  
  factory MesecniPutnik.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc
  ) {
    final data = doc.data()!;
    return MesecniPutnik(
      id: doc.id,
      putnikIme: data['putnik_ime'] as String,
      polasciPoDanu: Map<String, List<String>>.from(
        data['polasci_po_danu'] as Map
      ),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      // ... other fields
    );
  }
}
```

### **Adresa Firebase Version**
```dart
class Adresa {
  // 🔥 FIREBASE GEOPOINT
  final GeoPoint? koordinate;
  
  Map<String, dynamic> toFirestoreMap() {
    return {
      'ulica': ulica,
      'grad': grad,
      'koordinate': koordinate, // Direct GeoPoint
      'created_at': FieldValue.serverTimestamp(),
    };
  }
  
  factory Adresa.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Adresa(
      id: doc.id,
      ulica: data['ulica'],
      grad: data['grad'],
      koordinate: data['koordinate'] as GeoPoint?,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}
```

---

## ✅ SUMMARY

### **Ready for Firebase**: 4 modela
- Putnik ✅
- PutovanjaIstorija ✅  
- RealtimeRouteData ✅
- Vozilo ✅ (minor GPS denormalization)

### **Medium Effort**: 5 modela
- MesecniPutnik 🔄 (JSON → Map)
- DnevniPutnik 🔄 (denormalization)
- Vozac 🔄 (add kusur field)
- Ruta 🔄 (add pricing)
- GPSLokacija 🔄 (GeoPoint)

### **Complex**: 2 modela
- Adresa 🔄 (coordinate conversion)
- TurnByTurnInstruction ⚠️ (potential restructure)

**UKUPNO EFFORT**: 3-4 dana za sve model adaptacije

**RISK LEVEL**: 🟡 Medium - dobro planirano, poznate izmene

---

**STATUS**: 📋 Model analiza završena  
**NEXT**: Analiza servisa i API poziva