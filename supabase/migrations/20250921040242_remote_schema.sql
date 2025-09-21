

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."azuriraj_statistike_mesecnog_putnika"("putnik_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE public.mesecni_putnici 
    SET 
        broj_putovanja = get_broj_putovanja_za_mesecnog(putnik_id),
        broj_otkazivanja = (
            SELECT COUNT(DISTINCT datum)
            FROM public.putovanja_istorija 
            WHERE mesecni_putnik_id = putnik_id
            AND status_bela_crkva_vrsac = 'otkazao_poziv' 
            AND status_vrsac_bela_crkva = 'otkazao_poziv'
        ),
        poslednje_putovanje = (
            SELECT MAX(datum)
            FROM public.putovanja_istorija 
            WHERE mesecni_putnik_id = putnik_id
            AND (status_bela_crkva_vrsac = 'pokupljen' OR status_vrsac_bela_crkva = 'pokupljen')
        ),
        updated_at = timezone('utc'::text, now())
    WHERE id = putnik_id;
END;
$$;


ALTER FUNCTION "public"."azuriraj_statistike_mesecnog_putnika"("putnik_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_putovanja_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO notification_queue(table_name, event_type, payload)
    VALUES ('putovanja_istorija', 'insert', to_jsonb(NEW));
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enqueue_putovanja_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_broj_putovanja_za_mesecnog"("putnik_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT datum)
        FROM public.putovanja_istorija 
        WHERE mesecni_putnik_id = putnik_id
        AND (status_bela_crkva_vrsac = 'pokupljen' OR status_vrsac_bela_crkva = 'pokupljen')
    );
END;
$$;


ALTER FUNCTION "public"."get_broj_putovanja_za_mesecnog"("putnik_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_latest_gps_locations"() RETURNS TABLE("vozac_id" "text", "lat" double precision, "lng" double precision, "gps_timestamp" timestamp with time zone)
    LANGUAGE "sql"
    AS $$
    select distinct on (vozac_id) vozac_id, lat, lng, timestamp as gps_timestamp
    from gps_lokacije
    order by vozac_id, timestamp desc
$$;


ALTER FUNCTION "public"."get_latest_gps_locations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_week_month_year"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.nedelja = EXTRACT(WEEK FROM NEW.datum_voznje);
    NEW.mesec = EXTRACT(MONTH FROM NEW.datum_voznje);
    NEW.godina = EXTRACT(YEAR FROM NEW.datum_voznje);
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_week_month_year"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."daily_checkins" (
    "id" bigint NOT NULL,
    "vozac" "text" NOT NULL,
    "datum" "date" NOT NULL,
    "kusur_iznos" numeric(10,2) DEFAULT 0.0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "daily_checkins_kusur_positive" CHECK (("kusur_iznos" >= (0)::numeric))
);


ALTER TABLE "public"."daily_checkins" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."daily_checkins_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."daily_checkins_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."daily_checkins_id_seq" OWNED BY "public"."daily_checkins"."id";



CREATE TABLE IF NOT EXISTS "public"."daily_reports" (
    "id" integer NOT NULL,
    "vozac" character varying(50) NOT NULL,
    "datum" "date" NOT NULL,
    "ukupan_pazar" numeric(10,2) DEFAULT 0.00,
    "sitan_novac" numeric(10,2) DEFAULT 0.00,
    "dnevni_pazari" numeric(10,2) DEFAULT 0.00,
    "dodati_putnici" integer DEFAULT 0,
    "otkazani_putnici" integer DEFAULT 0,
    "naplaceni_putnici" integer DEFAULT 0,
    "pokupljeni_putnici" integer DEFAULT 0,
    "dugovi_putnici" integer DEFAULT 0,
    "mesecne_karte" integer DEFAULT 0,
    "kilometraza" numeric(8,2) DEFAULT 0.00,
    "automatski_generisan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."daily_reports" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."daily_reports_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."daily_reports_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."daily_reports_id_seq" OWNED BY "public"."daily_reports"."id";



CREATE TABLE IF NOT EXISTS "public"."gps_lokacije" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL,
    "lat" double precision NOT NULL,
    "lng" double precision NOT NULL,
    "timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "color" "text",
    "vehicle_type" "text"
);


ALTER TABLE "public"."gps_lokacije" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."gps_lokacije_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."gps_lokacije_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."gps_lokacije_id_seq" OWNED BY "public"."gps_lokacije"."id";



