-- rls_policies.sql (fixed syntax)
-- Idempotent RLS policies for key tables. DROP policy if exists then CREATE.

-- USERS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS users_admin_all ON users;
CREATE POLICY users_admin_all ON users
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS users_insert_authenticated ON users;
CREATE POLICY users_insert_authenticated ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated' AND id = auth.uid());

DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY users_select_own ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS users_update_own ON users;
CREATE POLICY users_update_own ON users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- DRIVERS
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS drivers_admin_all ON drivers;
CREATE POLICY drivers_admin_all ON drivers
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS drivers_select_driver ON drivers;
CREATE POLICY drivers_select_driver ON drivers
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS drivers_update_driver ON drivers;
CREATE POLICY drivers_update_driver ON drivers
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- RIDES
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rides_admin_select ON rides;
CREATE POLICY rides_admin_select ON rides
  FOR SELECT
  TO public
  USING (auth.role() = 'admin');

DROP POLICY IF EXISTS rides_select_driver ON rides;
CREATE POLICY rides_select_driver ON rides
  FOR SELECT
  TO authenticated
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS rides_insert_authenticated ON rides;
CREATE POLICY rides_insert_authenticated ON rides
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated');

-- DRIVER_LOGS
ALTER TABLE driver_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_logs_admin ON driver_logs;
CREATE POLICY driver_logs_admin ON driver_logs
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS driver_logs_select_own ON driver_logs;
CREATE POLICY driver_logs_select_own ON driver_logs
  FOR SELECT
  TO authenticated
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS driver_logs_insert_own ON driver_logs;
CREATE POLICY driver_logs_insert_own ON driver_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- PAYMENTS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payments_admin ON payments;
CREATE POLICY payments_admin ON payments
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS payments_select_passenger ON payments;
CREATE POLICY payments_select_passenger ON payments
  FOR SELECT
  TO authenticated
  USING (passenger_id = auth.uid());

DROP POLICY IF EXISTS payments_insert_authenticated ON payments;
CREATE POLICY payments_insert_authenticated ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated' AND passenger_id = auth.uid());

-- MONTHLY_PASSENGERS
ALTER TABLE monthly_passengers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS monthly_passengers_admin ON monthly_passengers;
CREATE POLICY monthly_passengers_admin ON monthly_passengers
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS monthly_passengers_select_owner ON monthly_passengers;
CREATE POLICY monthly_passengers_select_owner ON monthly_passengers
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS monthly_passengers_insert_authenticated ON monthly_passengers;
CREATE POLICY monthly_passengers_insert_authenticated ON monthly_passengers
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

-- BOOKINGS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bookings_admin ON bookings;
CREATE POLICY bookings_admin ON bookings
  FOR ALL
  TO public
  USING (auth.role() = 'admin')
  WITH CHECK (auth.role() = 'admin');

DROP POLICY IF EXISTS bookings_select_passenger ON bookings;
CREATE POLICY bookings_select_passenger ON bookings
  FOR SELECT
  TO authenticated
  USING (passenger_id = auth.uid());

DROP POLICY IF EXISTS bookings_insert_passenger ON bookings;
CREATE POLICY bookings_insert_passenger ON bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (passenger_id = auth.uid());

-- Final note: test these policies with your client roles (anon/authenticated/service_role) and adjust as necessary.
