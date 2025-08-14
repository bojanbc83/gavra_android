# 🍎 TestFlight Deploy PowerShell Script za Gavra Bus
# ===================================================

param(
    [string]$Environment = "production",
    [string]$BuildType = "release",
    [switch]$SkipTests = $false,
    [switch]$Help = $false
)

# Show help
if ($Help) {
    Write-Host "🍎 Gavra Bus TestFlight Deploy Script" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Deploy-TestFlight.ps1 [-Environment <env>] [-BuildType <type>] [-SkipTests]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Environment  : development, staging, production (default: production)" -ForegroundColor White
    Write-Host "  -BuildType    : debug, release (default: release)" -ForegroundColor White
    Write-Host "  -SkipTests    : Skip running tests before build" -ForegroundColor White
    Write-Host "  -Help         : Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Deploy-TestFlight.ps1" -ForegroundColor Green
    Write-Host "  .\scripts\Deploy-TestFlight.ps1 -Environment staging" -ForegroundColor Green
    Write-Host "  .\scripts\Deploy-TestFlight.ps1 -Environment development -BuildType debug -SkipTests" -ForegroundColor Green
    exit 0
}

# Set error action
$ErrorActionPreference = "Stop"

Write-Host "🚀 Gavra Bus TestFlight Deploy Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Build Type: $BuildType" -ForegroundColor Yellow
Write-Host ""

# Check requirements
function Test-Requirements {
    Write-Host "📋 Checking requirements..." -ForegroundColor Blue
    
    # Check Flutter
    try {
        $flutterVersion = flutter --version 2>$null
        Write-Host "✅ Flutter found" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Flutter not found! Please install Flutter and add to PATH." -ForegroundColor Red
        exit 1
    }
    
    # Check for macOS (required for iOS builds)
    if ($env:OS -eq "Windows_NT") {
        Write-Host "⚠️  iOS builds require macOS. This script prepares the project for building on macOS." -ForegroundColor Yellow
    }
    
    # Check required files
    $requiredFiles = @(
        "ios\ExportOptionsTestFlight.plist",
        "ios\Runner.xcworkspace",
        "pubspec.yaml"
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "✅ Found $file" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Missing $file" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "✅ All requirements satisfied" -ForegroundColor Green
}

# Setup environment variables
function Set-BuildEnvironment {
    Write-Host "🔧 Setting up $Environment environment..." -ForegroundColor Blue
    
    switch ($Environment.ToLower()) {
        "development" {
            $env:FLUTTER_ENV = "development"
            $env:BUILD_SUFFIX = "-dev"
            Write-Host "🔧 Development environment configured" -ForegroundColor Green
        }
        "staging" {
            $env:FLUTTER_ENV = "staging"
            $env:BUILD_SUFFIX = "-staging"
            Write-Host "🧪 Staging environment configured" -ForegroundColor Green
        }
        "production" {
            $env:FLUTTER_ENV = "production"
            $env:BUILD_SUFFIX = ""
            Write-Host "🚀 Production environment configured" -ForegroundColor Green
        }
        default {
            Write-Host "❌ Unknown environment: $Environment" -ForegroundColor Red
            Write-Host "Available: development, staging, production" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Run tests
function Invoke-Tests {
    if ($SkipTests) {
        Write-Host "⏭️  Skipping tests..." -ForegroundColor Yellow
        return
    }
    
    Write-Host "🧪 Running tests..." -ForegroundColor Blue
    
    try {
        flutter test
        Write-Host "✅ All tests passed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Tests failed! Use -SkipTests to bypass." -ForegroundColor Red
        exit 1
    }
}

# Clean and prepare
function Initialize-Build {
    Write-Host "🧹 Cleaning and preparing..." -ForegroundColor Blue
    
    # Flutter clean
    flutter clean
    flutter pub get
    
    # Clean iOS build directory
    if (Test-Path "ios\build") {
        Remove-Item -Recurse -Force "ios\build"
    }
    
    Write-Host "✅ Project cleaned and dependencies updated" -ForegroundColor Green
}

# Build Flutter app
function Build-FlutterApp {
    Write-Host "📱 Building Flutter iOS app..." -ForegroundColor Blue
    
    $buildName = "1.0.$([DateTimeOffset]::Now.ToString('yyyyMMddHHmm'))"
    $buildNumber = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    
    $buildArgs = @(
        "build", "ios",
        "--build-name=$buildName$env:BUILD_SUFFIX",
        "--build-number=$buildNumber",
        "--dart-define=ENVIRONMENT=$env:FLUTTER_ENV"
    )
    
    if ($BuildType -eq "debug") {
        $buildArgs += "--debug"
    }
    else {
        $buildArgs += "--release"
    }
    
    try {
        & flutter $buildArgs
        Write-Host "✅ Flutter build completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Flutter build failed!" -ForegroundColor Red
        exit 1
    }
}

# Generate deployment instructions
function Write-DeploymentInstructions {
    Write-Host ""
    Write-Host "📋 Next Steps for macOS/Xcode:" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Transfer this project to a macOS machine" -ForegroundColor Yellow
    Write-Host "2. Open Terminal and navigate to the project directory" -ForegroundColor Yellow
    Write-Host "3. Run the following commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   cd ios" -ForegroundColor Green
    Write-Host "   pod install --repo-update" -ForegroundColor Green
    Write-Host ""
    Write-Host "4. Archive the app:" -ForegroundColor Yellow
    Write-Host "   xcodebuild -workspace Runner.xcworkspace \\" -ForegroundColor Green
    Write-Host "     -scheme Runner \\" -ForegroundColor Green
    Write-Host "     -configuration Release \\" -ForegroundColor Green
    Write-Host "     -destination generic/platform=iOS \\" -ForegroundColor Green
    Write-Host "     -archivePath build/Runner.xcarchive \\" -ForegroundColor Green
    Write-Host "     archive" -ForegroundColor Green
    Write-Host ""
    Write-Host "5. Export IPA:" -ForegroundColor Yellow
    Write-Host "   xcodebuild -exportArchive \\" -ForegroundColor Green
    Write-Host "     -archivePath build/Runner.xcarchive \\" -ForegroundColor Green
    Write-Host "     -exportPath build \\" -ForegroundColor Green
    Write-Host "     -exportOptionsPlist ExportOptionsTestFlight.plist" -ForegroundColor Green
    Write-Host ""
    Write-Host "6. Upload to TestFlight via App Store Connect or altool" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔗 Helpful Links:" -ForegroundColor Cyan
    Write-Host "  App Store Connect: https://appstoreconnect.apple.com" -ForegroundColor Blue
    Write-Host "  TestFlight: https://developer.apple.com/testflight/" -ForegroundColor Blue
}

# Main execution
function Main {
    try {
        Test-Requirements
        Set-BuildEnvironment
        Invoke-Tests
        Initialize-Build
        Build-FlutterApp
        Write-DeploymentInstructions
        
        Write-Host ""
        Write-Host "🎉 Build preparation completed successfully!" -ForegroundColor Green
        Write-Host "Environment: $Environment" -ForegroundColor Yellow
        Write-Host "Build Type: $BuildType" -ForegroundColor Yellow
        Write-Host "Flutter Environment: $env:FLUTTER_ENV" -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Run the main function
Main
