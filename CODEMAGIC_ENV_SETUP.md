# ✅ CODEMAGIC ENVIRONMENT VARIABLES SETUP

Idi na **Codemagic Dashboard** → Vaša aplikacija → **Settings** → **Environment variables**

## Potrebne Environment Variables:

### 1. 🔐 APPLE_PRIVATE_KEY
- **Name**: `APPLE_PRIVATE_KEY`
- **Value**: Sadržaj Apple Developer Portal .p8 fajla (Gavra Bus API Key)
- **Secure**: ✅ Checked
- **Group**: Može biti `default` ili `ios_signing`

### 2. 🔐 APP_STORE_CONNECT_PRIVATE_KEY  
- **Name**: `APP_STORE_CONNECT_PRIVATE_KEY`
- **Value**: Sadržaj App Store Connect .p8 fajla (Gavra Bus API Key 2)
- **Secure**: ✅ Checked
- **Group**: Može biti `default` ili `ios_signing`

## Format .p8 ključeva:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
...ostatak ključa...
-----END PRIVATE KEY-----
```

## ⚠️ VAŽNO:
- **Uključi sve linije** (uključujući `-----BEGIN PRIVATE KEY-----` i `-----END PRIVATE KEY-----`)
- **Bez dodatnih razmaka** na početku ili kraju
- **Bez quotes** oko vrednosti

## 🧪 Test Environment Variables:

Dodaj i test varijable da proverimo da li sve radi:

### 3. 🔧 FIREBASE_API_KEY (za testiranje)
- **Name**: `FIREBASE_API_KEY`  
- **Value**: `AIzaSyBqRskM83ktbh7cGauSkrzIO4xZsP3schk`
- **Secure**: ✅ Checked

### 4. 🔧 ONESIGNAL_APP_ID (već imate u Android workflow)
- **Name**: `ONESIGNAL_APP_ID`
- **Value**: `4fd57af1-568a-45e0-a737-3b3918c4e92a`
- **Secure**: ❌ Unchecked (javni ID)

## 📝 Checklist pre build-a:

- [ ] `APPLE_PRIVATE_KEY` dodat i označen kao Secure
- [ ] `APP_STORE_CONNECT_PRIVATE_KEY` dodat i označen kao Secure  
- [ ] Proveren format .p8 ključeva (sa BEGIN/END linijama)
- [ ] Team ID u Apple Developer Portal je `6CY9Q44KMQ`
- [ ] Bundle ID u App Store Connect je `com.gavra.gavra013`
- [ ] App Store Connect integration je povezana (Gavra Bus API Key 2)

## 🚀 Sledeći koraci:

1. **Dodaj environment variables** u Codemagic
2. **Commit i push** trenutni `codemagic.yaml`  
3. **Pokreni build** i prati logove
4. **Proveri** da li build prolazi bez grešaka

Ako i dalje dobijaš "No Accounts" grešku, to znači da jedan od .p8 ključeva nije valjan ili nije dobro formatiran.
