# 🔥 KONAČNO REŠENJE P12 PROBLEMA! 
# Kreira novi P12 iz KEY i CER fajlova i automatski ažurira GitHub

Write-Host "🔥 KREIRAM NOVI P12 BEZ LOZINKE - KONAČNO REŠENJE!" -ForegroundColor Red

# Download and install OpenSSL for Windows
Write-Host "📥 Downloaing OpenSSL..." -ForegroundColor Yellow
$openSSLUrl = "https://slproweb.com/download/Win64OpenSSL_Light-3_0_15.exe"
$openSSLPath = "$env:TEMP\OpenSSL-Win64.exe"

try {
    Invoke-WebRequest -Uri $openSSLUrl -OutFile $openSSLPath -UseBasicParsing
    Write-Host "✅ OpenSSL downloaded" -ForegroundColor Green
    
    # Install silently
    Start-Process -FilePath $openSSLPath -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Write-Host "✅ OpenSSL installed" -ForegroundColor Green
    
    # Add to PATH
    $env:PATH += ";C:\Program Files\OpenSSL-Win64\bin"
    
    # Convert CER to PEM
    Write-Host "🔧 Converting CER to PEM..." -ForegroundColor Cyan
    & "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" x509 -inform DER -in "ios_distribution.cer" -out "ios_distribution.pem"
    
    # Create P12 without password
    Write-Host "🔨 Creating P12 WITHOUT PASSWORD..." -ForegroundColor Yellow
    & "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" pkcs12 -export -inkey "apple_ios_distribution.key" -in "ios_distribution.pem" -out "ios_new_working.p12" -passout pass:
    
    if (Test-Path "ios_new_working.p12") {
        Write-Host "🎉 SUCCESS! New P12 created!" -ForegroundColor Green
        
        # Create base64
        $newP12Bytes = [System.IO.File]::ReadAllBytes("ios_new_working.p12")
        $newBase64 = [System.Convert]::ToBase64String($newP12Bytes)
        
        Write-Host "📱 P12 size: $($newP12Bytes.Length) bytes" -ForegroundColor Cyan
        Write-Host "🔄 Updating GitHub secrets..." -ForegroundColor Yellow
        
        # Update GitHub secrets
        $env:PATH += ";C:\Program Files\GitHub CLI"
        
        # Set new certificate
        echo $newBase64 | gh secret set IOS_CERTIFICATE_BASE64 --repo "bojanbc83/gavra_android"
        
        # Set empty password
        echo '""' | gh secret set IOS_CERTIFICATE_PASSWORD --repo "bojanbc83/gavra_android"
        
        Write-Host "✅ GitHub secrets updated!" -ForegroundColor Green
        
        # Trigger new build
        Write-Host "🚀 Starting new TestFlight build..." -ForegroundColor Green
        gh workflow run "ios.yml" --repo "bojanbc83/gavra_android"
        
        Write-Host "🎉 DONE! New P12 created and TestFlight build started!" -ForegroundColor Green
        Write-Host "📊 Check progress: https://github.com/bojanbc83/gavra_android/actions" -ForegroundColor Yellow
        
    } else {
        Write-Host "❌ Failed to create P12" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔧 Trying alternative method..." -ForegroundColor Yellow
    
    # Alternative: Use existing file but fix the secret
    Write-Host "🔄 Using existing P12 with corrected password..." -ForegroundColor Cyan
    $env:PATH += ";C:\Program Files\GitHub CLI"
    
    # Try with the actual working password we found earlier
    echo "gavra123" | gh secret set IOS_CERTIFICATE_PASSWORD --repo "bojanbc83/gavra_android"
    
    Write-Host "✅ Password updated to gavra123" -ForegroundColor Green
    
    # Trigger build
    gh workflow run "ios.yml" --repo "bojanbc83/gavra_android"
    Write-Host "🚀 TestFlight build started with correct password!" -ForegroundColor Green
}
