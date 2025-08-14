#!/bin/bash

# 🍎 TestFlight Deploy Script za Gavra Bus
# Koristiti ovaj skript za manuelni upload na TestFlight

set -e

echo "🚀 Gavra Bus TestFlight Deploy Script"
echo "======================================"

# Proverava da li su potrebni fajlovi prisutni
check_requirements() {
    echo "📋 Checking requirements..."
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Xcode not found! Please install Xcode."
        exit 1
    fi
    
    # Check for Flutter
    if ! command -v flutter &> /dev/null; then
        echo "❌ Flutter not found! Please install Flutter."
        exit 1
    fi
    
    # Check for provisioning profile
    if [ ! -f "Gavra_013_App_Store_Profile.mobileprovision" ]; then
        echo "❌ Provisioning profile not found!"
        echo "Please ensure Gavra_013_App_Store_Profile.mobileprovision is in the project root."
        exit 1
    fi
    
    # Check for distribution certificate
    if [ ! -f "ios_distribution.cer" ]; then
        echo "❌ Distribution certificate not found!"
        echo "Please ensure ios_distribution.cer is in the project root."
        exit 1
    fi
    
    echo "✅ All requirements satisfied"
}

# Instaliraj provisioning profile i certificate
install_certificates() {
    echo "🔐 Installing certificates and provisioning profiles..."
    
    # Install distribution certificate
    security import ios_distribution.cer -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
    
    # Install provisioning profile
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
    cp Gavra_013_App_Store_Profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
    
    echo "✅ Certificates and profiles installed"
}

# Build Flutter aplikaciju
build_flutter_app() {
    echo "📱 Building Flutter iOS app..."
    
    # Clean and get dependencies
    flutter clean
    flutter pub get
    
    # Build iOS release
    flutter build ios --release \
        --build-name=1.0.$BUILD_NUMBER \
        --build-number=${BUILD_NUMBER:-$(date +%s)} \
        --verbose
        
    echo "✅ Flutter iOS build completed"
}

# Archive iOS aplikaciju
archive_ios_app() {
    echo "📦 Archiving iOS app..."
    
    cd ios
    
    # Clean previous builds
    rm -rf build/Runner.xcarchive
    
    # Create archive
    xcodebuild -workspace Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -destination generic/platform=iOS \
        -archivePath build/Runner.xcarchive \
        archive \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM=6CY9Q44KMQ \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        PROVISIONING_PROFILE_SPECIFIER="Gavra_013_App_Store_Profile"
        
    cd ..
    echo "✅ iOS app archived successfully"
}

# Export IPA za TestFlight
export_ipa() {
    echo "📤 Exporting IPA for TestFlight..."
    
    cd ios
    
    # Export IPA
    xcodebuild -exportArchive \
        -archivePath build/Runner.xcarchive \
        -exportPath build \
        -exportOptionsPlist ExportOptionsTestFlight.plist \
        -verbose
        
    # Verify IPA
    if [ -f build/Runner.ipa ]; then
        echo "✅ IPA exported successfully: ios/build/Runner.ipa"
        ls -la build/Runner.ipa
    else
        echo "❌ IPA export failed!"
        exit 1
    fi
    
    cd ..
}

# Upload na TestFlight (zahteva App Store Connect API key)
upload_to_testflight() {
    echo "🚀 Uploading to TestFlight..."
    
    if command -v xcrun altool &> /dev/null; then
        xcrun altool --upload-app \
            --type ios \
            --file ios/build/Runner.ipa \
            --primary-bundle-id com.gavra.gavra013 \
            --apiKey F4P38UR78G \
            --apiIssuer d8b50e72-6330-401d-9aef-4ead356405ca
        
        echo "✅ Upload to TestFlight completed!"
        echo "🎉 Check App Store Connect for processing status."
    else
        echo "⚠️  altool not available. Please upload ios/build/Runner.ipa manually to App Store Connect."
        echo "📱 IPA location: $(pwd)/ios/build/Runner.ipa"
    fi
}

# Main execution
main() {
    echo "Starting TestFlight deployment..."
    
    check_requirements
    install_certificates
    build_flutter_app
    archive_ios_app
    export_ipa
    upload_to_testflight
    
    echo ""
    echo "🎉 TestFlight deployment completed!"
    echo "📱 Check App Store Connect for build processing."
    echo "🧪 Once processed, you can distribute to beta testers."
}

# Run script
main "$@"
