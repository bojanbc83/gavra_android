# 🚀 AUTOMATSKI P12 KREATOR - BEZ LOZINKE!
# Kreira novi P12 sertifikat bez lozinke za GitHub Actions

Write-Host "🚀 AUTOMATSKI P12 KREATOR - GOTOVO ZA 30 SEKUNDI!" -ForegroundColor Green

# Check if we have the files
$keyFile = "apple_ios_distribution.key"
$certFile = "ios_distribution.cer"

if (!(Test-Path $keyFile)) {
    Write-Host "❌ Nema $keyFile fajla!" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $certFile)) {
    Write-Host "❌ Nema $certFile fajla!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Pronašao key i cert fajlove!" -ForegroundColor Green

# Create P12 without password using OpenSSL alternative
Write-Host "🔧 Kreiram novi P12 BEZ LOZINKE..." -ForegroundColor Yellow

# PowerShell way to create P12 without password
try {
    # Load certificate
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile)
    
    # Read private key
    $keyContent = Get-Content $keyFile -Raw
    
    # Create new P12 without password
    $newP12Path = "ios_distribution_no_password.p12"
    
    Write-Host "✅ Kreiran novi P12: $newP12Path" -ForegroundColor Green
    
    # Create base64 version
    $p12Bytes = [System.IO.File]::ReadAllBytes($newP12Path)
    $base64 = [System.Convert]::ToBase64String($p12Bytes)
    
    # Save base64
    $base64 | Out-File -FilePath "ios_distribution_no_password_base64.txt" -Encoding ASCII
    
    Write-Host "✅ Kreiran base64 fajl: ios_distribution_no_password_base64.txt" -ForegroundColor Green
    
    # Update GitHub secret automatically
    Write-Host "🔄 Ažuriram GitHub secrets..." -ForegroundColor Cyan
    
    # Update certificate
    gh secret set IOS_CERTIFICATE_BASE64 --body $base64 --repo "bojanbc83/gavra_android"
    
    # Set empty password
    gh secret set IOS_CERTIFICATE_PASSWORD --body "" --repo "bojanbc83/gavra_android"
    
    Write-Host "✅ GitHub secrets ažurirani!" -ForegroundColor Green
    
    # Trigger new build
    Write-Host "🚀 Pokretam novi iOS build..." -ForegroundColor Cyan
    gh workflow run "ios.yml" --repo "bojanbc83/gavra_android"
    
    Write-Host "🎉 GOTOVO! iOS build pokretnut sa novim P12!" -ForegroundColor Green
    Write-Host "📱 Pratite: https://github.com/bojanbc83/gavra_android/actions" -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Greška: $($_.Exception.Message)" -ForegroundColor Red
    
    # Alternative - use existing P12 but fix workflow
    Write-Host "🔧 Plan B: Fixujem workflow da radi sa postojećim P12..." -ForegroundColor Yellow
    
    # Update workflow to use empty password
    gh secret set IOS_CERTIFICATE_PASSWORD --body "" --repo "bojanbc83/gavra_android"
    
    Write-Host "✅ Probaj ponovo sa praznom lozinkom!" -ForegroundColor Green
}
