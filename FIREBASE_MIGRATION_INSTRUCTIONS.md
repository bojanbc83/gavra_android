# 🔥 GAVRA 013 - FIREBASE MIGRACIJA: KOMPLETNE INSTRUKCIJE

## 📋 PRE-REQUISITES

1. **Supabase Anon Key** - potreban za export postojećih podataka
2. **Firebase projekt** - već konfigurisan (✅ GOTOVO)  
3. **Internet konekcija** - za export/import operacije
4. **Flutter/Dart environment** - za pokretanje skriptova

## 🚀 KORAK PO KORAK MIGRACIJA

### FAZA 1: EXPORT POSTOJEĆIH PODATAKA (30-60 min)

#### Option A: Automatski Dart skript (preporučeno ako imaš Supabase key)
```bash
# 1. Ažuriraj Supabase credentials u:
lib/scripts/supabase_export.dart

# 2. Pokreni export
dart run lib/scripts/supabase_export.dart
```

#### Option B: Ručni PowerShell export (Windows)
```powershell
# 1. Ažuriraj SUPABASE_ANON_KEY u:
manual_supabase_export.ps1

# 2. Pokreni PowerShell script
.\manual_supabase_export.ps1
```

#### Option C: Ručni Bash export (Linux/Mac)
```bash
# 1. Ažuriraj SUPABASE_ANON_KEY u:
manual_supabase_export.sh

# 2. Pokreni bash script
chmod +x manual_supabase_export.sh
./manual_supabase_export.sh
```

**🎯 Rezultat**: `backup/manual_export_YYYYMMDD_HHMMSS/` direktorij sa JSON fajlovima

---

### FAZA 2: TRANSFORMACIJA PODATAKA (15-30 min)

```bash
# Transformiše Supabase format → Firebase format
dart run lib/scripts/data_transformer.dart
```

**🎯 Rezultat**: `backup/.../firebase_ready/` direktorij sa Firebase-kompatibilnim podacima

---

### FAZA 3: FIREBASE IMPORT (30-60 min)

```bash
# OPASNO: Briše postojeće Firebase podatke
dart run lib/scripts/firebase_importer.dart --clear

# BEZBEDNO: Dodaje podatke bez brisanja postojećih
dart run lib/scripts/firebase_importer.dart
```

**🎯 Rezultat**: Svi podaci importovani u Firebase Firestore

---

### FAZA 4: VALIDACIJA I TESTIRANJE (15-30 min)

```bash
# Pokreni unit testove
flutter test test/firebase_migration_test.dart

# Pokreni full test suite
flutter test
```

**🎯 Rezultat**: Potvrda da su svi podaci ispravno migrirani

---

## 🔧 TROUBLESHOOTING

### Problem: "Supabase key je neispravan"
```bash
# Proveri key u Supabase dashboard:
# https://supabase.com/dashboard → Project → Settings → API
```

### Problem: "Firebase inicijalizacija neuspešna"
```bash
# Reinstaliraj Firebase CLI:
npm install -g firebase-tools
firebase login
```

### Problem: "Dart skript neće da se pokrene"
```bash
# Ažuriraj dependencies:
flutter pub get
```

### Problem: "Import je spor"
```bash
# Normalno je - velike količine podataka se importuju batchwise
# GPS lokacije mogu imati hiljade zapisa
```

---

## 📊 OČEKIVANI TIMELINE

| Faza | Vreme | Opis |
|------|-------|------|
| Export | 30-60 min | Zavisi od količine GPS podataka |
| Transform | 15-30 min | Konverzija PostgreSQL → Firestore |
| Import | 30-60 min | Batch import u Firebase |
| Test | 15-30 min | Validacija i testiranje |
| **UKUPNO** | **1.5-3h** | **Kompletna migracija** |

---

## 🎯 SUCCESS CRITERIA

✅ **Svi podaci migrirani**: 8 glavnih kolekcija  
✅ **GeoPoint konverzija**: PostgreSQL POINT → Firebase GeoPoint  
✅ **Search terms**: Generisani za pretragu  
✅ **References**: Međukolekcijske veze očuvane  
✅ **Timestamps**: Pravilno konvertovani  
✅ **Testovi prolaze**: Unit i integration testovi  

---

## 🔄 ROLLBACK PLAN (ako nešto pođe po zlu)

1. **Firebase rollback**: Obriši Firestore kolekcije
```bash
# Kroz Firebase console ili CLI
firebase firestore:delete --all-collections
```

2. **Kod rollback**: Vrati Supabase servise iz backup-a
```bash
# Prekopiraj _backup.dart fajlove preko originalnih
```

3. **Dependencies rollback**: Dodaj supabase_flutter u pubspec.yaml
```yaml
dependencies:
  supabase_flutter: ^1.10.25  
```

---

## 📞 PODRŠKA

Ako imaš problema tokom migracije:

1. **Provjeri log fajlove** - skriptovi pišu detaljne greške
2. **Validiraj credentials** - Supabase key i Firebase config
3. **Provjeri network** - stabilna internet konekcija
4. **Backup prvo** - uvek napravi backup pre većih izmjena

---

**🎉 KADA ZAVRŠIŠ**: Imaćeš potpuno funkcionalan Firebase backend umesto Supabase-a!