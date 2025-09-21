# Kolone i statistike — opis i predlozi

Ovaj dokument beleži kolone koje su bitne za aplikaciju, canonicalizaciju podataka, indekse, i statistike koje treba pratiti.

Cilj: imati jedno mesto sa dogovorenim kolonama i SQL proverenim metrima pre nego što napravimo migracije ili kod promene.

---

## Tabele i preporučene kolone

1) `dozvoljeni_mesecni_putnici` (predlog minimalne roster tabele)
- `id UUID PRIMARY KEY` -- novi canonical id
- `ime TEXT NOT NULL`
- `prezime TEXT NOT NULL`
- `telefon TEXT NULL` -- formatisan broj, opcionalno
- `email TEXT NULL` -- opcionalno
- `canonical_hash TEXT NOT NULL` -- normalized lowe+rtrim hash for dedupe (UNIQUE)
- `source_mesecni_putnici_id bigint[] NULL` -- original ids (array) for auditing
- `created_at timestamptz NOT NULL DEFAULT now()`
- `updated_at timestamptz NULL`

Indeksi:
- `CREATE UNIQUE INDEX ON dozvoljeni_mesecni_putnici (canonical_hash)`
- GIN index on `source_mesecni_putnici_id` if used for lookups


2) `mesecni_putnici` (existing)
- Keep as-is during migration. Columns of interest to map:
  - `id` (bigint or text)
  - `ime`, `prezime`, `telefon`, `email`
  - legacy per-day columns `polazak_1`..`polazak_31` / `polasci_po_danu` jsonb
  - `cena` (text) and `cena_numeric` (numeric)
  - `radni_dani_arr` (text[] or int[])
  - `statistics` jsonb (if present)
  - `last_updated`, `created_at` (timestamps)

Notes: do not drop columns before backfill and verification.


3) `putovanja_istorija` (events/history)
- Columns to ensure canonicalization and mapping:
  - `id bigint` or `uuid` depending on history table design
  - `mesecni_putnik_id` (nullable) -- legacy pointer to `mesecni_putnici`
  - `dozvoljeni_putnik_id UUID NULL` -- new canonical pointer to `dozvoljeni_mesecni_putnici`
  - `status TEXT` -- standardized enum-like values (`zakupljeno`, `otkazano`, `nije_se_pojavio`, ...)
  - `vreme_pokupljenja_ts timestamptz NULL` -- canonical pickup time
  - `vreme_placanja_ts timestamptz NULL`
  - `cena_numeric numeric(10,2) NULL`
  - `raw_data jsonb NULL` -- to store original row snapshot if needed

Indexes:
- `CREATE INDEX ON putovanja_istorija (dozvoljeni_putnik_id)`
- `CREATE INDEX ON putovanja_istorija (mesecni_putnik_id)`
- GIN index on `raw_data` if frequent searches happen there


## Canonicalization i pravila mapiranja
- Imena: trim, lower, replace diacritics (ć->c, č->c, ž->z, š->s, đ->dj), collapse multiple spaces.
- Telefon: normalize by removing non-digits, leading country codes normalized.
- Email: lower-case and trim.
- canonical_hash = md5(concat(normalized_ime, '|', normalized_prezime, '|', telefon_or_email))
- Price: `cena_numeric` populated from `cena` using to_number/regexp to extract digits and decimal separator; ensure non-negative via CHECK.
- Timestamps: parse legacy text timestamps into `*_ts` canonical timestamptz columns; prefer `to_timestamp` with format fallbacks.


## Statistike koje aplikacija koristi (predlog listanja + SQL)
- **Broj aktivnih mesečnih putnika**:
  - Description: broj `dozvoljeni_mesecni_putnici` koji imaju `active` flag in `mesecni_putnici` or at least one future `putovanja_istorija` with `status='zakupljeno'`.
  - SQL (example):
    - Count by roster table: `SELECT count(*) FROM dozvoljeni_mesecni_putnici;`
    - Count by active zakupljeno future events: `SELECT count(DISTINCT dozvoljeni_putnik_id) FROM putovanja_istorija WHERE status='zakupljeno' AND vreme_pokupljenja_ts >= now()`

