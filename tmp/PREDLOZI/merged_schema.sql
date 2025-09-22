-- Merged schema (based on PREDLOG 1..4)
-- Uses UUIDs, timestamptz, relational schedules, bookings, payments, and driver logs.

-- Enable uuid-ossp or pgcrypto depending on Postgres setup. Supabase provides gen_random_uuid()

-- ENUM types
CREATE TYPE passenger_type AS ENUM ('radnik', 'ucenik', 'dnevni', 'other');
CREATE TYPE trip_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled');
CREATE TYPE payment_method AS ENUM ('kes', 'kartica', 'uplatnica', 'cash', 'card');

-- Users (common entity for passengers and drivers)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT,
    user_type passenger_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Monthly passengers
CREATE TABLE IF NOT EXISTS monthly_passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    passenger_type passenger_type NOT NULL,
    workplace TEXT,
    school TEXT,
    departure_address_bc TEXT,
    departure_address_vs TEXT,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Work schedules (relational, supports complex weekly patterns)
CREATE TABLE IF NOT EXISTS work_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    monthly_passenger_id UUID REFERENCES monthly_passengers(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Daily passengers
CREATE TABLE IF NOT EXISTS daily_passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    departure_address TEXT,
    destination_address TEXT,
    direction TEXT CHECK (direction IN ('bc_vrsac', 'vrsac_bc')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Drivers
CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    license_number TEXT UNIQUE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Rides (scheduled vehicle runs / departures)
CREATE TABLE IF NOT EXISTS rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    direction TEXT NOT NULL CHECK (direction IN ('bc_vrsac', 'vrsac_bc')),
    scheduled_departure TIMESTAMPTZ NOT NULL,
    actual_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    status trip_status NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Trips (link passengers to rides)
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    passenger_id UUID REFERENCES users(id) ON DELETE CASCADE,
    passenger_type passenger_type NOT NULL,
    boarding_time TIMESTAMPTZ,
    dropoff_time TIMESTAMPTZ,
    status trip_status NOT NULL DEFAULT 'scheduled',
    fare_amount NUMERIC(10,2) DEFAULT 0,
    payment_status TEXT CHECK (payment_status IN ('paid','unpaid','refunded')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Bookings (optional reservation layer)
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passenger_id UUID REFERENCES users(id) ON DELETE CASCADE,
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    seat_count INTEGER DEFAULT 1,
    booked_at TIMESTAMPTZ DEFAULT now(),
    status trip_status DEFAULT 'scheduled',
    cancelled_at TIMESTAMPTZ,
    cancel_reason TEXT,
    is_monthly BOOLEAN DEFAULT FALSE
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
    passenger_id UUID REFERENCES users(id) ON DELETE SET NULL,
    amount NUMERIC(10,2) NOT NULL,
    method payment_method DEFAULT 'kes',
    paid_at TIMESTAMPTZ DEFAULT now(),
    received_by TEXT,
    note TEXT
);

-- Driver logs / daily stats
CREATE TABLE IF NOT EXISTS driver_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    pickups INTEGER DEFAULT 0,
    cancellations INTEGER DEFAULT 0,
    small_change NUMERIC(10,2) DEFAULT 0,
    takings NUMERIC(12,2) DEFAULT 0,
    kilometers NUMERIC(10,2) DEFAULT 0,
    monthly_tickets_sold INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(driver_id, log_date)
);

-- Schedule exceptions for specific dates
CREATE TABLE IF NOT EXISTS schedule_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    monthly_passenger_id UUID REFERENCES monthly_passengers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    is_cancelled BOOLEAN DEFAULT FALSE,
    note TEXT
);

-- Routes and prices (optional)
CREATE TABLE IF NOT EXISTS routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origin TEXT,
    destination TEXT,
    price_monthly NUMERIC(10,2),
    price_daily NUMERIC(10,2),
    valid_from DATE,
    valid_to DATE,
    active BOOLEAN DEFAULT TRUE
);

-- Indexes for performance
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
    COUNT(t.*) FILTER (WHERE t.status = 'completed') as completed_trips,
    COUNT(t.*) FILTER (WHERE t.status = 'cancelled') as cancelled_trips,
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

-- Helper function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_reports() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
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

-- Notes: RLS policies and further fine-tuning (indexes, constraints) should be added based on deployment.
