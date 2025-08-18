# Windows + Codemagic iOS Build - Automatsko Signing

## Problem sa Windows-om
Na Windows-u ne možeš kreirati P12 sertifikat, ali možeš koristiti **Codemagic Automatic Signing**.

## Rešenje: Codemagic Automatic Signing

### Potrebni Apple API ključevi

U Codemagic dashboard → Environment variables trebaš:

#### 1. App Store Connect API Key
- **APP_STORE_CONNECT_PRIVATE_KEY**: Apple API private key (8 linija koda)
- **APP_STORE_CONNECT_KEY_IDENTIFIER**: `F4P3BUR78G`
- **APP_STORE_CONNECT_ISSUER_ID**: `d8b50e72-6330-401d-9aef-4ead356405ca`

#### 2. Apple Developer Portal API Key  
- **APPLE_PRIVATE_KEY**: Apple Developer API private key
- **APPLE_KEY_ID**: `L5CZWBQU22`
- **APPLE_ISSUER_ID**: `d8b50e72-6330-401d-9aef-4ead356405ca`

### Kako dobiti Apple API ključeve:

#### App Store Connect API Key:
1. Idi na [App Store Connect](https://appstoreconnect.apple.com)
2. Users and Access → Keys → App Store Connect API
3. Generiši novi ključ sa "Developer" dozvolama
4. Download .p8 fajl
5. Otvori .p8 fajl u text editor-u i kopiraj sadržaj

#### Apple Developer Portal API Key:
1. Idi na [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Certificates, Identifiers & Profiles → Keys
3. Generiši novi ključ sa "Developer Portal" dozvolama
4. Download .p8 fajl
5. Otvori .p8 fajl i kopiraj sadržaj

### Šta Codemagic automatski radi:
1. **Kreira iOS sertifikate** pomoću Apple API
2. **Kreira provisioning profile** za tvoj Bundle ID
3. **Instalsira sve** u keychain
4. **Builduje i sign-uje** aplikaciju

### Prednosti automatskog signing-a:
- ✅ Radi sa Windows-a
- ✅ Automatski obnavlja istekle sertifikate
- ✅ Nema potrebe za manual certificate management
- ✅ Codemagic sve radi umesto tebe

### Test:
1. Dodaj API ključeve u Codemagic Environment Variables
2. Commit i push izmenjeni `codemagic.yaml`
3. Pokreni build

### Važne napomene:
- Team ID mora biti tačan: `6CY9Q44KMQ`
- Bundle ID mora biti tačan: `com.gavra.gavra013`
- App mora postojati u App Store Connect
- Apple Developer account mora imati validnu plaćenu članarinu

## Ako i dalje ne radi...

Možeš da koristiš **GitHub Codespaces** ili **GitPod** (besplatni cloud Mac) da kreijaš P12 sertifikate ako je automatsko signing problematično.
