**Instrukcije za ručnu primenu migracije u Supabase SQL editoru**

- **Kratko:** Ako `supabase db pull` ili `db push` ne rade zbog CLI/SASL/SSL problema, primeni sledeći SQL direktno u Supabase web konzoli -> SQL Editor.

- **SQL koji treba da izvršiš (bez backfill koraka):**

```sql
BEGIN;

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

ALTER TABLE IF EXISTS public.putovanja_istorija
  ADD COLUMN IF NOT EXISTS dozvoljeni_putnik_id UUID NULL,
  ADD COLUMN IF NOT EXISTS vreme_pokupljenja_ts timestamptz NULL,
  ADD COLUMN IF NOT EXISTS vreme_placanja_ts timestamptz NULL,
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(10,2) NULL,
  ADD COLUMN IF NOT EXISTS raw_data jsonb NULL;

CREATE INDEX IF NOT EXISTS idx_putovanja_dozvoljeni_putnik_id ON public.putovanja_istorija (dozvoljeni_putnik_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_mesecni_putnik_id ON public.putovanja_istorija (mesecni_putnik_id);

ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS canonical_hash TEXT NULL,
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(10,2) NULL,
  ADD COLUMN IF NOT EXISTS raw_data jsonb NULL;

CREATE INDEX IF NOT EXISTS idx_mesecni_canonical_hash ON public.mesecni_putnici (canonical_hash);

COMMIT;
```

- **Koraci u Supabase UI:**
  1. Otvori Supabase Dashboard -> Project -> SQL Editor.
  2. Napravi novi query i nalepi gornji SQL.
  3. Klikni `Run` i sačekaj potvrdu.
  4. Posle uspeha, pokreni verifikacione SELECT upite (primeri dole).

- **Proverni SELECT upiti (posle primene):**
  - `SELECT to_regclass('public.dozvoljeni_mesecni_putnici');` — vratiće ime tabele ako postoji.
  - `SELECT column_name FROM information_schema.columns WHERE table_name='mesecni_putnici' AND column_name IN ('canonical_hash','cena_numeric');`
  - `SELECT column_name FROM information_schema.columns WHERE table_name='putovanja_istorija' AND column_name IN ('dozvoljeni_putnik_id','cena_numeric');`

- **Napomena:** Ovaj način neće automatski upisati migraciju u Supabase migrations istoriju; nakon što CLI `db pull` opet radi, preporučujem da pokreneš `supabase db pull` da sinhronizuješ lokalnu kopiju.
