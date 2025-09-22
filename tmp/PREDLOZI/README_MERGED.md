Merged schema README

Šta je u ovoj migraciji
- Koristi UUID (`gen_random_uuid()`) za primarne ključeve radi skalabilnosti i sigurnosti.
- Vremenski tipovi su `timestamptz` za događaje koji zahtevaju vremensku zonu (polasci, plaćanja, otkazivanja).
- Relacijski rasporedi (`work_schedules`) + `schedule_exceptions` za fleksibilne radne šeme.
- Model rezervacija (`bookings`), tripova (`trips`) i vožnji (`rides`) za praćenje sedišta i istorije.
- `driver_logs` tabela za dnevne statistike vozača (takings, kilometers, pickups).
- Materialized views za mesečnu i dnevnu agregaciju i helper funkciju `refresh_reports()`.

Kako pokrenuti migraciju (Supabase / Postgres)
1. Na lokalnom Postgres-u ili Supabase SQL editoru, pokreni migracije redom:

  - `migrations/001_initial_schema.sql`
  - `migrations/002_reports_and_indexes.sql`

2. Ako koristite Supabase SQL editor: otvorite SQL editor, paste-ujte sadržaj svakog fajla i izvršite u istom redosledu.

Napomene / preporuke posle migracije
- Kreirajte RLS politike (policy) za tabele:
  - `drivers` / `driver_logs`: vozač vidi samo svoje `driver_logs` i `rides`.
  - `users` / `monthly_passengers`: ograničiti modifikacije samo adminu.
- Dodajte indekse na kolone koje najviše koristite u WHERE/GROUP BY.
- Planirajte da pozivate `refresh_reports()` periodično (npr. jednom dnevno) putem Supabase scheduled function.
- Definišite enum tipove dodatno po potrebi.

Napomena o autentikaciji (Supabase):
- Supabase koristi `auth.uid()` kao UUID korisnika. Da biste vezali Supabase auth korisnika za red u `users`, prilikom kreiranja korisnika postavite `users.id = auth.uid()` ili sinhronizujte `users.user_id` sa `auth` sistemom. RLS politike ispod pretpostavljaju da `auth.uid()` vraća UUID koji odgovara `users.id`.

Sledeći koraci koje mogu odmah da uradim za tebe:
- Generisanje SQL RLS primera za Supabase (vozač vs admin).
- Konkretne SQL upite za izveštaje (mesečni broj putovanja, ukupan iznos po putniku, dnevni pazar po vozaču).
- Pretvaranje `merged_schema.sql` u Seriju migracija (001_..., 002_...)

Ako želiš, mogu odmah da generišem: `sample_reports.sql` sa najvažnijim upitima i `supabase_policies.sql` sa primerima RLS politika.
