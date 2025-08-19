# Auto iOS Password Tester
Write-Host "Automatski iOS Password Finder" -ForegroundColor Green

$passwords = @("", "gavra123", "123456", "password", "gavra", "android", "ios")
$p12File = "ios_with_pass.p12"

foreach ($password in $passwords) {
    $passwordText = if ($password -eq "") { "PRAZAN" } else { $password }
    Write-Host "Testiranje lozinke: $passwordText" -ForegroundColor Cyan
    
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($p12File, $password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
        
        Write-Host "USPEH! Tacna lozinka je: $passwordText" -ForegroundColor Green
        Write-Host "Kopirajte ovu lozinku u GitHub secret IOS_CERTIFICATE_PASSWORD: $password"
        exit 0
    }
    catch {
        Write-Host "Pogresna lozinka: $passwordText" -ForegroundColor Red
        continue
    }
}

Write-Host "Nijedna lozinka nije uspesna!" -ForegroundColor Red
