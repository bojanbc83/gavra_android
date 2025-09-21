# Import tools

This folder contains helper scripts to transform CSV exports into SQL inserts for the `dozvoljeni_mesecni_putnici` table.

Files generated/used:
- `tools/transform_dozvoljeni.js` - reads `tmp/dozvoljeni_mesecni_putnici_rows.csv` and writes `tmp/import_dozvoljeni.sql` and `tmp/mapping_putovanja.sql`.
- `tmp/import_dozvoljeni.sql` - generated INSERT statements (do not commit without review).
- `tmp/mapping_putovanja.sql` - generated UPDATE statements to link `putovanja_istorija` rows by `putnik_ime`.

How to run:

```powershell
npm run transform:dozvoljeni
```

Security & safety
- Always review generated SQL before executing it.
- Backup your database or run on a staging/test DB first.
- The mapping script uses `putnik_ime` to match rows — it's a heuristic and can cause incorrect mapping for duplicate names.

If you want more strict mapping, change `tools/transform_dozvoljeni.js` to match on additional fields (e.g. `datum`, `grad`) or generate queries that only update rows where `mesecni_putnik_id` IS NULL.
