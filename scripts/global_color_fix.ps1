# Global fix for Color.withValues to Color.withOpacity for Flutter 3.24.3 compatibility

$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Replace all withValues(alpha: X) with withOpacity(X)
    $content = $content -replace '\.withValues\(alpha:\s*([0-9.]+)\)', '.withOpacity($1)'
    
    if ($content -ne $originalContent) {
        Set-Content $file.FullName $content
        Write-Host "✅ Fixed withValues in: $($file.Name)"
    }
}

Write-Host "🎯 Global Color.withValues -> Color.withOpacity fix completed!"
