-- 20250921_extend_dozvoljeni.sql
-- Non-destructive ALTERs to add richer columns to `dozvoljeni_mesecni_putnici` to support imports.
-- Add only columns if missing to avoid destructive changes.

BEGIN;

ALTER TABLE IF EXISTS public.dozvoljeni_mesecni_putnici
  -- legacy JSON `polasci_po_danu` intentionally NOT added; use per-day columns instead
  ADD COLUMN IF NOT EXISTS datum_pocetka_meseca date NULL,
  ADD COLUMN IF NOT EXISTS datum_kraja_meseca date NULL,
  ADD COLUMN IF NOT EXISTS cena numeric(10,2) NULL,
  ADD COLUMN IF NOT EXISTS broj_putovanja integer DEFAULT 0 NULL,
  ADD COLUMN IF NOT EXISTS broj_otkazivanja integer DEFAULT 0 NULL,
  ADD COLUMN IF NOT EXISTS vreme_placanja timestamptz NULL,
  ADD COLUMN IF NOT EXISTS placeni_mesec integer NULL,
  ADD COLUMN IF NOT EXISTS placena_godina integer NULL,
  ADD COLUMN IF NOT EXISTS aktivan boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS obrisan boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_dozv_canonical_hash ON public.dozvoljeni_mesecni_putnici (canonical_hash);

COMMIT;