CREATE TABLE IF NOT EXISTS "public"."mesecni_putnici" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_ime" "text" NOT NULL,
    "tip" "text" NOT NULL,
    "tip_skole" "text",
    "broj_telefona" "text",
    "adresa_bela_crkva" "text",
    "adresa_vrsac" "text",
    "tip_prikazivanja" "text" DEFAULT 'fiksan'::"text" NOT NULL,
    "radni_dani" "text" DEFAULT 'pon,uto,sre,cet,pet'::"text" NOT NULL,
    "aktivan" boolean DEFAULT true NOT NULL,
    "datum_pocetka_meseca" "date" NOT NULL,
    "datum_kraja_meseca" "date" NOT NULL,
    "broj_putovanja" integer DEFAULT 0 NOT NULL,
    "broj_otkazivanja" integer DEFAULT 0 NOT NULL,
    "poslednje_putovanje" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "obrisan" boolean DEFAULT false,
    "pokupljen" boolean DEFAULT false,
    "vreme_pokupljenja" timestamp with time zone,
    "vreme_placanja" timestamp with time zone,
    "vozac" "text",
    "cena" numeric(10,2),
    "status" "text",
    "pokupljanje_vozac" "text",
    "naplata_vozac" "text",
    "otkazao_vozac" "text",
    "dodao_vozac" "text",
    "placeni_mesec" integer,
    "placena_godina" integer,
    "sitan_novac" "text",
    "polazak_bc_pon" time without time zone,
    "polazak_bc_uto" time without time zone,
    "polazak_bc_sre" time without time zone,
    "polazak_bc_cet" time without time zone,
    "polazak_bc_pet" time without time zone,
    "polazak_vs_pon" time without time zone,
    "polazak_vs_uto" time without time zone,
    "polazak_vs_sre" time without time zone,
    "polazak_vs_cet" time without time zone,
    "polazak_vs_pet" time without time zone,
    "polasci_po_danu" "jsonb",
    "radni_dani_arr" "text"[],
    "cena_numeric" numeric,
    "statistics" "jsonb",
    CONSTRAINT "mesecni_putnici_tip_check" CHECK (("tip" = ANY (ARRAY['radnik'::"text", 'ucenik'::"text"]))),
    CONSTRAINT "mesecni_putnici_tip_prikazivanja_check" CHECK (("tip_prikazivanja" = ANY (ARRAY['fiksan'::"text", 'preporucen'::"text", 'manual'::"text"])))
);


ALTER TABLE "public"."mesecni_putnici" OWNER TO "postgres";


COMMENT ON COLUMN "public"."mesecni_putnici"."obrisan" IS 'Soft delete flag - true znači da je putnik obrisan ali se čuva istorija';



COMMENT ON COLUMN "public"."mesecni_putnici"."placeni_mesec" IS 'Mesec za koji je plaćeno (1-12)';



COMMENT ON COLUMN "public"."mesecni_putnici"."placena_godina" IS 'Godina za koju je plaćeno';



CREATE TABLE IF NOT EXISTS "public"."notification_queue" (
    "id" bigint NOT NULL,
    "table_name" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "processed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_queue" OWNER TO "postgres";


ALTER TABLE "public"."notification_queue" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."notification_queue_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."putovanja_istorija" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "mesecni_putnik_id" "uuid",
    "tip_putnika" "text" NOT NULL,
    "datum" "date" NOT NULL,
    "vreme_polaska" time without time zone NOT NULL,
    "adresa_polaska" "text" NOT NULL,
    "putnik_ime" "text" NOT NULL,
    "broj_telefona" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "status" "text",
    "pokupljen" boolean DEFAULT false,
    "vreme_pokupljenja" timestamp with time zone,
    "vreme_placanja" timestamp with time zone,
    "vozac" "text",
    "dan" "text",
    "grad" "text",
    "obrisan" "text",
    "cena" "text",
    "pokupljanje_vozac" "text",
    "naplata_vozac" "text",
    "otkazao_vozac" "text",
    "dodao_vozac" "text",
    "sitan_novac" "text",
    CONSTRAINT "putovanja_istorija_tip_putnika_check" CHECK (("tip_putnika" = ANY (ARRAY['mesecni'::"text", 'dnevni'::"text"])))
);


