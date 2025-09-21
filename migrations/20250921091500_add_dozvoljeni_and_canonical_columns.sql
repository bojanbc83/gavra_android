-- 20250921091500_add_dozvoljeni_and_canonical_columns.sql
-- Generated from draft `015_add_dozvoljeni_and_canonical_columns.sql`
-- Non-destructive; uses IF NOT EXISTS and IF NOT NULL checks.

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

COMMIT;

-- Backfill steps removed from migration file; run separately as controlled jobs.
