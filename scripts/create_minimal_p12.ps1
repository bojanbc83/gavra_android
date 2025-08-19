# Kreiranje novog P12 fajla iz KEY i CER fajlova
Write-Host "Kreiram novi P12..." -ForegroundColor Green

# Read certificate
$certBytes = [System.IO.File]::ReadAllBytes("ios_distribution.cer")
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)

# Read private key
$keyContent = Get-Content "apple_ios_distribution.key" -Raw

# Try to create new P12 with different approach
$newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$newCert.Import("ios_distribution.cer")

Write-Host "Certificate loaded: $($cert.Subject)" -ForegroundColor Yellow

# Create minimal P12 for testing
$collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$collection.Add($cert)

# Export as P12 with empty password
$pfxBytes = $collection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, "")
[System.IO.File]::WriteAllBytes("ios_new_empty_password.p12", $pfxBytes)

if (Test-Path "ios_new_empty_password.p12") {
    Write-Host "✅ Kreiran novi P12: ios_new_empty_password.p12" -ForegroundColor Green
    
    # Create base64
    $base64 = [System.Convert]::ToBase64String($pfxBytes)
    $base64 | Out-File "ios_new_base64.txt" -Encoding ASCII
    
    Write-Host "✅ Kreiran base64 fajl" -ForegroundColor Green
    Write-Host "Veličina: $($pfxBytes.Length) bytes" -ForegroundColor Cyan
} else {
    Write-Host "❌ Greška" -ForegroundColor Red
}
