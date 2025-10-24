# 🔥 DUBOKA ANALIZA MIGRACIJE: SUPABASE → FIREBASE

**Datum**: 24.10.2025  
**Status**: Kompletna analiza za migraciju  
**Autor**: AI Assistant  

---

## 📊 TRENUTNO STANJE - SUPABASE IMPLEMENTACIJA

### 🗄️ SUPABASE TABELE (PostgreSQL)

| Tabela | Svrha | Broj kolona | Status |
|--------|-------|-------------|--------|
| `vozaci` | Vozači i njihov kusur | ~8 | ✅ Aktivno |
| `mesecni_putnici` | Mesečni putnici sa polascima | ~20 | ✅ Aktivno |
| `dnevni_putnici` | Dnevni putnici | ~15 | ✅ Aktivno |
| `putovanja_istorija` | Istorija putovanja | ~12 | ✅ Aktivno |
| `adrese` | Adrese sa koordinatama | ~8 | ✅ Aktivno |
| `vozila` | Vozila i GPS tracking | ~10 | ✅ Aktivno |
| `gps_lokacije` | GPS pozicije vozila | ~8 | ✅ Aktivno |
| `rute` | Rute sa cenama | ~6 | ✅ Aktivno |

### 🔐 AUTENTIFIKACIJA
- **Supabase Auth**: Email registracija, login, password reset
- **Session Management**: SharedPreferences + Supabase session
- **Email Verification**: Obavezno za login

### 🛰️ REALTIME FUNKCIONALNOSTI
- **Supabase Realtime**: PostgreSQL LISTEN/NOTIFY
- **Live Updates**: Putnici, GPS pozicije, status changes
- **Heartbeat Monitoring**: Connection health tracking

### 🧩 SERVISI (30+ fajlova)
- **Database Services**: CRUD operacije
- **Optimization Services**: Query caching, performance monitoring
- **Analytics Services**: Usage statistics, performance metrics
- **Backup Services**: Data export/import

---

## 🎯 FIREBASE MAPIRANJE

### 🔥 FIRESTORE KOLEKCIJE (NoSQL)

