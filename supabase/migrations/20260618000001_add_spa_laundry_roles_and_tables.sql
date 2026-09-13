-- ============================================================
-- Migration: Add Spa/Laundry roles, assigned_to columns, service_bills
-- Idempotent: safe to run multiple times
-- ============================================================

-- ── 1. Extend employee_role enum ────────────────────────────
-- ALTER TYPE ... ADD VALUE cannot run inside a transaction block.
-- Each ADD VALUE is its own statement.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'SPA_MANAGER'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'employee_role')
  ) THEN
    ALTER TYPE employee_role ADD VALUE 'SPA_MANAGER';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'SPA_EMPLOYEE'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'employee_role')
  ) THEN
    ALTER TYPE employee_role ADD VALUE 'SPA_EMPLOYEE';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'LAUNDRY_MANAGER'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'employee_role')
  ) THEN
    ALTER TYPE employee_role ADD VALUE 'LAUNDRY_MANAGER';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'LAUNDRY_EMPLOYEE'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'employee_role')
  ) THEN
    ALTER TYPE employee_role ADD VALUE 'LAUNDRY_EMPLOYEE';
  END IF;
END$$;

-- ── 2. Add assigned_to to spa_orders ────────────────────────
ALTER TABLE spa_orders
  ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES property_employees(emp_id) ON DELETE SET NULL;

-- ── 3. Add assigned_to to laundry_requests ──────────────────
ALTER TABLE laundry_requests
  ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES property_employees(emp_id) ON DELETE SET NULL;

-- ── 4. Create service_bills table ───────────────────────────
CREATE TABLE IF NOT EXISTS service_bills (
  bill_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  serv_id         UUID NOT NULL REFERENCES services(serv_id) ON DELETE RESTRICT,
  property_id     UUID NOT NULL REFERENCES hotel_property(property_id) ON DELETE CASCADE,
  stay_id         UUID NOT NULL REFERENCES stay(stay_id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  room_no         TEXT NOT NULL,
  amt             NUMERIC(10,2) NOT NULL CHECK (amt > 0),
  payment_status  TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status = ANY (ARRAY['unpaid'::text, 'paid'::text])),
  payment_method  TEXT,
  created_by      UUID REFERENCES property_employees(emp_id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ DEFAULT NULL
);

-- ── 5. updated_at trigger for service_bills ─────────────────
CREATE OR REPLACE FUNCTION set_service_bills_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_service_bills_updated_at ON service_bills;
CREATE TRIGGER trg_service_bills_updated_at
  BEFORE UPDATE ON service_bills
  FOR EACH ROW EXECUTE FUNCTION set_service_bills_updated_at();