ALTER TABLE "public"."putovanja_istorija" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usage_aggregate" (
    "service" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "count" bigint DEFAULT 0 NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."usage_aggregate" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usage_alerts" (
    "id" bigint NOT NULL,
    "service" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "observed_count" bigint NOT NULL,
    "limit_count" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "handled" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."usage_alerts" OWNER TO "postgres";


ALTER TABLE "public"."usage_alerts" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."usage_alerts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."usage_limits" (
    "service" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "limit_count" bigint NOT NULL,
    "period_seconds" integer DEFAULT 2592000 NOT NULL,
    "last_reset_at" timestamp with time zone
);


ALTER TABLE "public"."usage_limits" OWNER TO "postgres";


ALTER TABLE ONLY "public"."daily_checkins" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."daily_checkins_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."daily_reports" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."daily_reports_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."gps_lokacije" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."gps_lokacije_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_unique_vozac_datum" UNIQUE ("vozac", "datum");



ALTER TABLE ONLY "public"."daily_reports"
    ADD CONSTRAINT "daily_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_reports"
    ADD CONSTRAINT "daily_reports_vozac_datum_key" UNIQUE ("vozac", "datum");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_queue"
    ADD CONSTRAINT "notification_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usage_aggregate"
    ADD CONSTRAINT "usage_aggregate_pkey" PRIMARY KEY ("service", "event_type");



ALTER TABLE ONLY "public"."usage_alerts"
    ADD CONSTRAINT "usage_alerts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usage_limits"
    ADD CONSTRAINT "usage_limits_pkey" PRIMARY KEY ("service", "event_type");



CREATE INDEX "idx_daily_checkins_datum" ON "public"."daily_checkins" USING "btree" ("datum");



CREATE INDEX "idx_daily_checkins_vozac" ON "public"."daily_checkins" USING "btree" ("vozac");



CREATE INDEX "idx_mesecni_putnici_aktivan" ON "public"."mesecni_putnici" USING "btree" ("aktivan");



CREATE INDEX "idx_mesecni_putnici_datum_meseca" ON "public"."mesecni_putnici" USING "btree" ("datum_pocetka_meseca", "datum_kraja_meseca");



CREATE INDEX "idx_mesecni_putnici_obrisan" ON "public"."mesecni_putnici" USING "btree" ("obrisan");



CREATE INDEX "idx_mesecni_putnici_polasci_gin" ON "public"."mesecni_putnici" USING "gin" ("polasci_po_danu" "jsonb_path_ops");



CREATE INDEX "idx_mesecni_putnici_radni_dani_gin" ON "public"."mesecni_putnici" USING "gin" ("radni_dani_arr");



CREATE INDEX "idx_mesecni_putnici_statistics_gin" ON "public"."mesecni_putnici" USING "gin" ("statistics" "jsonb_path_ops");



CREATE INDEX "idx_mesecni_putnici_tip" ON "public"."mesecni_putnici" USING "btree" ("tip");



CREATE INDEX "idx_notification_queue_processed" ON "public"."notification_queue" USING "btree" ("processed") WHERE ("processed" = false);



CREATE INDEX "idx_putovanja_istorija_dan" ON "public"."putovanja_istorija" USING "btree" ("dan");



CREATE INDEX "idx_putovanja_istorija_datum" ON "public"."putovanja_istorija" USING "btree" ("datum");



CREATE INDEX "idx_putovanja_istorija_datum_desc" ON "public"."putovanja_istorija" USING "btree" ("datum" DESC);



CREATE INDEX "idx_putovanja_istorija_grad" ON "public"."putovanja_istorija" USING "btree" ("grad");



CREATE INDEX "idx_putovanja_istorija_mesecni_datum" ON "public"."putovanja_istorija" USING "btree" ("mesecni_putnik_id", "datum") WHERE ("mesecni_putnik_id" IS NOT NULL);



CREATE INDEX "idx_putovanja_istorija_mesecni_putnik" ON "public"."putovanja_istorija" USING "btree" ("mesecni_putnik_id");



CREATE INDEX "idx_putovanja_istorija_tip_putnika" ON "public"."putovanja_istorija" USING "btree" ("tip_putnika");



CREATE INDEX "idx_putovanja_istorija_vreme_polaska" ON "public"."putovanja_istorija" USING "btree" ("vreme_polaska");



