# Kreiranje P12 sertifikata na GitHub Codespaces

## Korak 1: Kreiraj GitHub Codespace
1. Idi na https://github.com/codespaces
2. Kreiraj novi Codespace (besplatan za 60 sati mesečno)
3. Odaberi "Blank" template

## Korak 2: Upload fajlove u Codespace
Upload ove fajlove u Codespace:
- ios_distribution.cer
- apple_ios_distribution.key (private key)

## Korak 3: Kreiraj P12 sertifikat
```bash
# Install OpenSSL (obično je već instaliran)
sudo apt-get update && sudo apt-get install openssl

# Kreiraj P12 sertifikat
openssl pkcs12 -export \
  -out ios_distribution.p12 \
  -inkey apple_ios_distribution.key \
  -in ios_distribution.cer \
  -password pass:YourPasswordHere

# Kreiraj base64
base64 -i ios_distribution.p12 > ios_distribution_p12_base64.txt
```

## Korak 4: Download rezultat
Download `ios_distribution_p12_base64.txt` fajl na Windows

## Korak 5: Dodaj u Codemagic
Kopiraj sadržaj u `CM_CERTIFICATE` environment variable
