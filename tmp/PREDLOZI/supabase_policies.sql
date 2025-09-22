-- Supabase RLS example policies (adjust role names and auth claims as needed)

-- NOTE: Supabase sets `auth.uid()` to the authenticated user's UUID from the auth system.
-- Adjust policies to match your JWT claim or role naming convention.
-- Supabase RLS example policies (adjust role names and auth claims as needed)

-- NOTE: Supabase sets `auth.uid()` to the authenticated user's UUID from the auth system.
-- Adjust policies to match your JWT claim or role naming convention.

-- USERS: Admin can manage all, users can view/update own record
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Allow admins to do anything (replace condition with your admin role check)
CREATE POLICY "users_admin_all" ON users
FOR ALL
TO public
USING (auth.role() = 'admin')
WITH CHECK (auth.role() = 'admin');

-- Allow authenticated users to insert their own user row (signup)
CREATE POLICY "users_insert_authenticated" ON users
FOR INSERT
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated' AND id = auth.uid());

-- Allow users to select/update their own record
CREATE POLICY "users_select_update_own" ON users
FOR SELECT, UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- DRIVERS: Admin can manage; driver can see own driver record
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "drivers_admin_select" ON drivers
FOR SELECT
USING (auth.role() = 'admin');

CREATE POLICY "drivers_select_driver" ON drivers
FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "drivers_update_driver" ON drivers
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- RIDES: Drivers see their rides; admins see all
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rides_admin_select" ON rides
FOR SELECT
USING (auth.role() = 'admin');

CREATE POLICY "rides_select_driver" ON rides
FOR SELECT
USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

CREATE POLICY "rides_insert_authenticated" ON rides
FOR INSERT
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- DRIVER_LOGS: drivers can insert and view only their log entries
ALTER TABLE driver_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "driver_logs_admin" ON driver_logs
FOR ALL
USING (auth.role() = 'admin')
WITH CHECK (auth.role() = 'admin');

CREATE POLICY "driver_logs_select_own" ON driver_logs
FOR SELECT
USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

CREATE POLICY "driver_logs_insert_own" ON driver_logs
FOR INSERT
USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- PAYMENTS: allow admin to see all; passengers see own payments
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "payments_admin" ON payments
FOR ALL
USING (auth.role() = 'admin')
WITH CHECK (auth.role() = 'admin');

CREATE POLICY "payments_select_passenger" ON payments
FOR SELECT
USING (passenger_id = auth.uid());

CREATE POLICY "payments_insert_authenticated" ON payments
FOR INSERT
USING (auth.role() = 'authenticated' AND passenger_id = auth.uid())
WITH CHECK (auth.role() = 'authenticated' AND passenger_id = auth.uid());

-- MONTHLY_PASSENGERS: owner can view their monthly passenger data
ALTER TABLE monthly_passengers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "monthly_passengers_admin" ON monthly_passengers
FOR ALL
USING (auth.role() = 'admin')
WITH CHECK (auth.role() = 'admin');

CREATE POLICY "monthly_passengers_select_owner" ON monthly_passengers
FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "monthly_passengers_insert_authenticated" ON monthly_passengers
FOR INSERT
USING (auth.role() = 'authenticated' AND user_id = auth.uid())
WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

-- BOOKINGS: passenger can create/view own bookings
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bookings_admin" ON bookings
FOR ALL
USING (auth.role() = 'admin')
WITH CHECK (auth.role() = 'admin');

CREATE POLICY "bookings_select_passenger" ON bookings
FOR SELECT
USING (passenger_id = auth.uid());

CREATE POLICY "bookings_insert_passenger" ON bookings
FOR INSERT
USING (passenger_id = auth.uid())
WITH CHECK (passenger_id = auth.uid());

-- Notes:
-- - Replace auth.role() checks with specific role conditions if you have roles like 'admin'.
-- - Make sure to test policies thoroughly in Supabase SQL editor before applying in production.