- **Broj putovanja po mesecu (per-putnik i globalno)**:
  - Per-putnik: `SELECT dozvoljeni_putnik_id, date_trunc('month', vreme_pokupljenja_ts) as mon, count(*) FROM putovanja_istorija WHERE status='zakupljeno' GROUP BY 1,2`.
  - Global: same without grouping by id.

- **Prihodi po mesecu**:
  - `SELECT date_trunc('month', vreme_placanja_ts) as mon, sum(cena_numeric) FROM putovanja_istorija WHERE cena_numeric IS NOT NULL GROUP BY 1`.

- **Neusklađeni/bez mappinga events**:
  - `SELECT * FROM putovanja_istorija WHERE dozvoljeni_putnik_id IS NULL AND (mesecni_putnik_id IS NOT NULL OR raw_data->>'name' IS NOT NULL) LIMIT 100`.

- **Duplikati u rosteru** (pre-migraciona provera):
  - `SELECT canonical_hash, array_agg(id) FROM mesecni_putnici GROUP BY canonical_hash HAVING count(*)>1`.

- **Promene cene / anomalije**:
  - `SELECT id, cena, cena_numeric FROM putovanja_istorija WHERE cena_numeric IS NULL AND cena IS NOT NULL LIMIT 100`.


## Dodatna polja i metričke vrednosti iz koda
Nakon pregleda `lib/services/statistika_service.dart`, `lib/services/mesecni_putnik_service.dart` i modela, dodajem sledeća polja i metričke upite koje aplikacija implicitno očekuje ili koristi:

- `broj_putovanja` (int) — čuva sinhronizovan broj jedinstvenih dana kada je putnik pokupljen. Ažurira se iz `putovanja_istorija`.
- `broj_otkazivanja` (int) — broj jedinstvenih dana sa statusom otkazan/nije_se_pojavio.
- `poslednje_putovanje` (date) — datum poslednjeg pokupljenja.
- `vreme_placanja` / `vreme_placanja_ts` (timestamptz) — kada je plaćeno; koristi se za filtriranje pazara.
- `naplata_vozac` / `vozac` / `naplatioVozac` (text) — ko je izvršio naplatu (korišćeno u StatistikaService).
- `pokupljanje_vozac` / `pokupioVozac` (text) — ko je izvršio pokupljanje; koristi se za broj pokupljenih i dugove.
- `vreme_otkazivanja` (timestamptz) — kada je otkazano; koristi se za periodne izveštaje.
- `placeni_mesec`, `placena_godina` (int) — za evidenciju za koji mesec/godinu je platno.
- `adresa_bela_crkva`, `adresa_vrsac` (text) — eksplicitne adrese koje se koriste u kreiranju `putovanja_istorija` i za optimizaciju rute.
- `broj_telefona` (text) — koristi se za deduplikaciju i komunikaciju.
- `vreme_pokupljenja` / `vreme_pokupljenja_ts` (timestamptz) — canonical pickup time (model i SQL koriste mešano polja — predloženo canonical `vreme_pokupljenja_ts`).

## SQL primeri za metrike koje StatistikaService računa

- PAZAR po vozaču u periodu (iz `putovanja_istorija` i `mesecni_putnici`):
  - `-- Obični putnici pazar po vozacu`
  - `SELECT naplata_vozac, SUM(cena_numeric) FROM putovanja_istorija WHERE vreme_placanja_ts BETWEEN $from AND $to AND tip_putnika != 'mesecni' AND status != 'otkazan' GROUP BY naplata_vozac;`
  - `-- Mesečne karte pazar po vozacu (iz mesecni_putnici)`
  - `SELECT naplata_vozac, SUM(cena) FROM mesecni_putnici WHERE vreme_placanja BETWEEN $from AND $to AND cena > 0 GROUP BY naplata_vozac;`

- DUGOVI (pokupljeni ali neplaćeni):
  - `SELECT pokupio_vozac, COUNT(*) FROM putovanja_istorija WHERE pokupljen = true AND (cena_numeric IS NULL OR cena_numeric = 0) AND status != 'otkazan' AND vreme_pokupljenja_ts BETWEEN $from AND $to GROUP BY pokupio_vozac;`

