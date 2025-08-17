#!/bin/bash

echo "🍎 GAVRA iOS BUILD SCRIPT"
echo "========================="

# Set working directory to project root
cd "$(dirname "$0")/.."

echo "📱 Starting iOS build process..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/ephemeral
rm -rf ios/build

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Navigate to iOS directory
cd ios

# Install/update CocoaPods dependencies
echo "🏗️ Installing iOS dependencies (CocoaPods)..."
pod repo update
pod install --repo-update

# Return to project root
cd ..

echo "✅ Build preparation completed!"
echo ""
echo "🚀 NEXT STEPS FOR macOS:"
echo "1. Otvori ios/Runner.xcworkspace u Xcode (NE .xcodeproj!)"
echo "2. Selectuj svoj Apple Developer Team"
echo "3. Proveri da li je Bundle ID: com.gavra013.gavraAndroid"
echo "4. Selectuj iOS device ili simulator"
echo "5. Klikni Product > Build ili ⌘+B"
echo ""
echo "📋 PROVISIONING PROFILES:"
echo "- Imaš provisioning profiles u root direktoriju"
echo "- ExportOptionsTestFlight.plist je konfigurisan za TestFlight"
echo ""
echo "🔥 Za TestFlight upload koristi:"
echo "./scripts/deploy_testflight.sh"
