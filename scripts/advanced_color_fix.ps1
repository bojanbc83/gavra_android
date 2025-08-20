# Advanced fix for ALL Color.withValues patterns in Flutter 3.24.3

$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Pattern 1: .withValues(alpha: X)
    $content = $content -replace '\.withValues\(\s*alpha:\s*([0-9.]+)\s*\)', '.withOpacity($1)'
    
    # Pattern 2: .withValues(\n    alpha: X)  (multiline)
    $content = $content -replace '\.withValues\(\s*\n\s*alpha:\s*([0-9.]+)\s*\)', '.withOpacity($1)'
    
    # Pattern 3: Complex withValues patterns - replace whole block
    $content = $content -replace '\.withValues\([^)]*alpha:\s*([0-9.]+)[^)]*\)', '.withOpacity($1)'
    
    if ($content -ne $originalContent) {
        Set-Content $file.FullName $content
        Write-Host "✅ Advanced fix applied to: $($file.Name)"
    }
}

Write-Host "🎯 Advanced Color.withValues -> Color.withOpacity fix completed!"
