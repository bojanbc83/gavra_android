#!/bin/bash

# 🔥 GAVRA 013 - MANUAL SUPABASE EXPORT SCRIPT
# 
# Ručni export Supabase podataka pomoću curl komandi
# Pokreći sa: ./manual_supabase_export.sh

# ⚠️ DODAJ PRAVI SUPABASE ANON KEY OVDE!
SUPABASE_URL="https://gjtabtwudbrmfeyjiicu.supabase.co"
SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY_HERE"

# Kreiraj backup direktorij
BACKUP_DIR="backup/manual_export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔥 GAVRA 013 - MANUAL SUPABASE EXPORT"
echo "📁 Backup direktorij: $BACKUP_DIR"
echo ""

# Lista tabela za export
TABLES=("vozaci" "mesecni_putnici" "dnevni_putnici" "putovanja_istorija" "adrese" "vozila" "gps_lokacije" "rute")

# Export svake tabele
for TABLE in "${TABLES[@]}"; do
    echo "📤 Exportujem tabelu: $TABLE..."
    
    curl -X GET "$SUPABASE_URL/rest/v1/$TABLE?select=*" \
         -H "apikey: $SUPABASE_ANON_KEY" \
         -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
         -H "Content-Type: application/json" \
         -o "$BACKUP_DIR/$TABLE.json"
    
    if [ $? -eq 0 ]; then
        RECORD_COUNT=$(jq '. | length' "$BACKUP_DIR/$TABLE.json" 2>/dev/null || echo "?")
        echo "✅ $TABLE exportovan: $RECORD_COUNT zapisa"
    else
        echo "❌ Greška pri exportu tabele $TABLE"
    fi
    
    sleep 0.5  # Kratka pauza između zahteva
done

echo ""
echo "🎉 EXPORT ZAVRŠEN!"
echo "📁 Backup lokacija: $BACKUP_DIR"

# Kreiraj summary
echo "{" > "$BACKUP_DIR/export_summary.json"
echo "  \"export_completed_at\": \"$(date -Iseconds)\"," >> "$BACKUP_DIR/export_summary.json"
echo "  \"backup_directory\": \"$BACKUP_DIR\"," >> "$BACKUP_DIR/export_summary.json"
echo "  \"supabase_url\": \"$SUPABASE_URL\"," >> "$BACKUP_DIR/export_summary.json"
echo "  \"tables_exported\": [" >> "$BACKUP_DIR/export_summary.json"

for i in "${!TABLES[@]}"; do
    TABLE="${TABLES[$i]}"
    if [ $i -eq $((${#TABLES[@]} - 1)) ]; then
        echo "    \"$TABLE\"" >> "$BACKUP_DIR/export_summary.json"
    else
        echo "    \"$TABLE\"," >> "$BACKUP_DIR/export_summary.json"
    fi
done

echo "  ]" >> "$BACKUP_DIR/export_summary.json"
echo "}" >> "$BACKUP_DIR/export_summary.json"

echo "📊 Export summary kreiran u: $BACKUP_DIR/export_summary.json"