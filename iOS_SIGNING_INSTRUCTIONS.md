# iOS Codemagic Signing Issues - Rešenje

## Problem
```
Error (Xcode): No Accounts: Add a new account in Accounts settings.
Error (Xcode): No profiles for 'com.gavra.gavra013' were found
```

## Razlozi
1. **Nedostaju iOS signing credentials** u Codemagic environment variables
2. **Provisioning profile** nije pravilno konfigurisan
3. **Manual signing** nije kompletno podešen

## Rešenje

### Korak 1: Kreiranje P12 sertifikata
1. Otvori **Keychain Access** na Mac-u
2. Pronađi **iOS Distribution** sertifikat za team `6CY9Q44KMQ`
3. Right-click → **Export** → Odaberi **.p12** format
4. Postavi password (zapamti ga!)
5. Sačuvaj kao `ios_distribution.p12`

### Korak 2: Kreiranje base64 vrednosti
```bash
# Za P12 sertifikat
base64 -i ios_distribution.p12 > certificate_base64.txt

# Za provisioning profile (već kreiran)
# Koristi postojeći fajl: provisioning_profile_base64_LATEST.txt
```

### Korak 3: Dodavanje Environment Variables u Codemagic
Idi na **Codemagic Dashboard → App Settings → Environment variables** i dodaj:

1. **CERTIFICATE**
   - Value: Sadržaj `certificate_base64.txt` fajla
   - Secure: ✅ Checked

2. **CERTIFICATE_PRIVATE_KEY**
   - Value: Password koji si koristio za P12 export
   - Secure: ✅ Checked

3. **PROVISIONING_PROFILE**
   - Value: Sadržaj `provisioning_profile_base64_LATEST.txt` fajla
   - Secure: ✅ Checked

### Korak 4: Verifikacija Bundle ID i Team ID
Proveri da li su sledeći podaci tačni u Apple Developer Portal:

- **App ID**: `com.gavra.gavra013`
- **Team ID**: `6CY9Q44KMQ`
- **Provisioning Profile**: App Store profile za `com.gavra.gavra013`

### Korak 5: Test Build
1. Commit i push izmene u `codemagic.yaml`
2. Pokreni novi build u Codemagic
3. Proveri logove za potvrdu da su credentials učitani

## Dodatne provere

### Provisioning Profile validacija
```bash
# Proveri da li provisioning profile sadrži tačan Bundle ID
security cms -D -i Gavra_013_App_Store_Profile_NEW.mobileprovision | grep -A5 "application-identifier"
```

### Sertifikat validacija
```bash
# Proveri da li sertifikat odgovara Team ID
openssl x509 -inform DER -in ios_distribution.cer -text | grep "Subject:"
```

## Česti problemi

1. **Pogrešan Team ID** - Proveri da li je `6CY9Q44KMQ` tačan u Apple Developer Portal
2. **Istekao provisioning profile** - Kreiraj novi App Store profile
3. **Pogrešan Bundle ID** - Mora biti tačno `com.gavra.gavra013`
4. **Nedostaje Development certificate** - Možda treba i Development profile za testing

## Kontakt za dodatnu pomoć
Ako problem i dalje postoji, pošalji:
1. Screenshot Apple Developer Portal provisioning profiles
2. Codemagic build log (deo sa signing errors)
3. Screenshot Team ID u Apple Developer Portal
