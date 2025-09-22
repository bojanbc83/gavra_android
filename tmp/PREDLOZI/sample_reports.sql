-- Sample reports for merged schema

-- 1) Broj putovanja po mesecu po mesečnom putniku (completed and cancelled)
SELECT
  mp.id as monthly_passenger_id,
  u.full_name,
  DATE_TRUNC('month', t.created_at) as month,
  SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed_trips,
  SUM(CASE WHEN t.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_trips,
  COALESCE(SUM(p.amount),0) as total_paid
FROM monthly_passengers mp
JOIN users u ON mp.user_id = u.id
LEFT JOIN trips t ON u.id = t.passenger_id
LEFT JOIN payments p ON p.trip_id = t.id
GROUP BY mp.id, u.full_name, DATE_TRUNC('month', t.created_at)
ORDER BY month DESC;

-- 2) Ukupan broj otkazivanja i vreme otkazivanja za svakog putnika u mesecu
SELECT
  u.full_name,
  SUM(CASE WHEN b.status = 'cancelled' AND DATE_TRUNC('month', b.cancelled_at) = DATE_TRUNC('month', CURRENT_DATE) THEN 1 ELSE 0 END) as cancelled_count_this_month,
  MAX(CASE WHEN b.status = 'cancelled' THEN b.cancelled_at ELSE NULL END) as last_cancelled_at
FROM bookings b
JOIN users u ON b.passenger_id = u.id
GROUP BY u.full_name
ORDER BY cancelled_count_this_month DESC;

-- 3) Koliko puta su platili po mesecu i ukupan iznos po putniku
SELECT
  u.full_name,
  DATE_TRUNC('month', p.paid_at) as month,
  COUNT(p.id) as payments_count,
  SUM(p.amount) as total_amount
FROM payments p
JOIN users u ON p.passenger_id = u.id
GROUP BY u.full_name, DATE_TRUNC('month', p.paid_at)
ORDER BY month DESC, total_amount DESC;

-- 4) Dnevni pazar po vozaču (uz trips i driver_logs)
SELECT
  d.id as driver_id,
  u.full_name,
  dl.log_date,
  SUM(dl.takings) as total_takings,
  SUM(dl.monthly_tickets_sold) as monthly_tickets_sold
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
JOIN users u ON d.user_id = u.id
GROUP BY d.id, u.full_name, dl.log_date
ORDER BY dl.log_date DESC;

-- 5) Peak hours (broj putnika po satu polaska)
SELECT DATE_TRUNC('hour', r.scheduled_departure) as hour, COUNT(t.id) as bookings
FROM rides r
JOIN trips t ON r.id = t.ride_id
GROUP BY hour
ORDER BY bookings DESC
LIMIT 20;

-- 6) Lista putnika sa fleksibilnim rasporedom (iz work_schedules + exceptions)
SELECT mp.id, u.full_name, ws.day_of_week, ws.start_time, ws.end_time, se.date as exception_date, se.is_cancelled
FROM monthly_passengers mp
JOIN users u ON mp.user_id = u.id
LEFT JOIN work_schedules ws ON mp.id = ws.monthly_passenger_id
LEFT JOIN schedule_exceptions se ON mp.id = se.monthly_passenger_id
ORDER BY u.full_name, ws.day_of_week;
