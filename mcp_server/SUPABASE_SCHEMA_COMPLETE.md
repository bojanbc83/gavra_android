# 🗄️ SUPABASE COMPLETE SCHEMA ANALYSIS
**Date**: 2025-10-25T14:04:18.141Z
**Project**: gjtabtwudbrmfeyjiicu
**URL**: https://gjtabtwudbrmfeyjiicu.supabase.co

## 🔑 CONNECTION INFO
- **ANON KEY**: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk
- **SERVICE ROLE**: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4
- **PROJECT PASSWORD**: FlqfvHczUpSytgrV

---

## 📊 DISCOVERED TABLES (8)

### 🔸 TABLE: `mesecni_putnici`
- **Rows**: 5+ (showing first 5)
- **Columns**: 39
- **Column Names**: id, putnik_ime, tip, tip_skole, broj_telefona, broj_telefona_oca, broj_telefona_majke, polasci_po_danu, adresa_bela_crkva, adresa_vrsac, tip_prikazivanja, radni_dani, aktivan, status, datum_pocetka_meseca, datum_kraja_meseca, ukupna_cena_meseca, cena, broj_putovanja, broj_otkazivanja, poslednje_putovanje, vreme_placanja, placeni_mesec, placena_godina, vozac_id, pokupljen, vreme_pokupljenja, statistics, obrisan, created_at, updated_at, ruta_id, vozilo_id, adresa_polaska_id, adresa_dolaska_id, ime, prezime, datum_pocetka, datum_kraja

