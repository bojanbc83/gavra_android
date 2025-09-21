-- 20250921_backfill_plan.sql
-- Safe step-by-step backfill & verification plan for staging.
-- Run each section manually and inspect results before proceeding to next.

-- 0) Basic sanity checks
-- Count rows
-- SELECT COUNT(*) FROM public.putovanja_istorija;
-- SELECT COUNT(*) FROM public.dozvoljeni_mesecni_putnici;

-- 1) Normalize cena -> cena_numeric for putovanja_istorija (non-destructive)
-- Preview rows where cena is non-numeric
-- SELECT id, cena FROM public.putovanja_istorija WHERE cena IS NOT NULL AND cena !~ '^[0-9]+(\\.[0-9]+)?$' LIMIT 50;

-- Create numeric column if not exists (already created by migration script but safe check)
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS cena_numeric numeric(10,2);

-- Backfill numeric parse (adjust regexp for locale if needed)
UPDATE public.putovanja_istorija
SET cena_numeric = NULLIF(regexp_replace(cena::text, '[^0-9\\.]', '', 'g'), '')::numeric
WHERE cena IS NOT NULL AND (cena_numeric IS NULL OR cena_numeric = 0);

-- 2) Ensure vreme_placanja_ts and vreme_pokupljenja_ts are populated using existing fields
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS vreme_placanja_ts timestamptz;
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS vreme_pokupljenja_ts timestamptz;

-- Example parsing (only run after spot-checking formats)
-- UPDATE public.putovanja_istorija
-- SET vreme_placanja_ts = cast(vreme_placanja AS timestamptz)
-- WHERE vreme_placanja IS NOT NULL AND vreme_placanja_ts IS NULL;

-- 3) Normalize obrisan column: if it is text, create boolean column and copy semantics
-- Check current type by querying information_schema
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name='putovanja_istorija' AND column_name='obrisan';

-- If `obrisan` is text, create `obrisan_bool` and backfill
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS obrisan_bool boolean;
UPDATE public.putovanja_istorija
SET obrisan_bool = CASE
  WHEN LOWER(COALESCE(obrisan::text,'') ) IN ('true','t','1','yes','y') THEN true
  WHEN LOWER(COALESCE(obrisan::text,'')) IN ('false','f','0','no','n','') THEN false
  ELSE false
END
WHERE obrisan_bool IS NULL;

-- (Optional) After verification, you may drop or rename original column and rename obrisan_bool->obrisan
-- ALTER TABLE public.putovanja_istorija DROP COLUMN obrisan;
-- ALTER TABLE public.putovanja_istorija RENAME COLUMN obrisan_bool TO obrisan;

-- 4) Import roster SQL produced by transform script (manual step) - recommended to run on staging only.
-- psql $CONN -f tmp/import_dozvoljeni.sql

-- 5) Backfill dozvoljeni_putnik_id on putovanja_istorija from roster
-- Safe update: only set where dozvoljeni_putnik_id IS NULL
-- Run the generated mapping SQL file `tmp/mapping_putovanja.sql` after reviewing.

-- 6) Verify mappings won't clobber existing mesecni_putnik_id
-- SELECT count(*) FROM public.putovanja_istorija WHERE dozvoljeni_putnik_id IS NOT NULL AND mesecni_putnik_id IS NOT NULL;

-- 7) Reporting queries
-- Rows where mapping not found (putnik_ime unmatched)
-- SELECT putnik_ime, COUNT(*) FROM public.putovanja_istorija WHERE dozvoljeni_putnik_id IS NULL GROUP BY putnik_ime ORDER BY COUNT DESC LIMIT 50;

-- 8) Final checks: compare app usage expectations
-- SELECT id, putnik_ime, datum, mesecni_putnik_id, dozvoljeni_putnik_id FROM public.putovanja_istorija WHERE datum >= now() - interval '7 days' ORDER BY datum DESC LIMIT 100;

-- End of backfill plan
