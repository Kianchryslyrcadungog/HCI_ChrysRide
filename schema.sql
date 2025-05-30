-- Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ================= USERS =================
CREATE TABLE IF NOT EXISTS users (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_uid UUID UNIQUE,  -- links to auth.users.id
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT CHECK (role IN ('driver', 'passenger')) NOT NULL,
  phone_number TEXT NOT NULL,
  profile_picture TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ================= VEHICLES =================
CREATE TABLE IF NOT EXISTS vehicles (
  vehicle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
  plate_no TEXT UNIQUE NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INT,
  color TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Only drivers can register vehicles
CREATE OR REPLACE FUNCTION check_driver_role()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users WHERE user_id = NEW.user_id AND role = 'driver'
  ) THEN
    RAISE EXCEPTION 'Only users with role=driver can register vehicles.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_driver ON vehicles;
CREATE TRIGGER validate_driver
BEFORE INSERT ON vehicles
FOR EACH ROW
EXECUTE FUNCTION check_driver_role();

-- ================= RIDES =================
CREATE TABLE IF NOT EXISTS rides (
  ride_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
  driver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
  vehicle_id UUID REFERENCES vehicles(vehicle_id) ON DELETE SET NULL,
  pickup TEXT NOT NULL,
  dropoff TEXT NOT NULL,
  status TEXT CHECK (status IN ('requested', 'accepted', 'ongoing', 'completed', 'cancelled')) NOT NULL DEFAULT 'requested',
  fare DECIMAL(10, 2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Validate correct passenger and driver roles
CREATE OR REPLACE FUNCTION check_ride_roles()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users WHERE user_id = NEW.passenger_id AND role = 'passenger'
  ) THEN
    RAISE EXCEPTION 'Invalid: passenger_id must belong to a user with role = passenger';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM users WHERE user_id = NEW.driver_id AND role = 'driver'
  ) THEN
    RAISE EXCEPTION 'Invalid: driver_id must belong to a user with role = driver';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_ride_roles ON rides;
CREATE TRIGGER validate_ride_roles
BEFORE INSERT ON rides
FOR EACH ROW
EXECUTE FUNCTION check_ride_roles();

-- ================= PAYMENTS =================
CREATE TABLE IF NOT EXISTS payments (
  payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(ride_id) ON DELETE CASCADE,
  passenger_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
  amount DECIMAL(10, 2) NOT NULL,
  method TEXT CHECK (method IN ('cash', 'card', 'gcash')) NOT NULL,
  status TEXT CHECK (status IN ('success', 'pending', 'failed')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Validate that the paying user is the correct passenger for the ride
CREATE OR REPLACE FUNCTION check_payment_validity()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users WHERE user_id = NEW.passenger_id AND role = 'passenger'
  ) THEN
    RAISE EXCEPTION 'Invalid: passenger_id must belong to a user with role = passenger';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM rides WHERE ride_id = NEW.ride_id AND passenger_id = NEW.passenger_id
  ) THEN
    RAISE EXCEPTION 'Invalid: The ride does not belong to the passenger';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_payment ON payments;
CREATE TRIGGER validate_payment
BEFORE INSERT ON payments
FOR EACH ROW
EXECUTE FUNCTION check_payment_validity();

-- ================= RIDE STATUS LOGS =================
CREATE TABLE IF NOT EXISTS ride_status_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(ride_id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('completed', 'cancelled')) NOT NULL,
  changed_at TIMESTAMP DEFAULT NOW()
);

-- Log ride completion or cancellation
CREATE OR REPLACE FUNCTION log_final_ride_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled') AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO ride_status_logs (ride_id, status)
    VALUES (NEW.ride_id, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_log_ride_status ON rides;
CREATE TRIGGER trigger_log_ride_status
AFTER UPDATE ON rides
FOR EACH ROW
EXECUTE FUNCTION log_final_ride_status();

-- ================= RATINGS =================
CREATE TABLE IF NOT EXISTS ratings (
  rating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID UNIQUE REFERENCES rides(ride_id) ON DELETE CASCADE,
  passenger_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
  rating INT CHECK (rating BETWEEN 1 AND 5) NOT NULL,
  comment TEXT,
  rated_at TIMESTAMP DEFAULT NOW()
);

-- Allow reviews for completed or cancelled rides
CREATE OR REPLACE FUNCTION validate_ride_feedback()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM rides
    WHERE ride_id = NEW.ride_id AND status IN ('completed', 'cancelled')
  ) THEN
    RAISE EXCEPTION 'You can only review completed or cancelled rides.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_rating ON ratings;
CREATE TRIGGER trigger_validate_rating
BEFORE INSERT ON ratings
FOR EACH ROW
EXECUTE FUNCTION validate_ride_feedback();
