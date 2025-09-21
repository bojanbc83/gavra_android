-- CREATE script for gavra_dozvoljeni_mesecni_putnici (saved & renamed)
create table public.gavra_dozvoljeni_mesecni_putnici (
  id uuid not null default gen_random_uuid (),
  ime text null,
  telefon text null,
  email text null,
  canonical_hash text null,
  source_mesecni_putnici_id text[] null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone null,
  constraint gavra_dozvoljeni_mesecni_putnici_pkey primary key (id)
) TABLESPACE pg_default;

create unique INDEX IF not exists gavra_dozv_putnici_canonical_hash_idx on public.gavra_dozvoljeni_mesecni_putnici using btree (canonical_hash) TABLESPACE pg_default;
