# 🚀 AUTOMATSKI P12 KREATOR - REŠAVA SVE!
# Kreira novi P12 iz .key i .cer fajlova BEZ LOZINKE

Write-Host "🔥 KREIRAM NOVI P12 AUTOMATSKI!" -ForegroundColor Green

# Install OpenSSL if not available
if (!(Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "📥 Instaliram OpenSSL..." -ForegroundColor Yellow
    winget install OpenSSL.OpenSSL
}

# Convert .cer to .pem
Write-Host "🔧 Konvertujem .cer u .pem..." -ForegroundColor Cyan
& openssl x509 -inform DER -in "ios_distribution.cer" -out "ios_distribution.pem"

# Create new P12 without password
Write-Host "🔨 Kreiram novi P12 BEZ LOZINKE..." -ForegroundColor Yellow
& openssl pkcs12 -export -inkey "apple_ios_distribution.key" -in "ios_distribution.pem" -out "ios_distribution_NEW.p12" -passout pass:

if (Test-Path "ios_distribution_NEW.p12") {
    Write-Host "✅ USPEH! Kreiran novi P12!" -ForegroundColor Green
    
    # Create base64
    $newP12Bytes = [System.IO.File]::ReadAllBytes("ios_distribution_NEW.p12")
    $newBase64 = [System.Convert]::ToBase64String($newP12Bytes)
    
    # Update GitHub secrets
    Write-Host "🔄 Ažuriram GitHub secrets..." -ForegroundColor Cyan
    
    & gh secret set IOS_CERTIFICATE_BASE64 --body $newBase64 --repo "bojanbc83/gavra_android"
    & gh secret set IOS_CERTIFICATE_PASSWORD --body '""' --repo "bojanbc83/gavra_android"
    
    Write-Host "🚀 Pokretam novi build..." -ForegroundColor Green
    & gh workflow run "ios.yml" --repo "bojanbc83/gavra_android"
    
    Write-Host "🎉 GOTOVO! Novi P12 kreiran i build pokretnut!" -ForegroundColor Green
} else {
    Write-Host "❌ Greška pri kreiranju P12" -ForegroundColor Red
}
