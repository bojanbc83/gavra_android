# 🍎 iOS Firebase Configuration Guide

## KORACI ZA DODAVANJE FIREBASE U iOS:

### 1. Idite na Firebase Console:
   https://console.firebase.google.com/

### 2. Otvorite svoj postojeći projekat "gavra-android-notifications"

### 3. Kliknite "Add app" i izaberite iOS

### 4. Registrujte iOS app:
   - iOS bundle ID: com.gavra.bus (ili vaš bundle ID)
   - App nickname: Gavra Bus iOS
   - App Store ID: (ostaviti prazno za sada)

### 5. Downloadujte GoogleService-Info.plist

### 6. Dodajte GoogleService-Info.plist u:
   ios/Runner/GoogleService-Info.plist

### 7. Aktivirajte Firebase Cloud Messaging za iOS u Firebase Console

NAPOMENA: Fajl GoogleService-Info.plist MORA biti dodat ručno na MacOS mašini u Xcode!
