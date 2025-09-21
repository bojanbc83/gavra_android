# Schema comparison report (2025-09-21)

This report compares SQL CREATE scripts in `tmp/GAVRA SUPABASE` with Dart models in `lib/models`.

## 1) `gavra_dozvoljeni_mesecni_putnici` (SQL)

- id : uuid
- ime : text
- telefon : text
- email : text
- canonical_hash : text
- source_mesecni_putnici_id : text[]
- created_at : timestamp with time zone
- updated_at : timestamp with time zone

Model mapping: `MesecniPutnik` (`lib/models/dozvoljeni_mesecni_putnik.dart`)

- id -> `id` (String)
- ime -> `putnik_ime` (String)
- telefon -> `broj_telefona` (String?)
- email -> NOT MAPPED (no `email` field)
- canonical_hash -> NOT MAPPED
- source_mesecni_putnici_id -> NOT MAPPED
- created_at -> `createdAt` (DateTime)
- updated_at -> `updatedAt` (DateTime)

Notes / Recommendations:
- The `MesecniPutnik` model stores `putnik_ime` instead of `ime` and exposes `broj_telefona` — these map cleanly.
- Add optional fields to model if you need to use `email`, `canonical_hash`, or `source_mesecni_putnici_id` in the app.

## 2) `gavra_putovanja_istorija` (SQL)

- id : uuid
- mesecni_putnik_id : uuid
- tip_putnika : text
- datum : date
- vreme_polaska : time without time zone
- adresa_polaska : text
- ime : text
- broj_telefona : text
- created_at : timestamp with time zone
- updated_at : timestamp with time zone
- status : text
- pokupljen : boolean
- vreme_pokupljenja : timestamp with time zone
- vreme_placanja : timestamp with time zone
- vozac : text
- dan : text
- grad : text
- obrisan : text
- cena : text
- pokupljanje_vozac : text
- naplata_vozac : text
- otkazao_vozac : text
- dodao_vozac : text
- sitan_novac : text
- dozvoljeni_putnik_id : uuid
- vreme_pokupljenja_ts : timestamp with time zone
- vreme_placanja_ts : timestamp with time zone
- cena_numeric : numeric(10,2)
- raw_data : jsonb

Model mapping: `PutovanjaIstorija` (`lib/models/putovanja_istorija.dart`)

- id -> `id` (String)
- mesecni_putnik_id -> `mesecniPutnikId` (String?)
- tip_putnika -> `tipPutnika` (String)
- datum -> `datum` (DateTime)
- vreme_polaska -> `vremePolaska` (String)
- adresa_polaska -> `adresaPolaska` (String)
- ime -> `putnikIme` (String)
- broj_telefona -> `brojTelefona` (String?)
- created_at -> `createdAt` (DateTime)
- updated_at -> `updatedAt` (DateTime)
- status -> `status` (String)
- pokupljen -> `pokupljen` (bool)
- vreme_pokupljenja -> `vremePokupljenja` (DateTime?)
- vreme_placanja -> `vremePlacanja` (DateTime?)
- vozac -> `vozac` (String?)
- dan -> `dan` (String?)
- grad -> `grad` (String?)
- obrisan -> `obrisan` (bool)
- cena / cena_numeric -> `cena` (double)
- raw_data -> NOT MAPPED (no `raw_data` field)
- dozvoljeni_putnik_id -> NOT MAPPED (model has `mesecniPutnikId` and `dozvoljeni_putnik_id` not present)
- pokupljanje_vozac / naplata_vozac / otkazao_vozac / dodao_vozac / sitan_novac -> NOT MAPPED
- vreme_pokupljenja_ts / vreme_placanja_ts -> NOT MAPPED (timestamps duplicates)

Notes / Recommendations:
- The `PutovanjaIstorija` model covers core columns used in app logic (status, pokupljen, timestamps, driver, location fields).
- Several SQL columns appear to be legacy or extra telemetry (`*_vozac` fields, `_ts` duplicates, `raw_data`). Add them to the model only if the app needs them.
- `obrisan` in SQL is `text` — model expects `bool`. Confirm DB column type/values. If it's text with 'true'/'false', adjust parsing.

---

## Summary

- Core schema is represented in Dart models with slightly different naming conventions. Most fields needed by the app are mapped.
- Missing mappings: `email`, `canonical_hash`, `source_mesecni_putnici_id`, `raw_data`, several driver-related audit columns, and timestamp-duplicate fields.
- Actionable: add missing optional fields to models or update `fromMap` parsing if you need those columns; verify `obrisan` DB type vs model bool.

If you want, I can:
- Update models to include missing optional fields and add mapping/parsing in `fromMap`/`toMap`.
- Generate a migration SQL to reconcile types (e.g., `obrisan` -> boolean) if desired.
