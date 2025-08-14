#!/bin/bash

# 🏗️ iOS Build Script za različite environments
# ==============================================

set -e

ENVIRONMENT=${1:-production}
BUILD_TYPE=${2:-release}

echo "🍎 Building iOS app for $ENVIRONMENT environment ($BUILD_TYPE)"

# Setup environment variables
setup_environment() {
    case $ENVIRONMENT in
        "development"|"dev")
            echo "🔧 Setting up DEVELOPMENT environment"
            export FLUTTER_ENV=development
            export BUILD_SUFFIX="-dev"
            ;;
        "staging"|"stage")
            echo "🧪 Setting up STAGING environment"
            export FLUTTER_ENV=staging
            export BUILD_SUFFIX="-staging"
            ;;
        "production"|"prod")
            echo "🚀 Setting up PRODUCTION environment"
            export FLUTTER_ENV=production
            export BUILD_SUFFIX=""
            ;;
        *)
            echo "❌ Unknown environment: $ENVIRONMENT"
            echo "Available: development, staging, production"
            exit 1
            ;;
    esac
}

# Clean and prepare
prepare_build() {
    echo "🧹 Cleaning previous builds..."
    flutter clean
    flutter pub get
    
    cd ios
    rm -rf build/
    rm -rf Pods/
    pod install --repo-update
    cd ..
}

# Build Flutter app
build_flutter() {
    echo "📱 Building Flutter iOS app..."
    
    local build_name="1.0.${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
    local build_number="${BUILD_NUMBER:-$(date +%s)}"
    
    if [ "$BUILD_TYPE" = "debug" ]; then
        flutter build ios --debug \
            --build-name="$build_name$BUILD_SUFFIX" \
            --build-number="$build_number" \
            --dart-define=ENVIRONMENT=$FLUTTER_ENV
    else
        flutter build ios --release \
            --build-name="$build_name$BUILD_SUFFIX" \
            --build-number="$build_number" \
            --dart-define=ENVIRONMENT=$FLUTTER_ENV
    fi
}

# Main execution
main() {
    setup_environment
    prepare_build
    build_flutter
    
    echo "✅ iOS build completed successfully!"
    echo "Environment: $ENVIRONMENT"
    echo "Build Type: $BUILD_TYPE"
    echo "Flutter Environment: $FLUTTER_ENV"
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <environment> [build_type]"
    echo ""
    echo "Environments:"
    echo "  development|dev    - Development build"
    echo "  staging|stage      - Staging build"
    echo "  production|prod    - Production build"
    echo ""
    echo "Build Types:"
    echo "  debug              - Debug build"
    echo "  release            - Release build (default)"
    echo ""
    echo "Examples:"
    echo "  $0 development debug"
    echo "  $0 staging release"
    echo "  $0 production"
    exit 1
fi

main "$@"