#### 1. **vozaci** → `drivers`
```javascript
{
  id: "uuid",
  ime: "string",
  email: "string?",
  kusur: "number",
  aktivan: "boolean",
  boja: "string",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 2. **mesecni_putnici** → `monthly_passengers`
```javascript
{
  id: "uuid",
  putnik_ime: "string",
  tip: "string", // 'radnik' | 'ucenik'
  tip_skole: "string?",
  broj_telefona: "string?",
  broj_telefona_oca: "string?",
  broj_telefona_majke: "string?",
  polasci_po_danu: {
    "pon": ["07:00 BC", "15:00 VS"],
    "uto": ["07:00 BC"],
    // ...
  },
  adresa_bela_crkva: "string?",
  adresa_vrsac: "string?",
  radni_dani: "string",
  datum_pocetka_meseca: "timestamp",
  datum_kraja_meseca: "timestamp",
  aktivan: "boolean",
  status: "string",
  ukupna_cena_meseca: "number",
  cena: "number?",
  broj_putovanja: "number",
  broj_otkazivanja: "number",
  vreme_placanja: "timestamp?",
  placeni_mesec: "number?",
  placena_godina: "number?",
  obrisan: "boolean",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 3. **dnevni_putnici** → `daily_passengers`
```javascript
{
  id: "uuid",
  ime: "string",
  broj_telefona: "string?",
  adresa_id: "string", // Reference to addresses
  ruta_id: "string", // Reference to routes
  datum: "timestamp",
  polazak: "string", // time string
  broj_mesta: "number",
  cena: "number",
  status: "string", // 'rezervisan' | 'pokupljen' | 'otkazan'
  napomena: "string?",
  vreme_pokupljenja: "timestamp?",
  pokupio_vozac_id: "string?",
  vreme_placanja: "timestamp?",
  naplatio_vozac_id: "string?",
  dodao_vozac_id: "string?",
  obrisan: "boolean",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 4. **putovanja_istorija** → `travel_history`
```javascript
{
  id: "uuid",
  mesecni_putnik_id: "string?", // Reference
  tip_putnika: "string",
  datum: "timestamp",
  vreme_polaska: "string",
  vreme_akcije: "timestamp?",
  adresa_polaska: "string",
  status: "string",
  putnik_ime: "string",
  broj_telefona: "string?",
  cena: "number",
  dan: "string?",
  grad: "string?",
  obrisan: "boolean",
  pokupljen: "boolean",
  vozac: "string?",
  vreme_placanja: "timestamp?",
  vreme_pokupljenja: "timestamp?",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 5. **adrese** → `addresses`
```javascript
{
  id: "uuid",
  ulica: "string",
  broj: "string?",
  grad: "string",
  postanski_broj: "string?",
  koordinate: {
    latitude: "number",
    longitude: "number"
  },
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 6. **vozila** → `vehicles`
```javascript
{
  id: "uuid",
  registracija: "string",
  model: "string",
  godina: "number?",
  trenutni_vozac_id: "string?", // Reference to drivers
  poslednja_gps_pozicija: {
    latitude: "number",
    longitude: "number",
    timestamp: "timestamp"
  },
  aktivan: "boolean",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

#### 7. **gps_lokacije** → `gps_locations`
```javascript
{
  id: "uuid",
  vozac: "string",
  vozilo_id: "string?", // Reference
  latitude: "number",
  longitude: "number",
  brzina: "number?",
  smer: "number?",
  tacnost: "number?",
  timestamp: "timestamp",
  created_at: "timestamp"
}
```

#### 8. **rute** → `routes`
```javascript
{
  id: "uuid",
  naziv: "string",
  cena: "number",
  grad_polaska: "string",
  grad_dolaska: "string",
  aktivna: "boolean",
  created_at: "timestamp",
  updated_at: "timestamp"
}
```

---

## 🔀 FIREBASE AUTH MAPIRANJE

### 🔐 Auth Strategy

#### **Supabase Auth** → **Firebase Auth**
- Email/Password authentication ✅
- Email verification ✅  
- Password reset ✅
- User metadata (driver_name) ✅

#### Custom Claims
```javascript
{
  driver_name: "string",
  driver_color: "string",
  role: "driver" | "admin"
}
```

---

## 🛰️ REALTIME MAPIRANJE

### **Supabase Realtime** → **Firestore Streams**

#### 1. Dnevni Putnici Stream
```dart
// Supabase
supabase.from('dnevni_putnici').stream()

// Firebase
FirebaseFirestore.instance
  .collection('daily_passengers')
  .where('datum', isEqualTo: today)
  .snapshots()
```

#### 2. GPS Tracking Stream
```dart
// Supabase
supabase.from('gps_lokacije').stream()

// Firebase
FirebaseFirestore.instance
  .collection('gps_locations')
  .where('vozac', isEqualTo: driver)
  .orderBy('timestamp', descending: true)
  .limit(1)
  .snapshots()
```

#### 3. Kusur Stream
```dart
// Supabase
supabase.from('vozaci').stream()

// Firebase
FirebaseFirestore.instance
  .collection('drivers')
  .snapshots()
```

---

## 📈 PREDNOSTI FIREBASE-a

### ✅ **Performance**
- **Offline Support**: Automatski cache
- **Auto-scaling**: Bez manual optimization
- **Global CDN**: Brži pristup podacima

### ✅ **Development**
- **Type Safety**: Bolje Flutter integration
- **Security Rules**: Declarative permissions
- **Analytics**: Ugrađen Google Analytics

### ✅ **Maintenance**
- **Managed Service**: Bez manual backup-a
- **Auto Updates**: Security patches
- **Monitoring**: Crashlytics, Performance

---

## ⚠️ CHALLENGES & SOLUTIONS

### 🔴 **Challenge 1: SQL → NoSQL**
**Problem**: Složeni JOIN upiti  
**Solution**: Denormalization + subcollections

### 🔴 **Challenge 2: RPC Functions**
**Problem**: PostgreSQL stored procedures  
**Solution**: Cloud Functions ili client-side logic

### 🔴 **Challenge 3: Complex Queries**
**Problem**: ILIKE, full-text search  
**Solution**: Algolia integration ili compound queries

### 🔴 **Challenge 4: Data Migration**
**Problem**: Postojeći podaci u Supabase  
**Solution**: Export/Import script sa validation

---

## 🚀 MIGRATION STRATEGY

### **FAZA 1**: Setup & Auth (1-2 dana)
1. Firebase project setup
2. Auth migration
3. Basic CRUD servisi

### **FAZA 2**: Core Data (3-4 dana)
1. Firestore struktura
2. Model adaptacije
3. Osnovni servisi

### **FAZA 3**: Advanced Features (2-3 dana)
1. Realtime streams
2. Complex queries
3. Performance optimization

### **FAZA 4**: Data Migration (1-2 dana)
1. Export iz Supabase
2. Import u Firestore
3. Data validation

### **FAZA 5**: Testing (2-3 dana)
1. Unit testovi
2. Integration testovi
3. Performance testovi

**UKUPNO**: 9-14 dana za kompletnu migraciju

---

## 💰 COST ANALYSIS

### **Supabase** (trenutno)
- Free tier: 500MB database
- Paid: $25/mesec za 8GB

### **Firebase** (nakon migracije)
- Free tier: 1GB Firestore + 50K reads/day
- Pay-as-you-scale: $0.18/100K reads

**Prognoza**: Slični troškovi, bolje skaliranje

---

## 🎯 PRIORITETI ZA MIGRACIJU

### **KRITIČNO (P0)**
1. ✅ Auth sistem
2. ✅ Dnevni putnici CRUD
3. ✅ Mesečni putnici CRUD
4. ✅ Realtime updates

### **VAŽNO (P1)**
1. 🔄 GPS tracking
2. 🔄 Statistike
3. 🔄 Export/Import

### **OPTIONAL (P2)**
1. 🔄 Advanced analytics
2. 🔄 Performance monitoring
3. 🔄 Backup automatization

---

## 📝 NEXT STEPS

1. **Setup Firebase Project** ✅ (Already done)
2. **Create Migration Scripts**
3. **Start with Auth Migration**
4. **Migrate Core Models**
5. **Test & Validate**

---

**STATUS**: 📋 Ready for implementation  
**ESTIMATED EFFORT**: 9-14 dana  
**RISK LEVEL**: 🟡 Medium (well-planned)  