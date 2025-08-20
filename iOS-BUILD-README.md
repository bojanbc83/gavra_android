# 📱 iOS Cloud Build Setup

## 🚫 NEMA LOKALNIH iOS FAJLOVA
Ovaj projekt je konfigurisan za **cloud-only iOS build** preko GitHub Actions ili Codemagic.

## ✅ ŠTA IMAŠ U PROJEKTU:
- `AuthKey_F4P38UR78G.p8` - App Store Connect API key
- `ios/fastlane/Fastfile` - Cloud build konfiguracija  
- `ios/Runner.xcodeproj/` - Xcode projekt
- `ios/Runner/GoogleService-Info.plist` - Firebase config

## 🔐 POTREBNE ENVIRONMENT VARIABLES:

### GitHub Actions Secrets:
```
IOS_CERTIFICATE_BASE64          # Base64 encoded .p12 sertifikat
IOS_CERTIFICATE_PASSWORD        # Password za .p12 sertifikat  
IOS_PROVISIONING_PROFILE_BASE64 # Base64 encoded .mobileprovision
```

### Codemagic Environment Variables:
```
IOS_CERTIFICATE_BASE64          # Distribution certificate
IOS_CERTIFICATE_PASSWORD        # Certificate password
IOS_PROVISIONING_PROFILE_BASE64 # App Store provisioning profile
```

## 🚀 KAKO POKRENUTI BUILD:

### GitHub Actions:
```yaml
- name: Build iOS
  run: |
    cd ios
    bundle exec fastlane build_cloud
```

### Codemagic:
```yaml
scripts:
  - cd ios && bundle exec fastlane build_and_upload
```

## 📋 BUNDLE ID KONFIGURACIJA:
```
Xcode:        com.gavra013.gavraAndroid
Firebase:     com.gavra.gavra013         ❌ TREBA FIKSIRATI!
Provisioning: com.gavra013.gavraAndroid
```

## ❌ GLAVNI PROBLEM:
Firebase bundle ID ne odgovara Xcode-u! Treba kreirati novi iOS app u Firebase Console sa bundle ID: `com.gavra013.gavraAndroid`

## 🔧 FASTLANE LANES:
- `build_cloud` - Build iOS aplikacije
- `upload_testflight` - Upload na TestFlight
- `build_and_upload` - Kompletny process

## 🆔 APP STORE CONNECT:
- Team ID: `6CY9Q44KMQ`
- Key ID: `F4P38UR78G`
- Issuer ID: `d8b50e72-6330-401d-9aef-4ead356405ca`
