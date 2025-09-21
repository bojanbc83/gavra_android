-- 20250921_triggers_sync_putovanja.sql
-- Triggers to keep dozvoljeni_mesecni_putnici counters in sync with putovanja_istorija
BEGIN;

-- Function to handle insert into putovanja_istorija
CREATE OR REPLACE FUNCTION public.fn_putovanja_insert_trigger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.mesecni_putnik_id IS NOT NULL) THEN
    IF (NEW.status IS NULL OR NEW.status <> 'otkazano') THEN
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_putovanja = COALESCE(broj_putovanja,0) + 1,
          poslednje_putovanje = GREATEST(COALESCE(poslednje_putovanje, 'epoch'::timestamp), NEW.created_at)
      WHERE id = NEW.mesecni_putnik_id;
    ELSE
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_otkazivanja = COALESCE(broj_otkazivanja,0) + 1
      WHERE id = NEW.mesecni_putnik_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Function to handle delete from putovanja_istorija (best-effort decrement)
CREATE OR REPLACE FUNCTION public.fn_putovanja_delete_trigger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (OLD.mesecni_putnik_id IS NOT NULL) THEN
    IF (OLD.status IS NULL OR OLD.status <> 'otkazano') THEN
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_putovanja = GREATEST(COALESCE(broj_putovanja,0) - 1, 0)
      WHERE id = OLD.mesecni_putnik_id;
    ELSE
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_otkazivanja = GREATEST(COALESCE(broj_otkazivanja,0) - 1, 0)
      WHERE id = OLD.mesecni_putnik_id;
    END IF;
  END IF;
  RETURN OLD;
END;
$$;

-- Function to handle update: adjust counters if status changed or mesecni_putnik_id changed
CREATE OR REPLACE FUNCTION public.fn_putovanja_update_trigger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- If mesecni_putnik_id changed, decrement old counters and increment new
  IF (OLD.mesecni_putnik_id IS NOT NULL AND NEW.mesecni_putnik_id IS DISTINCT FROM OLD.mesecni_putnik_id) THEN
    -- decrement old
    IF (OLD.status IS NULL OR OLD.status <> 'otkazano') THEN
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_putovanja = GREATEST(COALESCE(broj_putovanja,0) - 1, 0)
      WHERE id = OLD.mesecni_putnik_id;
    ELSE
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_otkazivanja = GREATEST(COALESCE(broj_otkazivanja,0) - 1, 0)
      WHERE id = OLD.mesecni_putnik_id;
    END IF;

    -- increment new
    IF (NEW.status IS NULL OR NEW.status <> 'otkazano') THEN
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_putovanja = COALESCE(broj_putovanja,0) + 1
      WHERE id = NEW.mesecni_putnik_id;
    ELSE
      UPDATE public.dozvoljeni_mesecni_putnici
      SET broj_otkazivanja = COALESCE(broj_otkazivanja,0) + 1
      WHERE id = NEW.mesecni_putnik_id;
    END IF;
  ELSE
    -- If status changed for same mesecni_putnik_id, adjust accordingly
    IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.mesecni_putnik_id IS NOT NULL) THEN
      -- If old was 'otkazano' and new is not -> move from otkazivanja to realizovano
      IF (OLD.status = 'otkazano' AND (NEW.status IS NULL OR NEW.status <> 'otkazano')) THEN
        UPDATE public.dozvoljeni_mesecni_putnici
        SET broj_otkazivanja = GREATEST(COALESCE(broj_otkazivanja,0) - 1, 0),
            broj_putovanja = COALESCE(broj_putovanja,0) + 1
        WHERE id = NEW.mesecni_putnik_id;
      ELSIF (NEW.status = 'otkazano' AND (OLD.status IS NULL OR OLD.status <> 'otkazano')) THEN
        UPDATE public.dozvoljeni_mesecni_putnici
        SET broj_putovanja = GREATEST(COALESCE(broj_putovanja,0) - 1, 0),
            broj_otkazivanja = COALESCE(broj_otkazivanja,0) + 1
        WHERE id = NEW.mesecni_putnik_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Attach triggers
DROP TRIGGER IF EXISTS trg_putovanja_insert_sync ON public.putovanja_istorija;
CREATE TRIGGER trg_putovanja_insert_sync AFTER INSERT ON public.putovanja_istorija
FOR EACH ROW EXECUTE FUNCTION public.fn_putovanja_insert_trigger();

DROP TRIGGER IF EXISTS trg_putovanja_delete_sync ON public.putovanja_istorija;
CREATE TRIGGER trg_putovanja_delete_sync AFTER DELETE ON public.putovanja_istorija
FOR EACH ROW EXECUTE FUNCTION public.fn_putovanja_delete_trigger();

DROP TRIGGER IF EXISTS trg_putovanja_update_sync ON public.putovanja_istorija;
CREATE TRIGGER trg_putovanja_update_sync AFTER UPDATE ON public.putovanja_istorija
FOR EACH ROW EXECUTE FUNCTION public.fn_putovanja_update_trigger();

COMMIT;
