# 📊 SUPABASE DATABASE COMPLETE ANALYSIS
**Date**: 2025-10-25T13:57:36.624Z
**Project**: gjtabtwudbrmfeyjiicu
**URL**: https://gjtabtwudbrmfeyjiicu.supabase.co

## 🔑 CREDENTIALS
- **ANON KEY**: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk
- **SERVICE ROLE**: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4
- **PASSWORD**: FlqfvHczUpSytgrV

---

## 📋 MANUAL TABLE LIST (8)
Checking: mesecni_putnici, dnevni_putnici, vozaci, vozila, rute, gps_lokacije, putovanja_istorija, adrese

### 🔸 TABLE: `mesecni_putnici`
- **Row Count**: 5+ rows
- **Columns (39)**: id, putnik_ime, tip, tip_skole, broj_telefona, broj_telefona_oca, broj_telefona_majke, polasci_po_danu, adresa_bela_crkva, adresa_vrsac, tip_prikazivanja, radni_dani, aktivan, status, datum_pocetka_meseca, datum_kraja_meseca, ukupna_cena_meseca, cena, broj_putovanja, broj_otkazivanja, poslednje_putovanje, vreme_placanja, placeni_mesec, placena_godina, vozac_id, pokupljen, vreme_pokupljenja, statistics, obrisan, created_at, updated_at, ruta_id, vozilo_id, adresa_polaska_id, adresa_dolaska_id, ime, prezime, datum_pocetka, datum_kraja

**Sample Data:**
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
  }
]
```

### 🔸 TABLE: `dnevni_putnici`
- **Row Count**: 0+ rows
### 🔸 TABLE: `vozaci`
- **Row Count**: 4+ rows
- **Columns (8)**: id, ime, email, telefon, aktivan, created_at, updated_at, kusur

**Sample Data:**
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
  }
]
```

### 🔸 TABLE: `vozila`
- **Row Count**: 0+ rows
### 🔸 TABLE: `rute`
- **Row Count**: 0+ rows
### 🔸 TABLE: `gps_lokacije`
- **Row Count**: 5+ rows
- **Columns (9)**: id, vozac_id, vozilo_id, latitude, longitude, brzina, pravac, tacnost, vreme

**Sample Data:**
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
  }
]
```

### 🔸 TABLE: `putovanja_istorija`
- **Row Count**: 5+ rows
- **Columns (16)**: id, mesecni_putnik_id, datum_putovanja, vreme_polaska, status, vozac_id, napomene, obrisan, created_at, updated_at, ruta_id, vozilo_id, adresa_id, cena, tip_putnika, putnik_ime

**Sample Data:**
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
  }
]
```

### 🔸 TABLE: `adrese`
- **Row Count**: 0+ rows
## ✅ ANALYSIS COMPLETE
**Generated**: 10/25/2025, 3:57:39 PM
**Status**: SUCCESS
**Total Tables Analyzed**: 8
