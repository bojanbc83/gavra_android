Import steps (PowerShell) - run locally on your machine

Prerequisites:
- `psql` and `pg_dump` must be installed and available in PATH. On Windows, install PostgreSQL client tools or use `psql` from the Postgres installer or via `chocolatey`.

1) Backup database (replace placeholders):

```powershell
$CONN = "postgresql://postgres.gjtabtwudbrmfeyjiicu:1DIA0obrDgQHGMAc@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"
pg_dump --dbname=$CONN -F c -f backup_pre_import.dump
```

2) Test import in a transaction (dry-run):

```powershell
$CONN = "postgresql://postgres.gjtabtwudbrmfeyjiicu:1DIA0obrDgQHGMAc@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"
# Open psql and run BEGIN; \i tmp/import_dozvoljeni.sql; ROLLBACK;
psql $CONN -c "BEGIN;" -f tmp/import_dozvoljeni.sql -c "ROLLBACK;"
```

3) If the dry-run looks good, perform the import inside a transaction:

```powershell
psql $CONN -c "BEGIN;" -f tmp/import_dozvoljeni.sql -c "COMMIT;"
```

4) Run safe mapping (only update where mesecni_putnik_id IS NULL):

```powershell
psql $CONN -f tmp/mapping_putovanja_safe.sql
```

5) Verify results (examples):

```powershell
# Count inserted monthly passengers
psql $CONN -c "SELECT COUNT(*) FROM public.dozvoljeni_mesecni_putnici WHERE created_at >= now() - interval '1 day';"
# Sample mapping check
psql $CONN -c "SELECT id, putnik_ime, mesecni_putnik_id FROM public.putovanja_istorija WHERE putnik_ime IN ('Radnik Test','Ljilja Andrejic','Ucenik Test') ORDER BY datum LIMIT 20;"
```

6) Rollback/restore (if needed):

```powershell
# Restore from backup (be careful - this will overwrite)
pg_restore --dbname=$CONN --clean backup_pre_import.dump
```

Notes:
- `tmp/import_dozvoljeni.sql` contains INSERTs with default values for fields not present in your CSV.
- `tmp/mapping_putovanja_safe.sql` only updates rows where `mesecni_putnik_id IS NULL` to reduce risk.
- If you prefer, I can run these steps remotely but you must confirm and accept the security implications of providing credentials.
