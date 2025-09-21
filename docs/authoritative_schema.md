# Authoritative schema (exported CSVs)

Summary: I loaded the CSVs you added to `tmp` (`mesecni_putnici_rows.csv` and `putovanja_istorija_rows.csv`) and extracted headers and a few sample rows. Use this file to verify live types before applying migrations.

## mesecni_putnici (CSV header)
- id
- putnik_ime
- tip
- tip_skole
- broj_telefona
- adresa_bela_crkva
- adresa_vrsac
- tip_prikazivanja
- radni_dani
- aktivan
- datum_pocetka_meseca
- datum_kraja_meseca
- broj_putovanja
- broj_otkazivanja
- poslednje_putovanje
- created_at
- updated_at
- obrisan
- pokupljen
- vreme_pokupljenja
- vreme_placanja
- vozac
- cena
- status
- pokupljanje_vozac
- naplata_vozac
- otkazao_vozac
- dodao_vozac
- placeni_mesec
- placena_godina
- sitan_novac
- polazak_bc_pon
- polazak_bc_uto
- polazak_bc_sre
- polazak_bc_cet
- polazak_bc_pet
- polazak_vs_pon
- polazak_vs_uto
- polazak_vs_sre
- polazak_vs_cet
- polazak_vs_pet
- polasci_po_danu
- radni_dani_arr
- cena_numeric
- statistics

Sample rows (first 3 rows from export):
- id=1c62ec08-2294-4acb-8375-a39a112a4b8b, putnik_ime=Radnik Test, tip=radnik, broj_putovanja=0, aktivan=false, created_at=2025-09-19 23:14:20.365258+00, updated_at=2025-09-21 01:45:46.793982+00
- id=553250f8-4a81-445c-bbe0-8eb342d61cad, putnik_ime=Ljilja Andrejic, tip=radnik, aktivan=true, created_at=2025-09-21 04:22:54.400542+00
- id=8e3b60e9-1e5f-4728-8aec-42c5e6dfc528, putnik_ime=Ucenik Test, tip=ucenik, tip_skole=Hemijska, broj_telefona=060991199

## putovanja_istorija (CSV header)
- id
- mesecni_putnik_id
- tip_putnika
- datum
- vreme_polaska
- adresa_polaska
- putnik_ime
- broj_telefona
- created_at
- updated_at
- status
- pokupljen
- vreme_pokupljenja
- vreme_placanja
- vozac
- dan
- grad
- obrisan
- cena
- pokupljanje_vozac
- naplata_vozac
- otkazao_vozac
- dodao_vozac
- sitan_novac

Sample rows (first 3 rows):
- id=293055e9-b132-41df-b1a4-2b731d57ef7d, mesecni_putnik_id=8e3b60e9-1e5f-4728-8aec-42c5e6dfc528, tip_putnika=mesecni, datum=2025-09-19, vreme_polaska=19:00:00, adresa_polaska=psihijatrija, status=nije_se_pojavio, grad=Vršac, cena=0.0
- id=7ce26491-acfd-4105-a185-9f3bb10e7acc, mesecni_putnik_id=8e3b60e9-1e5f-4728-8aec-42c5e6dfc528, datum=2025-09-19, vreme_polaska=09:00:00, adresa_polaska=Jasenovo skola, status=nije_se_pojavio, grad=Bela Crkva
- id=a0b48ec3-fe48-4772-8581-e483d23adc20, mesecni_putnik_id=NULL, tip_putnika=dnevni, datum=2025-09-22, vreme_polaska=05:00:00, adresa_polaska=Policija, putnik_ime=Dnevni Test, grad=Bela Crkva, obrisan=false, cena=0.0, dodao_vozac=Bojan

Notes:
- The CSV header shows many application-expected columns already present (e.g., `cena_numeric` in `mesecni_putnici`, `vreme_pokupljenja`/`vreme_placanja` fields currently as text/time).
- `mesecni_putnik_id` in `putovanja_istorija` is sometimes NULL for `dnevni` rows — expected.

Next steps:
- Confirm this matches what you expect. If yes, I will:
  1) Update `docs/columns_and_statistics.md` types to `timestamptz` for `created_at/updated_at` and propose final types.
  2) Generate a non-destructive migration draft adding `dozvoljeni_putnik_id UUID NULL`, `vreme_pokupljenja_ts timestamptz`, `vreme_placanja_ts timestamptz`, and `cena_numeric numeric(10,2)` if missing.
  3) Create backfill SQL to map existing rows and verify with checks.