- BROJ mesecnih karata (jedinstveno po mesecnom putniku) u periodu:
  - `SELECT COUNT(DISTINCT id) FROM mesecni_putnici WHERE vreme_placanja BETWEEN $from AND $to AND cena > 0;`

- KILOMETRAŽA agregacija (ako imate GPS logs/table):
  - `SELECT vozac, SUM(km) as ukupno_km FROM gps_logs WHERE timestamp BETWEEN $from AND $to GROUP BY vozac;`

## Preporuka za dokumentaciju kolona u bazi
- Dodati u `docs/columns_and_statistics.md` ovaj spisak kolona kao "contract" koji se sinhronizuje sa migracijama, da developeri znaju koja polja aplikacija očekuje.

---

Napomena: dokument je ažuriran da uključi sva polja i metričke izvode viđene u kodu. Ako želite, mogu da generišem SQL migraciju koja dodaje nedostajuće canonical kolone (`dozvoljeni_putnik_id`, `vreme_placanja_ts`, `vreme_pokupljenja_ts`, `cena_numeric`, `pokupio_vozac`, `naplata_vozac`, `vreme_otkazivanja`) kao non-destructive ALTER korake.


## Verifikacioni upiti pre i posle migracije
- Pre-migration:
  - Count rows in each table: `SELECT (SELECT count(*) FROM mesecni_putnici) as mesecni, (SELECT count(*) FROM putovanja_istorija) as istorija;`
  - Duplicate hashes in `mesecni_putnici`.
- After backfill (mapping):
  - `SELECT count(*) FROM putovanja_istorija WHERE dozvoljeni_putnik_id IS NOT NULL;` -- expect near 100% for rows referencing a monthly putnik.
  - Report unmatched: `SELECT count(*) FROM putovanja_istorija WHERE dozvoljeni_putnik_id IS NULL AND (mesecni_putnik_id IS NOT NULL OR raw_data IS NOT NULL)`.


## Rollback i sigurnosne preporuke
- Raditi sve na staging i snapshot DB pre svake migracije.
- Koristiti non-destructive ALTER (dodaj kolone, napuni, proveri) pre nego što se brišu stare kolone.
- Zadržati `mesecni_putnici` nedirnut dok se sve verifikuje.
- Koristiti `transaction` gde moguće, ali za velike backfill operacije razdvojiti u batch-e da izbegnemo dugotrajne transakcije.


## Sledeći koraci (kratko)
- Finalizovati SQL migraciju i backfill skripte.
- Pripremiti kode patch sa feature-flagom.
- Pokrenuti na staging i proveriti verifikacione upite.


---

Dokument napravio asistent radi praćenja predloga — spremno za review i dopunu.

## Migration draft

- Kreirao sam nacrt migracije u `migrations/015_add_dozvoljeni_and_canonical_columns.sql` (Postgres SQL). Migration sadrži:
  - Kreiranje `dozvoljeni_mesecni_putnici` tabele
  - Dodavanje canonical kolona u `putovanja_istorija` i `mesecni_putnici` (`dozvoljeni_putnik_id`, `vreme_pokupljenja_ts`, `vreme_placanja_ts`, `cena_numeric`, `raw_data`)
  - Primer backfill upita (cena parsing, vreme_pokupljenja_ts popunjavanje iz `datum` + `vreme_pokupljenja`, mapiranje preko `mesecni_putnik_id`)

Napomena: migracija je napisana u Postgres sintaksi. Linter u editoru može prijaviti greške ako pokušava da je parsira kao drugi dialect; izvršavaj je na staging-u i testiraj pre produkcije.

Sledeći koraci koje mogu uraditi:
- Ažurirati tipove u `docs/columns_and_statistics.md` da eksplicitno pokažem predložene tipove (UUID, timestamptz, numeric).
- Generisati poseban batch backfill skript sa LIMIT/OFFSET ili sa cursor-om za velike tabele.
- Napraviti PR sa migracijom i dokumentacijom.
