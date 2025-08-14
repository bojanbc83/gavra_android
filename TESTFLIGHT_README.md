# 🍎 TestFlight Configuration Guide za Gavra Bus
# ================================================

## 📋 Preduslovi

1. **Apple Developer Account** (6CY9Q44KMQ)
2. **App Store Connect pristup**
3. **Xcode instaliran** (najnovija verzija)
4. **Flutter setup** za iOS development

## 🔐 Potrebni fajlovi

- `ios_distribution.cer` - Distribution certificate
- `apple_ios_distribution.key` - Private key za certificate
- `Gavra_013_App_Store_Profile.mobileprovision` - App Store provisioning profile

## 🚀 TestFlight Deployment Opcije

### Opcija 1: Codemagic (Automatski)
```bash
git push origin main  # Pokreće automatski iOS workflow
```

### Opcija 2: Lokalni build (Manuelni)
```bash
chmod +x scripts/deploy_testflight.sh
./scripts/deploy_testflight.sh
```

### Opcija 3: Flutter build + Xcode Archive
```bash
flutter build ios --release
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive
xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build -exportOptionsPlist ExportOptionsTestFlight.plist
```

## 📱 TestFlight Beta Groups

- **Internal Testers** - Gavra tim
- **Gavra Bus Beta** - Eksterni testeri (vozači, putnici)

## 🔧 Build Settings

| Setting | Value |
|---------|--------|
| Bundle ID | com.gavra.gavra013 |
| Team ID | 6CY9Q44KMQ |
| Code Signing | Manual |
| Certificate | Apple Distribution |
| Provisioning Profile | Gavra_013_App_Store_Profile |

## 📊 Build Numbering

- **Version**: 1.0.x (MARKETING_VERSION)
- **Build**: Timestamp ili BUILD_NUMBER (CURRENT_PROJECT_VERSION)

## 🔍 Troubleshooting

### Common Issues:

1. **Code signing error**
   - Proverite da li je certificate instaliran
   - Proverite da li je provisioning profile valjan

2. **Missing GoogleService-Info.plist**
   - Skinite iz Firebase Console
   - Postavite u ios/Runner/

3. **OneSignal configuration missing**
   - Proverite ONESIGNAL_APP_ID u build settings

4. **Location permissions missing**
   - Proverite Info.plist za NSLocation permissions

## 📞 Support

Za pomoć kontaktirajte iOS development tim.

## 🔗 Korisni linkovi

- [App Store Connect](https://appstoreconnect.apple.com)
- [Apple Developer Portal](https://developer.apple.com)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Codemagic Dashboard](https://codemagic.io)
