#!/bin/bash

# Script to create environment variables for Codemagic iOS signing

echo "Creating environment variables for Codemagic..."

# Check if files exist
if [ ! -f "ios_distribution.cer" ]; then
    echo "❌ ios_distribution.cer not found!"
    echo "Download your iOS Distribution certificate from Apple Developer Portal"
    exit 1
fi

if [ ! -f "Gavra_013_App_Store_Profile_NEW.mobileprovision" ]; then
    echo "❌ Provisioning profile not found!"
    echo "Download your App Store provisioning profile from Apple Developer Portal"
    exit 1
fi

echo "✅ Files found, creating base64 encoded values..."

# Create certificate base64 (you need to convert .cer to .p12 first)
echo "CERTIFICATE (you need to export as .p12 from Keychain Access):"
echo "1. Open Keychain Access"
echo "2. Find your iOS Distribution certificate"
echo "3. Right-click -> Export -> .p12 format"
echo "4. Set a password and run: base64 -i your_cert.p12"
echo ""

# Create provisioning profile base64
echo "PROVISIONING_PROFILE:"
base64 -i Gavra_013_App_Store_Profile_NEW.mobileprovision
echo ""

echo "CERTIFICATE_PRIVATE_KEY:"
echo "Enter the password you used when exporting the .p12 certificate"
echo ""

echo "Add these values to Codemagic Environment Variables:"
echo "1. Go to Codemagic dashboard"
echo "2. Select your app"
echo "3. Go to Settings > Environment variables"
echo "4. Add CERTIFICATE, CERTIFICATE_PRIVATE_KEY, and PROVISIONING_PROFILE"
echo "5. Mark them as secure/encrypted"
