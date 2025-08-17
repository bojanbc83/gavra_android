# KORAK PO KORAK: Provera Apple Developer Portal-a

## Problem: 108+ neuspešnih build-ova
**Greška**: "No profiles for 'com.gavra013.gavraAndroid' were found" + "0 valid identities found"

---

## KORAK 1: Uloguj se u Apple Developer Portal
1. Idi na: https://developer.apple.com/account/
2. Uloguj se sa Apple ID nalogom koji je vlasnik aplikacije
3. Verifikuj da vidiš Team: **6CY9Q44KMQ**

---

## KORAK 2: Proveri App ID (Bundle Identifier)
1. Idi na: https://developer.apple.com/account/resources/identifiers/list/bundleId
2. **POTRAŽI**: `com.gavra013.gavraAndroid`
3. **PROVERI**:
   - [ ] App ID postoji u listi?
   - [ ] Status je "Active"?
   - [ ] Capabilities su omogućene (Push Notifications, itd.)?
   
**AKO NE POSTOJI**: 
- Klikni na "+" da kreiraš novi App ID
- Description: "Gavra Bus"
- Bundle ID: `com.gavra013.gavraAndroid`
- Omogući potrebne capabilities

---

## KORAK 3: Proveri Certificate (Sertifikat)
1. Idi na: https://developer.apple.com/account/resources/certificates/list
2. **POTRAŽI**: "Gavra Bus Distribution" ili bilo koji "iOS Distribution" sertifikat
3. **PROVERI**:
   - [ ] Sertifikat postoji?
   - [ ] Status je "Active" (NIJE "Expired" ili "Revoked")?
   - [ ] Type je "iOS Distribution"?
   - [ ] Vezan je za Team ID: 6CY9Q44KMQ?

**AKO JE EXPIRED ili NE POSTOJI**:
- Klikni na "+" da kreiraš novi
- Tip: "iOS Distribution"
- Upload CSR file (možeš kreirati novi u Keychain Access)

---

## KORAK 4: Proveri Provisioning Profile
1. Idi na: https://developer.apple.com/account/resources/profiles/list
2. **POTRAŽI**: "Gavra 013 App Store Profile" ili bilo koji App Store profil za tvoju aplikaciju
3. **PROVERI**:
   - [ ] Profil postoji?
   - [ ] Status je "Active"?
   - [ ] Type je "App Store"?
   - [ ] App ID je: `com.gavra013.gavraAndroid`?
   - [ ] Certificate je povezan sa "Gavra Bus Distribution"?

**AKO NE POSTOJI ili JE INVALID**:
- Klikni na "+" da kreiraš novi
- Type: "App Store"
- App ID: `com.gavra013.gavraAndroid`
- Certificate: Izaberi "Gavra Bus Distribution"
- Devices: Ne treba za App Store
- Profile Name: "Gavra 013 App Store Profile NEW"

---

## KORAK 5: Proveri Team Membership
1. Idi na: https://developer.apple.com/account/#!/membership/
2. **PROVERI**:
   - [ ] Team ID je tačno: **6CY9Q44KMQ**?
   - [ ] Tvoja uloga je "Admin" ili "App Manager"?
   - [ ] Apple Developer Program je aktivan?
   - [ ] Nema pending zahteva ili problema?

---

## KORAK 6: Download Fresh Files (ako si našao probleme)

### Ako si kreirao novi Certificate:
```bash
# Download iz Apple Developer Portal → Certificates
# Zameni fajl: ios_distribution.cer
```

### Ako si kreirao novi Provisioning Profile:
```bash
# Download iz Apple Developer Portal → Profiles  
# Zameni fajl: Gavra_013_App_Store_Profile_NEW.mobileprovision
```

---

## KORAK 7: Commit i Push (ako si downloadovao nove fajlove)
```bash
git add .
git commit -m "APPLE PORTAL FIX: Updated certificate and/or provisioning profile - Build #109"
git push origin main
```

---

## NAJČEŠĆI PROBLEMI:

### Problem 1: App ID ne postoji
**Rešenje**: Kreiraj novi App ID sa Bundle ID: `com.gavra013.gavraAndroid`

### Problem 2: Certificate je expired
**Rešenje**: Kreiraj novi iOS Distribution certificate

### Problem 3: Provisioning Profile nije povezan
**Rešenje**: Kreiraj novi App Store provisioning profile koji povezuje App ID + Certificate

### Problem 4: Team ID se promenio
**Rešenje**: Proveri da li je Team ID stvarno `6CY9Q44KMQ`

---

## NAKON PROVERE - Očekivani rezultat:

✅ **App ID**: `com.gavra013.gavraAndroid` - Active  
✅ **Certificate**: "iOS Distribution" - Active  
✅ **Profile**: "App Store" profil koji povezuje App ID + Certificate  
✅ **Team**: 6CY9Q44KMQ - Active membership  

**Kada sve ovo bude OK → Build #109 će uspeti!**

---

## NAPOMENE:
- Proveravaj **svaki korak** pažljivo
- Ako nešto ne postoji ili je expired - KREIRAJ NOVO
- Apple Developer Portal je jedini izvor istine za signing
- Sve Codemagic konfiguracije su ispravne - problem je u Portal-u!
