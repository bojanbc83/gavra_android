-- CREATE script for gavra_putovanja_istorija (saved & renamed)
create table public.gavra_putovanja_istorija (
  id uuid not null default extensions.uuid_generate_v4 (),
  mesecni_putnik_id uuid null,
  tip_putnika text not null,
  datum date not null,
  vreme_polaska time without time zone not null,
  adresa_polaska text not null,
  ime text not null,
  broj_telefona text null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  status text null,
  pokupljen boolean null default false,
  vreme_pokupljenja timestamp with time zone null,
  vreme_placanja timestamp with time zone null,
  vozac text null,
  dan text null,
  grad text null,
  obrisan text null,
  cena text null,
  pokupljanje_vozac text null,
  naplata_vozac text null,
  otkazao_vozac text null,
  dodao_vozac text null,
  sitan_novac text null,
  dozvoljeni_putnik_id uuid null,
  vreme_pokupljenja_ts timestamp with time zone null,
  vreme_placanja_ts timestamp with time zone null,
  cena_numeric numeric(10, 2) null,
  raw_data jsonb null,
  constraint gavra_putovanja_istorija_pkey primary key (id),
  constraint gavra_putovanja_istorija_tip_putnika_check check (
    (
      tip_putnika = any (array['mesecni'::text, 'dnevni'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_dozvoljeni_putnik_id on public.gavra_putovanja_istorija using btree (dozvoljeni_putnik_id) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_mesecni_putnik on public.gavra_putovanja_istorija using btree (mesecni_putnik_id) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_tip_putnika on public.gavra_putovanja_istorija using btree (tip_putnika) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_datum on public.gavra_putovanja_istorija using btree (datum) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_datum_desc on public.gavra_putovanja_istorija using btree (datum desc) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_vreme_polaska on public.gavra_putovanja_istorija using btree (vreme_polaska) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_mesecni_datum on public.gavra_putovanja_istorija using btree (mesecni_putnik_id, datum) TABLESPACE pg_default
where
  (mesecni_putnik_id is not null);

create index IF not exists gavra_idx_putovanja_mesecni_putnik_id on public.gavra_putovanja_istorija using btree (mesecni_putnik_id) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_dan on public.gavra_putovanja_istorija using btree (dan) TABLESPACE pg_default;

create index IF not exists gavra_idx_putovanja_istorija_grad on public.gavra_putovanja_istorija using btree (grad) TABLESPACE pg_default;

create trigger tr_gavra_enqueue_putovanja_notification
after INSERT on gavra_putovanja_istorija for EACH row
execute FUNCTION enqueue_putovanja_notification ();

create trigger tr_update_gavra_putovanja_updated_at BEFORE
update on gavra_putovanja_istorija for EACH row
execute FUNCTION update_updated_at_column ();