**Column Details:**
- `id`: string (e.g., "295db8f8-2bd9-46b3-9bec-63d37ece95aa")
- `putnik_ime`: string (e.g., "Bar Andjela")
- `tip`: string (e.g., "ucenik")
- `tip_skole`: string (e.g., "Hemijska")
- `broj_telefona`: string (e.g., "0642351663")
- `broj_telefona_oca`: null
- `broj_telefona_majke`: string (e.g., "0642717071")
- `polasci_po_danu`: object (e.g., {})
- `adresa_bela_crkva`: string (e.g., "Vojske Jugoslavije")
- `adresa_vrsac`: string (e.g., "Dis")
- `tip_prikazivanja`: string (e.g., "standard")
- `radni_dani`: string (e.g., "pon,uto,sre,cet,pet")
- `aktivan`: boolean (e.g., true)
- `status`: string (e.g., "aktivan")
- `datum_pocetka_meseca`: string (e.g., "2025-10-01")
- `datum_kraja_meseca`: string (e.g., "2025-10-31")
- `ukupna_cena_meseca`: number (e.g., 0)
- `cena`: number (e.g., 0)
- `broj_putovanja`: number (e.g., 0)
- `broj_otkazivanja`: number (e.g., 0)
- `poslednje_putovanje`: null
- `vreme_placanja`: string (e.g., "2025-10-21T21:31:08.990597+00:00")
- `placeni_mesec`: number (e.g., 9)
- `placena_godina`: number (e.g., 2025)
- `vozac_id`: string (e.g., "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e")
- `pokupljen`: boolean (e.g., false)
- `vreme_pokupljenja`: null
- `statistics`: object (e.g., {"last_trip":null,"trips_total":0,"cancellations_t)
- `obrisan`: boolean (e.g., false)
- `created_at`: string (e.g., "2025-10-20T22:31:55.679573+00:00")
- `updated_at`: string (e.g., "2025-10-21T21:31:08.990643+00:00")
- `ruta_id`: null
- `vozilo_id`: null
- `adresa_polaska_id`: null
- `adresa_dolaska_id`: null
- `ime`: null
- `prezime`: null
- `datum_pocetka`: null
- `datum_kraja`: null

**Sample Records:**
```json
[
  {
    "id": "295db8f8-2bd9-46b3-9bec-63d37ece95aa",
    "putnik_ime": "Bar Andjela",
    "tip": "ucenik",
    "tip_skole": "Hemijska",
    "broj_telefona": "0642351663",
    "broj_telefona_oca": null,
    "broj_telefona_majke": "0642717071",
    "polasci_po_danu": {},
    "adresa_bela_crkva": "Vojske Jugoslavije",
    "adresa_vrsac": "Dis",
    "tip_prikazivanja": "standard",
    "radni_dani": "pon,uto,sre,cet,pet",
    "aktivan": true,
    "status": "aktivan",
    "datum_pocetka_meseca": "2025-10-01",
    "datum_kraja_meseca": "2025-10-31",
    "ukupna_cena_meseca": 0,
    "cena": 0,
    "broj_putovanja": 0,
    "broj_otkazivanja": 0,
    "poslednje_putovanje": null,
    "vreme_placanja": "2025-10-21T21:31:08.990597+00:00",
    "placeni_mesec": 9,
    "placena_godina": 2025,
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "pokupljen": false,
    "vreme_pokupljenja": null,
    "statistics": {
      "last_trip": null,
      "trips_total": 0,
      "cancellations_total": 0
    },
    "obrisan": false,
    "created_at": "2025-10-20T22:31:55.679573+00:00",
    "updated_at": "2025-10-21T21:31:08.990643+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_polaska_id": null,
    "adresa_dolaska_id": null,
    "ime": null,
    "prezime": null,
    "datum_pocetka": null,
    "datum_kraja": null
  },
  {
    "id": "2aca338b-3178-4f2b-80c3-026e970ce26e",
    "putnik_ime": "Marina Bihler",
    "tip": "radnik",
    "tip_skole": "Gradic Pejton",
    "broj_telefona": "0607140492",
    "broj_telefona_oca": null,
    "broj_telefona_majke": null,
    "polasci_po_danu": {},
    "adresa_bela_crkva": null,
    "adresa_vrsac": null,
    "tip_prikazivanja": "standard",
    "radni_dani": "pon,uto,sre,cet,pet",
    "aktivan": true,
    "status": "aktivan",
    "datum_pocetka_meseca": "2025-10-01",
    "datum_kraja_meseca": "2025-10-31",
    "ukupna_cena_meseca": 0,
    "cena": 0,
    "broj_putovanja": 0,
    "broj_otkazivanja": 0,
    "poslednje_putovanje": null,
    "vreme_placanja": "2025-10-21T21:08:43.294839+00:00",
    "placeni_mesec": 9,
    "placena_godina": 2025,
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "pokupljen": false,
    "vreme_pokupljenja": null,
    "statistics": {
      "last_trip": null,
      "trips_total": 0,
      "cancellations_total": 0
    },
    "obrisan": false,
    "created_at": "2025-10-20T12:21:33.116075+00:00",
    "updated_at": "2025-10-21T21:08:43.294968+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_polaska_id": null,
    "adresa_dolaska_id": null,
    "ime": null,
    "prezime": null,
    "datum_pocetka": null,
    "datum_kraja": null
  },
  {
    "id": "c2630b45-fa8a-4a54-ae7e-21cc02ce7c30",
    "putnik_ime": "Maja Pesic",
    "tip": "radnik",
    "tip_skole": null,
    "broj_telefona": "0600570133",
    "broj_telefona_oca": null,
    "broj_telefona_majke": null,
    "polasci_po_danu": {},
    "adresa_bela_crkva": "Dejana Brankova 99",
    "adresa_vrsac": "Sud",
    "tip_prikazivanja": "standard",
    "radni_dani": "pon,uto,sre,cet,pet",
    "aktivan": true,
    "status": "aktivan",
    "datum_pocetka_meseca": "2025-10-01",
    "datum_kraja_meseca": "2025-10-31",
    "ukupna_cena_meseca": 7000,
    "cena": 7000,
    "broj_putovanja": 0,
    "broj_otkazivanja": 0,
    "poslednje_putovanje": null,
    "vreme_placanja": "2025-10-20T22:12:55.675129+00:00",
    "placeni_mesec": 10,
    "placena_godina": 2025,
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "pokupljen": false,
    "vreme_pokupljenja": null,
    "statistics": {
      "last_trip": null,
      "trips_total": 0,
      "cancellations_total": 0
    },
    "obrisan": false,
    "created_at": "2025-10-20T22:12:38.069296+00:00",
    "updated_at": "2025-10-20T22:12:55.675189+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_polaska_id": null,
    "adresa_dolaska_id": null,
    "ime": null,
    "prezime": null,
    "datum_pocetka": null,
    "datum_kraja": null
  }
]
```

### 🔸 TABLE: `dnevni_putnici`
- **Rows**: 0+ (showing first 5)
### 🔸 TABLE: `vozaci`
- **Rows**: 4+ (showing first 5)
- **Columns**: 8
- **Column Names**: id, ime, email, telefon, aktivan, created_at, updated_at, kusur

**Column Details:**
- `id`: string (e.g., "8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f")
- `ime`: string (e.g., "Bilevski")
- `email`: null
- `telefon`: null
- `aktivan`: boolean (e.g., true)
- `created_at`: string (e.g., "2025-10-03T18:10:38.27787+00:00")
- `updated_at`: string (e.g., "2025-10-03T18:10:38.27787+00:00")
- `kusur`: number (e.g., 0)

**Sample Records:**
```json
[
  {
    "id": "8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f",
    "ime": "Bilevski",
    "email": null,
    "telefon": null,
    "aktivan": true,
    "created_at": "2025-10-03T18:10:38.27787+00:00",
    "updated_at": "2025-10-03T18:10:38.27787+00:00",
    "kusur": 0
  },
  {
    "id": "5b379394-084e-1c7d-76bf-fc193a5b6c7d",
    "ime": "Svetlana",
    "email": null,
    "telefon": null,
    "aktivan": true,
    "created_at": "2025-10-03T18:10:38.27787+00:00",
    "updated_at": "2025-10-03T18:10:38.27787+00:00",
    "kusur": 0
  },
  {
    "id": "7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f",
    "ime": "Bruda",
    "email": null,
    "telefon": null,
    "aktivan": true,
    "created_at": "2025-10-03T18:10:38.27787+00:00",
    "updated_at": "2025-10-03T18:10:38.27787+00:00",
    "kusur": 0
  }
]
```

### 🔸 TABLE: `vozila`
- **Rows**: 0+ (showing first 5)
### 🔸 TABLE: `rute`
- **Rows**: 0+ (showing first 5)
### 🔸 TABLE: `gps_lokacije`
- **Rows**: 5+ (showing first 5)
- **Columns**: 9
- **Column Names**: id, vozac_id, vozilo_id, latitude, longitude, brzina, pravac, tacnost, vreme

**Column Details:**
- `id`: string (e.g., "ce792b68-7359-424e-8941-59b6221ce562")
- `vozac_id`: string (e.g., "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e")
- `vozilo_id`: null
- `latitude`: number (e.g., 44.9006466)
- `longitude`: number (e.g., 21.4152327)
- `brzina`: number (e.g., 0)
- `pravac`: number (e.g., 0)
- `tacnost`: number (e.g., 20)
- `vreme`: string (e.g., "2025-10-03T18:11:31.85077+00:00")

**Sample Records:**
```json
[
  {
    "id": "ce792b68-7359-424e-8941-59b6221ce562",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "vozilo_id": null,
    "latitude": 44.9006466,
    "longitude": 21.4152327,
    "brzina": 0,
    "pravac": 0,
    "tacnost": 20,
    "vreme": "2025-10-03T18:11:31.85077+00:00"
  },
  {
    "id": "ae0afef8-cf26-4f98-92d0-e0ca386e494a",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "vozilo_id": null,
    "latitude": 44.9006466,
    "longitude": 21.4152327,
    "brzina": 0,
    "pravac": 0,
    "tacnost": 20,
    "vreme": "2025-10-03T18:12:31.302314+00:00"
  },
  {
    "id": "f48b96b9-83de-4365-91a0-0bdab1e9b916",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "vozilo_id": null,
    "latitude": 44.9006467,
    "longitude": 21.4152327,
    "brzina": 0,
    "pravac": 0,
    "tacnost": 20,
    "vreme": "2025-10-03T18:13:31.412259+00:00"
  }
]
```

### 🔸 TABLE: `putovanja_istorija`
- **Rows**: 5+ (showing first 5)
- **Columns**: 16
- **Column Names**: id, mesecni_putnik_id, datum_putovanja, vreme_polaska, status, vozac_id, napomene, obrisan, created_at, updated_at, ruta_id, vozilo_id, adresa_id, cena, tip_putnika, putnik_ime

**Column Details:**
- `id`: string (e.g., "32d48c09-a49a-4530-9227-96bc488f9cf8")
- `mesecni_putnik_id`: string (e.g., "e0f97b70-157f-447c-ab83-0521b2fc338f")
- `datum_putovanja`: string (e.g., "2025-10-20")
- `vreme_polaska`: string (e.g., "mesecno_placanje")
- `status`: string (e.g., "placeno")
- `vozac_id`: string (e.g., "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e")
- `napomene`: string (e.g., "Mesečno plaćanje za 10/2025")
- `obrisan`: boolean (e.g., false)
- `created_at`: string (e.g., "2025-10-20T20:56:53.23053+00:00")
- `updated_at`: string (e.g., "2025-10-20T20:56:53.23053+00:00")
- `ruta_id`: null
- `vozilo_id`: null
- `adresa_id`: null
- `cena`: number (e.g., 4200)
- `tip_putnika`: string (e.g., "mesecni")
- `putnik_ime`: string (e.g., "Violeta Lazic")

**Sample Records:**
```json
[
  {
    "id": "32d48c09-a49a-4530-9227-96bc488f9cf8",
    "mesecni_putnik_id": "e0f97b70-157f-447c-ab83-0521b2fc338f",
    "datum_putovanja": "2025-10-20",
    "vreme_polaska": "mesecno_placanje",
    "status": "placeno",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "napomene": "Mesečno plaćanje za 10/2025",
    "obrisan": false,
    "created_at": "2025-10-20T20:56:53.23053+00:00",
    "updated_at": "2025-10-20T20:56:53.23053+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_id": null,
    "cena": 4200,
    "tip_putnika": "mesecni",
    "putnik_ime": "Violeta Lazic"
  },
  {
    "id": "375add2b-0ae2-4877-ab1f-c43020cba552",
    "mesecni_putnik_id": "bb33972a-676a-4d6d-a0dd-898eec1eaa32",
    "datum_putovanja": "2025-10-13",
    "vreme_polaska": "mesecno_placanje",
    "status": "placeno",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "napomene": "Mesečno plaćanje za 10/2025",
    "obrisan": false,
    "created_at": "2025-10-13T19:02:11.560232+00:00",
    "updated_at": "2025-10-13T19:02:11.560232+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_id": null,
    "cena": 14000,
    "tip_putnika": "mesecni",
    "putnik_ime": "Jovan Todorovic"
  },
  {
    "id": "383f2a0e-a0ea-4c72-8e65-46e1f2242fdd",
    "mesecni_putnik_id": "c048e395-5491-44a6-855b-694a640a3a76",
    "datum_putovanja": "2025-10-17",
    "vreme_polaska": "mesecno_placanje",
    "status": "placeno",
    "vozac_id": "6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e",
    "napomene": "Mesečno plaćanje za 10/2025",
    "obrisan": false,
    "created_at": "2025-10-17T19:35:37.344325+00:00",
    "updated_at": "2025-10-17T19:35:37.344325+00:00",
    "ruta_id": null,
    "vozilo_id": null,
    "adresa_id": null,
    "cena": 12000,
    "tip_putnika": "mesecni",
    "putnik_ime": "Ogi"
  }
]
```

### 🔸 TABLE: `adrese`
- **Rows**: 0+ (showing first 5)
## 🔗 CONNECTION STATUS
- **Auth Status**: Connected
- **Session**: Active

## ✅ SCHEMA ANALYSIS COMPLETE
**Generated**: 10/25/2025, 4:04:20 PM
**Tables Found**: 8
**Status**: SUCCESS