CREATE OR REPLACE TRIGGER "tr_enqueue_putovanja_notification" AFTER INSERT ON "public"."putovanja_istorija" FOR EACH ROW EXECUTE FUNCTION "public"."enqueue_putovanja_notification"();



CREATE OR REPLACE TRIGGER "update_mesecni_putnici_updated_at" BEFORE UPDATE ON "public"."mesecni_putnici" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_putovanja_istorija_updated_at" BEFORE UPDATE ON "public"."putovanja_istorija" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_mesecni_putnik_id_fkey" FOREIGN KEY ("mesecni_putnik_id") REFERENCES "public"."mesecni_putnici"("id") ON DELETE SET NULL;



CREATE POLICY "Allow all operations on mesecni_putnici" ON "public"."mesecni_putnici" USING (true) WITH CHECK (true);



CREATE POLICY "Allow anonymous read mesecni_putnici" ON "public"."mesecni_putnici" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anonymous read putovanja_istorija" ON "public"."putovanja_istorija" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anonymous write mesecni_putnici" ON "public"."mesecni_putnici" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow anonymous write putovanja_istorija" ON "public"."putovanja_istorija" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow insert for all users" ON "public"."putovanja_istorija" FOR INSERT WITH CHECK (true);



CREATE POLICY "Enable all access for authenticated users" ON "public"."mesecni_putnici" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Enable all access for authenticated users" ON "public"."putovanja_istorija" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "allow_delete_putovanja_istorija" ON "public"."putovanja_istorija" FOR DELETE USING (true);



CREATE POLICY "allow_insert_putovanja_istorija" ON "public"."putovanja_istorija" FOR INSERT WITH CHECK (true);



CREATE POLICY "allow_select_putovanja_istorija" ON "public"."putovanja_istorija" FOR SELECT USING (true);



CREATE POLICY "allow_update_putovanja_istorija" ON "public"."putovanja_istorija" FOR UPDATE USING (true);



CREATE POLICY "dozvoli sve" ON "public"."gps_lokacije" USING (true) WITH CHECK (true);



ALTER TABLE "public"."gps_lokacije" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mesecni_putnici" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."putovanja_istorija" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."gps_lokacije";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."mesecni_putnici";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."putovanja_istorija";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."azuriraj_statistike_mesecnog_putnika"("putnik_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."azuriraj_statistike_mesecnog_putnika"("putnik_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."azuriraj_statistike_mesecnog_putnika"("putnik_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."enqueue_putovanja_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."enqueue_putovanja_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enqueue_putovanja_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_broj_putovanja_za_mesecnog"("putnik_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_broj_putovanja_za_mesecnog"("putnik_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_broj_putovanja_za_mesecnog"("putnik_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_latest_gps_locations"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_latest_gps_locations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_latest_gps_locations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_week_month_year"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_week_month_year"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_week_month_year"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."daily_checkins" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins" TO "service_role";



GRANT ALL ON SEQUENCE "public"."daily_checkins_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."daily_checkins_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."daily_checkins_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."daily_reports" TO "anon";
GRANT ALL ON TABLE "public"."daily_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."daily_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."daily_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."daily_reports_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "service_role";



GRANT ALL ON SEQUENCE "public"."gps_lokacije_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."gps_lokacije_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."gps_lokacije_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."mesecni_putnici" TO "anon";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "authenticated";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "service_role";



GRANT ALL ON TABLE "public"."notification_queue" TO "anon";
GRANT ALL ON TABLE "public"."notification_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_queue" TO "service_role";



GRANT ALL ON SEQUENCE "public"."notification_queue_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notification_queue_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notification_queue_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."putovanja_istorija" TO "anon";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "authenticated";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "service_role";



GRANT ALL ON TABLE "public"."usage_aggregate" TO "anon";
GRANT ALL ON TABLE "public"."usage_aggregate" TO "authenticated";
GRANT ALL ON TABLE "public"."usage_aggregate" TO "service_role";



GRANT ALL ON TABLE "public"."usage_alerts" TO "anon";
GRANT ALL ON TABLE "public"."usage_alerts" TO "authenticated";
GRANT ALL ON TABLE "public"."usage_alerts" TO "service_role";



GRANT ALL ON SEQUENCE "public"."usage_alerts_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."usage_alerts_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."usage_alerts_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."usage_limits" TO "anon";
GRANT ALL ON TABLE "public"."usage_limits" TO "authenticated";
GRANT ALL ON TABLE "public"."usage_limits" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
