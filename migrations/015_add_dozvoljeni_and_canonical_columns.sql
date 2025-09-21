-- 015_add_dozvoljeni_and_canonical_columns.sql
-- Draft: add canonical roster table and canonical columns for mapping/backfill.
-- Run on staging first. This script is intentionally non-destructive.

BEGIN;

-- 1) Create `dozvoljeni_mesecni_putnici` roster table
CREATE TABLE IF NOT EXISTS public.dozvoljeni_mesecni_putnici (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ime TEXT,
  prezime TEXT,
  telefon TEXT,
  email TEXT,
  canonical_hash TEXT,
  source_mesecni_putnici_id TEXT[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS dozv_putnici_canonical_hash_idx ON public.dozvoljeni_mesecni_putnici (canonical_hash);

-- 2) Add canonical columns to putovanja_istorija (non-destructive)
ALTER TABLE IF EXISTS public.putovanja_istorija
  ADD COLUMN IF NOT EXISTS dozvoljeni_putnik_id UUID NULL,
  ADD COLUMN IF NOT EXISTS vreme_pokupljenja_ts timestamptz NULL,
  ADD COLUMN IF NOT EXISTS vreme_placanja_ts timestamptz NULL,
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(10,2) NULL,
  ADD COLUMN IF NOT EXISTS raw_data jsonb NULL;

CREATE INDEX IF NOT EXISTS idx_putovanja_dozvoljeni_putnik_id ON public.putovanja_istorija (dozvoljeni_putnik_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_mesecni_putnik_id ON public.putovanja_istorija (mesecni_putnik_id);

-- 3) Add canonical columns to mesecni_putnici if missing
ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS canonical_hash TEXT NULL,
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(10,2) NULL,
  ADD COLUMN IF NOT EXISTS raw_data jsonb NULL;

CREATE INDEX IF NOT EXISTS idx_mesecni_canonical_hash ON public.mesecni_putnici (canonical_hash);

-- 4) Backfill strategy (examples) - run these in batches on staging
-- 4a) Populate cena_numeric from cena in mesecni_putnici (basic numeric parse)
-- NOTE: adjust regexp if your locale uses comma decimal separator
UPDATE public.mesecni_putnici
SET cena_numeric = NULLIF(regexp_replace(cena, '[^0-9\.]', '', 'g'), '')::numeric
WHERE cena IS NOT NULL AND (cena_numeric IS NULL OR cena_numeric = 0);

-- 4b) Populate cena_numeric in putovanja_istorija
UPDATE public.putovanja_istorija
SET cena_numeric = NULLIF(regexp_replace(cena::text, '[^0-9\.]', '', 'g'), '')::numeric
WHERE cena IS NOT NULL AND (cena_numeric IS NULL OR cena_numeric = 0);

-- 4c) Populate vreme_pokupljenja_ts and vreme_placanja_ts from existing columns if available
-- Example: if `vreme_pokupljenja` stored as text 'HH:MM:SS' and `datum` exists, combine them
UPDATE public.putovanja_istorija
SET vreme_pokupljenja_ts = to_timestamp(concat(datum::text, ' ', vreme_pokupljenja::text), 'YYYY-MM-DD HH24:MI:SS')
WHERE vreme_pokupljenja_ts IS NULL AND vreme_pokupljenja IS NOT NULL AND datum IS NOT NULL;

-- If application stores `vreme_placanja` as timestamptz text, try parsing
UPDATE public.putovanja_istorija
SET vreme_placanja_ts = cast(vreme_placanja AS timestamptz)
WHERE vreme_placanja_ts IS NULL AND vreme_placanja IS NOT NULL;

-- 4d) Backfill `dozvoljeni_mesecni_putnici` from unique normalized mesecni_putnici rows (draft)
-- Normalize helper: lower-trim name and phone
INSERT INTO public.dozvoljeni_mesecni_putnici (ime, prezime, telefon, canonical_hash, source_mesecni_putnici_id, created_at)
SELECT
  split_part(putnik_ime, ' ', 1) AS ime,
  substring(putnik_ime from '\\s+(.*)$') AS prezime,
  regexp_replace(broj_telefona, '\\D', '', 'g') as telefon,
  md5(lower(trim( coalesce(putnik_ime, '') || '|' || coalesce(regexp_replace(broj_telefona,'\\D','', 'g'), '') ))) as canonical_hash,
  array[id::text] as source_mesecni_putnici_id,
  now()
FROM public.mesecni_putnici mp
WHERE mp.id IS NOT NULL
ON CONFLICT (canonical_hash) DO UPDATE
  SET source_mesecni_putnici_id = array_cat(coalesce(public.dozvoljeni_mesecni_putnici.source_mesecni_putnici_id, ARRAY[]::text[]), ARRAY[mp.id::text]);

-- 4e) Map putovanja_istorija to dozvoljeni_mesecni_putnici via mesecni_putnik_id where possible
UPDATE public.putovanja_istorija pi
SET dozvoljeni_putnik_id = d.id
FROM public.dozvoljeni_mesecni_putnici d
WHERE pi.mesecni_putnik_id::text = ANY(d.source_mesecni_putnici_id)
  AND pi.dozvoljeni_putnik_id IS NULL;

-- 4f) Report unmatched rows (run after backfill to inspect)
-- SELECT count(*) FROM public.putovanja_istorija WHERE dozvoljeni_putnik_id IS NULL AND mesecni_putnik_id IS NOT NULL;

COMMIT;

-- End of migration draft
