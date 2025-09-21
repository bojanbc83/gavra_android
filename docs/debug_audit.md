Audit: Test / Debug / Tmp fajlovi

Datum: 2025-09-21

Cilj: identifikovati fajlove za čišćenje, dokumentovati čemu služe i dati preporuke za bezbedno uklanjanje/arhiviranje.

1) tmp/tombstone_00
  - Svrha: Android tombstone / crash dump (veliki tekstualni dump). Koristan samo za forenzičku analizu crash-a.
  - Preporuka: arhiviraj ili obriši. Ako treba za kasniju forenziku, premesti van repoa ili kompresuj i stavi u `archive/`.

2) tmp/Supabase Snippet Table and Column Sanity Checks.csv
  - Svrha: rezultat sanity SELECT upita (sadrži `dozvoljeni_count`).
  - Preporuka: premesti u `docs/exports/` ili obriši ako nije potreban.

3) tmp/Supabase Snippet Untitled query.csv
  - Svrha: lista kolona (output SQL Editor-a).
  - Preporuka: premesti u `docs/exports/` ili obriši.

4) tmp/mesecni_putnici_rows*.csv, tmp/putovanja_istorija_rows*.csv
  - Svrha: CSV exporti tabela. Korisni kao snapshot/backups pre transformacija.
  - Preporuka: premesti ih u `data/exports/` i dodaj `data/exports/` u `.gitignore`, ili obriši ako nisu potrebni.

5) tmp/google-services.json, tmp/firebase-downloaded-google-services.json
  - Svrha: Firebase/Google servis fajlovi. Mogu sadržavati osetljive informacije.
  - Preporuka: premesti van repoa i obriši iz `tmp/`. Ako su potrebni, drži ih u bezbednom vault-u, ne u repou.

6) tmp/adb_log_SIGQUIT.txt, tmp/dumpsys_meminfo.txt
  - Svrha: debug logovi.
  - Preporuka: arhiviraj ili obriši.

7) tmp/sdkconfig-*.json
  - Svrha: lokalne konfiguracije alata.
  - Preporuka: proveriti sadržaj na osetljive podatke; obriši ili premesti van repoa.

8) Migracije i docs (zadržati)
  - migrations/015_add_dozvoljeni_and_canonical_columns.sql (draft) — zadrži
  - migrations/20250921091500_add_dozvoljeni_and_canonical_columns.sql (timestamped) — zadrži
  - supabase/migrations/20250921040242_remote_schema.sql — zadrži
  - docs/migration_apply_instructions.md — zadrži

Preporučene naredne akcije (primer komandi)
- Napravi folder za arhivu i prebaci korisne CSV-e iz tmp-a:
  mkdir -p data/exports
  mv tmp/mesecni_putnici_rows*.csv data/exports/

- Ukloni velike debug fajlove iz repoa (obriši lokalno ako nije potrebna):
  rm tmp/tombstone_00

- Dodaj `tmp/` u `.gitignore` da sprečiš slučajni commit debug artifakata.

Sigurnosna napomena
- Ako tmp sadrži ključeve/lozinke, premesti ih odmah i ukloni iz repoa.

Sledeći koraci
- Potvrdi koje fajlove da premestim/obrišem i ja ću to uraditi.
