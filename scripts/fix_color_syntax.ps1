# Quick fix for Color.withValues to Color.withOpacity for Flutter 3.24.3 compatibility

$filePath = "C:\Users\gavri\StudioProjects\gavra_android\lib\screens\welcome_screen.dart"
$content = Get-Content $filePath -Raw

# Replace all withValues(alpha: X) with withOpacity(X)
$content = $content -replace '\.withValues\(alpha:\s*([0-9.]+)\)', '.withOpacity($1)'

Set-Content $filePath $content
Write-Host "✅ Fixed Color.withValues -> Color.withOpacity in welcome_screen.dart"
