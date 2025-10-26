#!/bin/bash

# SERVICE CONSOLIDATION BACKUP SCRIPT (Bash version)
# Creates backup of old redundant services before migration

BACKUP_DIR="service_consolidation_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup of redundant services..."

# GEOCODING SERVICES BACKUP (3 → 1)
echo "🗺️ Backing up geocoding services..."
cp "lib/services/geocoding_service.dart" "$BACKUP_DIR/geocoding_service.dart.bak"
cp "lib/services/advanced_geocoding_service.dart" "$BACKUP_DIR/advanced_geocoding_service.dart.bak"
cp "lib/services/geocoding_stats_service.dart" "$BACKUP_DIR/geocoding_stats_service.dart.bak"

# FAIL-FAST MANAGERS BACKUP (2 → 1)
echo "🚨 Backing up fail-fast managers..."
cp "lib/services/fail_fast_stream_manager.dart" "$BACKUP_DIR/fail_fast_stream_manager.dart.bak"
cp "lib/services/fail_fast_stream_manager_new.dart" "$BACKUP_DIR/fail_fast_stream_manager_new.dart.bak"

# CACHING SERVICES BACKUP (3 → 1)
echo "💾 Backing up caching services..."
cp "lib/services/cache_service.dart" "$BACKUP_DIR/cache_service.dart.bak"
cp "lib/services/advanced_caching_service.dart" "$BACKUP_DIR/advanced_caching_service.dart.bak"
cp "lib/services/performance_cache_service.dart" "$BACKUP_DIR/performance_cache_service.dart.bak"

echo "✅ Backup completed in folder: $BACKUP_DIR"
echo ""
echo "📋 CONSOLIDATION SUMMARY:"
echo "• Geocoding: 3 services → 1 unified service"
echo "• Fail-Fast: 2 managers → 1 unified manager"  
echo "• Caching: 3 services → 1 unified service"
echo "• Total reduction: 8 services → 3 services (-62.5%)"
echo ""
echo "🔄 Next steps:"
echo "1. Test unified services with existing code"
echo "2. Update imports across codebase"
echo "3. Remove old service files"
echo "4. Update service documentation"