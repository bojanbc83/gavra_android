# 🍎 GAVRA iOS BUILD GUIDE - WINDOWS TO macOS

## ❌ GLAVNI PROBLEM
Ti si na **Windows sistemu** i pokušavaš da builduješ iOS aplikaciju. iOS build radi **SAMO NA macOS-u**!

## ✅ REŠENJE

### 1. PREBACI PROJEKAT NA macOS
```bash
# Na macOS sistemu:
git clone https://github.com/bojanbc83/gavra_android.git
cd gavra_android
chmod +x scripts/prepare_ios_build.sh
./scripts/prepare_ios_build.sh
```

### 2. iOS KONFIGURACIJA JE ISPRAVNA ✅
- ✅ Bundle ID: `com.gavra013.gavraAndroid` 
- ✅ Firebase pravilno konfigurisan
- ✅ Permissions u Info.plist su dobri
- ✅ Podfile ima iOS 14.0+ kompatibilnost
- ✅ AppDelegate.swift ima Firebase i notifications
- ✅ Provisioning profiles su prisutni
- ✅ ExportOptionsTestFlight.plist konfigurisan

### 3. MANJE GREŠKE KOJE SAM POPRAVIO
- ❌ **Duplirani NSContactsUsageDescription** u Info.plist → ✅ **POPRAVLJENO**

### 4. XCODE SETUP NA macOS
```bash
# U Xcode:
1. Otvori ios/Runner.xcworkspace (NE .xcodeproj!)
2. Selectuj Apple Developer Team: 6CY9Q44KMQ
3. Proveri Bundle ID: com.gavra013.gavraAndroid
4. Build za device/simulator: ⌘+B
```

### 5. TESTFLIGHT DEPLOYMENT
```bash
# Nakon uspešnog build-a:
./scripts/deploy_testflight.sh
```

## 🔧 ALTERNATIVNO REŠENJE ZA WINDOWS

### GitHub Actions CI/CD
Možeš koristiti GitHub Actions za automatski iOS build:

```yaml
# .github/workflows/ios.yml
name: iOS Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build ios --release
```

### Cloud Build Services
- **Codemagic** (vidim da imaš codemagic.yaml)
- **Bitrise** 
- **AppCenter**

## 📱 TRENUTNO STANJE
- Android build: ✅ Radi na Windows
- iOS build: ❌ Ne može na Windows - MORA macOS!

## 🎯 SLEDEĆI KORACI
1. Prebaci na macOS ili koristi cloud build
2. Pokreni `./scripts/prepare_ios_build.sh`
3. Otvori u Xcode i build
4. Deploy na TestFlight
