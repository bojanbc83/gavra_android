-- 20250921_create_dozvoljeni_full.sql
-- Create an enhanced `dozvoljeni_mesecni_putnici` table (non-destructive IF NOT EXISTS)
BEGIN;

-- Create table if not exists with recommended statistic and payment columns
CREATE TABLE IF NOT EXISTS public.dozvoljeni_mesecni_putnici (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_ime text NOT NULL,
  tip text,
  tip_skole text,
  broj_telefona text,
  adresa_bela_crkva text,
  adresa_vrsac text,
  tip_prikazivanja text,
  radni_dani text,
  aktivan boolean DEFAULT true,
  obrisan boolean DEFAULT false,

  -- Per-day canonical columns (example: polazak_bc_pon, polazak_vs_pon)
  polazak_bc_pon text,
  polazak_bc_uto text,
  polazak_bc_sre text,
  polazak_bc_cet text,
  polazak_bc_pet text,
  polazak_vs_pon text,
  polazak_vs_uto text,
  polazak_vs_sre text,
  polazak_vs_cet text,
  polazak_vs_pet text,

  -- Statistic / accounting columns
  broj_putovanja integer DEFAULT 0 NOT NULL,
  broj_otkazivanja integer DEFAULT 0 NOT NULL,
  ukupna_cena_meseca numeric(10,2),
  cena numeric(10,2),

  -- Payment tracking
  placeno boolean DEFAULT false,
  vreme_placanja timestamptz,
  placeni_mesec integer,
  placena_godina integer,
  naplata_vozac text,

  poslednje_putovanje timestamptz,

  datum_pocetka_meseca date,
  datum_kraja_meseca date,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_dozv_placeni_god_mes ON public.dozvoljeni_mesecni_putnici (placena_godina, placeni_mesec);
CREATE INDEX IF NOT EXISTS idx_dozv_vreme_placanja ON public.dozvoljeni_mesecni_putnici (vreme_placanja);
CREATE INDEX IF NOT EXISTS idx_dozv_broj_putovanja ON public.dozvoljeni_mesecni_putnici (broj_putovanja);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dozv_set_updated_at ON public.dozvoljeni_mesecni_putnici;
CREATE TRIGGER trg_dozv_set_updated_at
BEFORE UPDATE ON public.dozvoljeni_mesecni_putnici
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Backfill function: populate statistik columns from putovanja_istorija
CREATE OR REPLACE FUNCTION public.backfill_dozv_stats_for_month(p_year integer, p_month integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  -- Example simple backfill: count realized and cancelled trips per mesecni_putnik
  WITH month_rows AS (
    SELECT id FROM public.dozvoljeni_mesecni_putnici
  )
  UPDATE public.dozvoljeni_mesecni_putnici d
  SET
    broj_putovanja = COALESCE(sub.realizovano,0),
    broj_otkazivanja = COALESCE(sub.otkazano,0),
    poslednje_putovanje = sub.last_ts
  FROM (
    SELECT
      pti.mesecni_putnik_id as pid,
      COUNT(*) FILTER (WHERE pti.status IS DISTINCT FROM 'otkazano') as realizovano,
      COUNT(*) FILTER (WHERE pti.status = 'otkazano') as otkazano,
      MAX(pti.created_at) as last_ts
    FROM public.putovanja_istorija pti
    WHERE EXTRACT(YEAR FROM pti.datum) = p_year
      AND EXTRACT(MONTH FROM pti.datum) = p_month
    GROUP BY pti.mesecni_putnik_id
  ) sub
  WHERE d.id = sub.pid;
END;
$$;

COMMIT;
