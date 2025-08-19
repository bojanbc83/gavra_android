# 🔐 Automatski iOS Password Finder & GitHub Secret Updater
# Testira različite lozinke za P12 i automatski ažurira GitHub secret

Write-Host "🚀 Automatski iOS Password Finder" -ForegroundColor Green

# Moguće lozinke za testiranje
$passwords = @(
    "",
    "gavra123",
    "123456", 
    "password",
    "gavra",
    "android",
    "ios",
    "apple",
    "distribution"
)

$p12File = "ios_with_pass.p12"
$repoOwner = "bojanbc83"
$repoName = "gavra_android"

Write-Host "📋 Testiranje P12 fajla: $p12File" -ForegroundColor Yellow

# GitHub CLI check
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI nije instaliran!" -ForegroundColor Red
    Write-Host "💡 Instaliraje: winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

# Test GitHub auth
Write-Host "🔑 Proverava GitHub autentifikaciju..." -ForegroundColor Cyan
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Niste ulogovani u GitHub CLI!" -ForegroundColor Red
    Write-Host "💡 Pokrenite: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI je spreman!" -ForegroundColor Green

# Testiranje lozinki sa PowerShell PKCS12 check
foreach ($password in $passwords) {
    $passwordText = if ($password -eq "") { "PRAZAN" } else { $password }
    Write-Host "🔍 Testiranje lozinke: $passwordText" -ForegroundColor Cyan
    
    try {
        # PowerShell način testiranja P12 fajla
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($p12File, $password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
        
        Write-Host "🎉 USPEH! Tačna lozinka je: $passwordText" -ForegroundColor Green
        
        # Automatski ažuriranje GitHub secret
        Write-Host "🔄 Ažuriranje GitHub secret..." -ForegroundColor Yellow
        
        $secretValue = if ($password -eq "") { '""' } else { $password }
        $result = gh secret set IOS_CERTIFICATE_PASSWORD --body $password --repo "$repoOwner/$repoName"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitHub secret uspešno ažuriran!" -ForegroundColor Green
            Write-Host "🚀 Pokretanje novog build-a..." -ForegroundColor Cyan
            
            # Automatski pokretanje workflow-a
            gh workflow run "ios.yml" --repo "$repoOwner/$repoName"
            
            Write-Host "🎯 Build pokretnut! Proverite: https://github.com/$repoOwner/$repoName/actions" -ForegroundColor Green
        } else {
            Write-Host "❌ Greška pri ažuriranju secret-a" -ForegroundColor Red
        }
        
        exit 0
    }
    catch {
        Write-Host "❌ Pogrešna lozinka: $passwordText" -ForegroundColor Red
        continue
    }
}

Write-Host "Nijedna lozinka nije uspesna!" -ForegroundColor Red
Write-Host "Mozda treba novi P12 sertifikat?" -ForegroundColor Yellow
