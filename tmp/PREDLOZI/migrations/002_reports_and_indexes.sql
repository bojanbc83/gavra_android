-- 002_reports_and_indexes.sql
-- Indexes, materialized views, functions, triggers (separate migration)

-- Indexes
CREATE INDEX IF NOT EXISTS idx_rides_scheduled_departure ON rides (scheduled_departure);
CREATE INDEX IF NOT EXISTS idx_trips_passenger_id ON trips (passenger_id);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments (paid_at);
CREATE INDEX IF NOT EXISTS idx_driver_logs_date ON driver_logs (log_date);
CREATE INDEX IF NOT EXISTS idx_monthly_passengers_user_id ON monthly_passengers (user_id);

-- Materialized view: monthly passenger summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_passenger_summary AS
SELECT
    mp.id as monthly_passenger_id,
    u.id as user_id,
    u.full_name,
    DATE_TRUNC('month', t.created_at) as month,
    SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed_trips,
    SUM(CASE WHEN t.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_trips,
    COALESCE(SUM(p.amount),0) as total_paid
FROM monthly_passengers mp
JOIN users u ON mp.user_id = u.id
LEFT JOIN trips t ON u.id = t.passenger_id
LEFT JOIN payments p ON p.trip_id = t.id
GROUP BY mp.id, u.id, u.full_name, DATE_TRUNC('month', t.created_at);

-- Materialized view: driver daily summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_driver_daily_summary AS
SELECT
    dl.driver_id,
    dl.log_date,
    SUM(dl.pickups) as pickups,
    SUM(dl.cancellations) as cancellations,
    SUM(dl.takings) as takings,
    SUM(dl.kilometers) as kilometers
FROM driver_logs dl
GROUP BY dl.driver_id, dl.log_date;

-- Helper function to refresh materialized views (non-CONCURRENT; safe inside functions/transactions)
CREATE OR REPLACE FUNCTION refresh_reports() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Use non-CONCURRENT refresh here because PL/pgSQL functions run inside a transaction
    -- and `REFRESH MATERIALIZED VIEW CONCURRENTLY` is not allowed inside a transaction block.
    REFRESH MATERIALIZED VIEW mv_monthly_passenger_summary;
    REFRESH MATERIALIZED VIEW mv_driver_daily_summary;
END; $$;

-- Trigger to update updated_at on users
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_updated_at ON users;
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes on materialized views to support fast lookups and CONCURRENT refresh
-- Note: To use `REFRESH MATERIALIZED VIEW CONCURRENTLY` the materialized view must have
-- a UNIQUE index that can identify rows; the following unique indexes enable that.
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_monthly_passenger_summary_passenger_month ON mv_monthly_passenger_summary (monthly_passenger_id, month);
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_driver_daily_summary_driver_date ON mv_driver_daily_summary (driver_id, log_date);

-- If you want to perform a CONCURRENT refresh (non-blocking for readers), run from psql
-- or the Supabase SQL Editor directly (NOT from inside a PL/pgSQL function):
-- psql example (PowerShell):
-- $env:PGPASSWORD='YOUR_PASSWORD'
-- psql "host=HOST user=USER dbname=postgres port=5432 sslmode=require" -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_passenger_summary;"
-- If the CONCURRENT refresh fails (for example due to missing unique index or other reasons),
-- you can then run the non-concurrent refresh function:
-- psql -c "SELECT refresh_reports();"

-- Notes: run `SELECT refresh_reports();` after large data loads or schedule it nightly if
-- you prefer the simpler (blocking) refresh from within the database.

-- Notes: run `refresh_reports()` after large data loads or schedule it nightly.
