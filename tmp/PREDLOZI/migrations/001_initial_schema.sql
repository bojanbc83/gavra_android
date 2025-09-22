-- 001_initial_schema.sql
-- Types and core tables

CREATE TYPE passenger_type AS ENUM ('radnik', 'ucenik', 'dnevni', 'other');
CREATE TYPE trip_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled');
CREATE TYPE payment_method AS ENUM ('kes', 'kartica', 'uplatnica', 'cash', 'card');

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT,
    user_type passenger_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS schedule_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    monthly_passenger_id UUID REFERENCES monthly_passengers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    is_cancelled BOOLEAN DEFAULT FALSE,
    note TEXT
);

CREATE TABLE IF NOT EXISTS daily_passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    departure_address TEXT,
    destination_address TEXT,
    direction TEXT CHECK (direction IN ('bc_vrsac', 'vrsac_bc')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    license_number TEXT UNIQUE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

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
