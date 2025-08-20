# 🍎 iOS Cloud Build Setup - ZAVRŠENO ✅

## 🔧 GitHub Secrets Configuration

Za iOS build preko GitHub Actions, trebaju se postaviti sljedeći **Secrets** u GitHub repozitoriju:

### 📋 Required GitHub Secrets

1. **IOS_CERTIFICATE_BASE64**
   - Base64 encoded sadržaj certificate datoteke (.p12)
   - Komanda za kreiranje: `base64 -i ios_with_pass.p12 -o ios_cert_base64.txt`
   - Ili koristiti online base64 encoder

2. **IOS_CERTIFICATE_PASSWORD** 
   - Password za certificate (.p12) datoteku
   - Vjerojavno isto kao password koji se koristi za signing

3. **IOS_PROVISIONING_PROFILE_BASE64**
   - Base64 encoded sadržaj provisioning profile datoteke (.mobileprovision)
   - Komanda za kreiranje: `base64 -i Gavra_013_App_Store_Profile_NEW.mobileprovision -o profile_base64.txt`

### 🛠 Kako postaviti Secrets

1. Idi na GitHub repozitorij → **Settings**
2. U lijevom meniju klikni **Secrets and variables** → **Actions**
3. Klikni **New repository secret**
4. Dodaj svaki od 3 secrets-a iz liste gore

## 🏗 Build Process

### Automatski Build
- iOS build se pokreće automatski na push ili PR prema `main` branch-u
- Build uključuje: analyze → test → build → upload to TestFlight

### Manualni Build  
```bash
# Pokretanje iOS build-a lokalno (ako imaš Mac)
cd ios
flutter clean
flutter pub get
cd ios
pod install
bundle exec fastlane build_cloud
```

## 📱 Što je riješeno

### ✅ Bundle ID Problem (KLJUČNO!)
- **Prije**: Xcode koristio `com.gavra013.gavraAndroid`, Firebase `com.gavra.gavra013`
- **Sada**: Svi konfiguriraju koriste `com.gavra013.gavraAndroid`
- **Datoteke ažurirane**: 
  - `ios/Runner/GoogleService-Info.plist` (novi Firebase iOS app)
  - `lib/firebase_options.dart` (novi appId i bundleId)

### ✅ Cloud-Only Build
- Uklonjena lokalna certifikate i provisioning profiles
- `.gitignore` ažuriran da blokira lokalne iOS datoteke
- Fastlane konfiguriran za rad sa environment varijablama

### ✅ Firebase Dependencies  
- **Prije**: firebase_core: ^2.24.2, firebase_messaging: ^14.7.10
- **Sada**: firebase_core: ^3.8.0, firebase_messaging: ^15.1.5

### ✅ Kompletna Automatizacija
- GitHub Actions workflow za iOS build
- Fastlane sa cloud build logikom
- TestFlight upload sa App Store Connect API

## 🔍 Sljedeći Koraci

1. **Set GitHub Secrets** (obavezno prije prvog build-a)
2. **Push code** na main branch → automatski iOS build
3. **Provjeri TestFlight** za novu verziju aplikacije

## 📞 Podrška

Sve je sada konfigurirano i trebao bi iOS build raditi preko GitHub Actions!

**Firebase bundle ID mismatch problem = RIJEŠEN** 🎉

---
*Generisano: Gavra Android - iOS Cloud Build Setup*
