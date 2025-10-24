# 🔥 GAVRA 013 - MANUAL SUPABASE EXPORT SCRIPT (POWERSHELL)
# 
# Ručni export Supabase podataka pomoću PowerShell
# Pokreći sa: .\manual_supabase_export.ps1

# ⚠️ DODAJ PRAVI SUPABASE ANON KEY OVDE!
$SUPABASE_URL = "https://gjtabtwudbrmfeyjiicu.supabase.co"
$SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY_HERE"

# Kreiraj backup direktorij
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_DIR = "backup/manual_export_$timestamp"
New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null

Write-Host "🔥 GAVRA 013 - MANUAL SUPABASE EXPORT" -ForegroundColor Red
Write-Host "📁 Backup direktorij: $BACKUP_DIR" -ForegroundColor Cyan
Write-Host ""

# Lista tabela za export
$TABLES = @("vozaci", "mesecni_putnici", "dnevni_putnici", "putovanja_istorija", "adrese", "vozila", "gps_lokacije", "rute")

# Prepare headers
$headers = @{
    "apikey"        = $SUPABASE_ANON_KEY
    "Authorization" = "Bearer $SUPABASE_ANON_KEY"
    "Content-Type"  = "application/json"
}

# Export svake tabele
foreach ($TABLE in $TABLES) {
    Write-Host "📤 Exportujem tabelu: $TABLE..." -ForegroundColor Yellow
    
    try {
        $url = "$SUPABASE_URL/rest/v1/$TABLE" + "?select=*"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        
        # Wrap u format koji odgovara dart skriptu
        $wrappedData = @{
            table         = $TABLE
            exported_at   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            total_records = $response.Count
            data          = $response
        }
        
        $outputPath = "$BACKUP_DIR/$TABLE.json"
        $wrappedData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
        
        Write-Host "✅ $TABLE exportovan: $($response.Count) zapisa" -ForegroundColor Green
        
    }
    catch {
        Write-Host "❌ Greška pri exportu tabele $TABLE : $_" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 500  # Kratka pauza između zahteva
}

Write-Host ""
Write-Host "🎉 EXPORT ZAVRŠEN!" -ForegroundColor Green
Write-Host "📁 Backup lokacija: $BACKUP_DIR" -ForegroundColor Cyan

# Kreiraj summary
$summary = @{
    export_completed_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    backup_directory    = $BACKUP_DIR
    supabase_url        = $SUPABASE_URL
    tables_exported     = $TABLES
    total_files         = $TABLES.Count + 1  # +1 for summary itself
}

$summaryPath = "$BACKUP_DIR/export_summary.json"
$summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "📊 Export summary kreiran u: $summaryPath" -ForegroundColor Cyan

# Instrukcije za sledeći korak
Write-Host ""
Write-Host "🔄 SLEDEĆI KORACI:" -ForegroundColor Magenta
Write-Host "1. Pokreni data transformer: dart run lib/scripts/data_transformer.dart" -ForegroundColor White
Write-Host "2. Pokreni Firebase import: dart run lib/scripts/firebase_importer.dart" -ForegroundColor White
Write-Host "3. Pokreni testove: flutter test test/firebase_migration_test.dart" -ForegroundColor White