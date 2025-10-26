# SERVICE CONSOLIDATION BACKUP SCRIPT
# Creates backup of old redundant services before migration

$BackupDir = "service_consolidation_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $BackupDir -Force

Write-Host "📦 Creating backup of redundant services..." -ForegroundColor Yellow

# GEOCODING SERVICES BACKUP (3 → 1)
Write-Host "🗺️ Backing up geocoding services..." -ForegroundColor Cyan
Copy-Item "lib\services\geocoding_service.dart" "$BackupDir\geocoding_service.dart.bak" -Force
Copy-Item "lib\services\advanced_geocoding_service.dart" "$BackupDir\advanced_geocoding_service.dart.bak" -Force
Copy-Item "lib\services\geocoding_stats_service.dart" "$BackupDir\geocoding_stats_service.dart.bak" -Force

# FAIL-FAST MANAGERS BACKUP (2 → 1)
Write-Host "🚨 Backing up fail-fast managers..." -ForegroundColor Cyan
Copy-Item "lib\services\fail_fast_stream_manager.dart" "$BackupDir\fail_fast_stream_manager.dart.bak" -Force
Copy-Item "lib\services\fail_fast_stream_manager_new.dart" "$BackupDir\fail_fast_stream_manager_new.dart.bak" -Force

# CACHING SERVICES BACKUP (3 → 1)
Write-Host "💾 Backing up caching services..." -ForegroundColor Cyan
Copy-Item "lib\services\cache_service.dart" "$BackupDir\cache_service.dart.bak" -Force
Copy-Item "lib\services\advanced_caching_service.dart" "$BackupDir\advanced_caching_service.dart.bak" -Force
Copy-Item "lib\services\performance_cache_service.dart" "$BackupDir\performance_cache_service.dart.bak" -Force

Write-Host "✅ Backup completed in folder: $BackupDir" -ForegroundColor Green
Write-Host ""
Write-Host "📋 CONSOLIDATION SUMMARY:" -ForegroundColor Yellow
Write-Host "• Geocoding: 3 services → 1 unified service" -ForegroundColor White
Write-Host "• Fail-Fast: 2 managers → 1 unified manager" -ForegroundColor White  
Write-Host "• Caching: 3 services → 1 unified service" -ForegroundColor White
Write-Host "• Total reduction: 8 services → 3 services (-62.5%)" -ForegroundColor Green
Write-Host ""
Write-Host "🔄 Next steps:" -ForegroundColor Yellow
Write-Host "1. Test unified services with existing code" -ForegroundColor White
Write-Host "2. Update imports across codebase" -ForegroundColor White
Write-Host "3. Remove old service files" -ForegroundColor White
Write-Host "4. Update service documentation" -ForegroundColor White