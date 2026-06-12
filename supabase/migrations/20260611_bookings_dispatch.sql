-- Dispatch bookings: allow provider_id to be NULL initially (broadcast mode)
ALTER TABLE bookings
  ALTER COLUMN provider_id    DROP NOT NULL,
  ALTER COLUMN provider_name  DROP NOT NULL;

-- Make provider_avatar_url nullable if it isn't already
DO $$
BEGIN
  ALTER TABLE bookings ALTER COLUMN provider_avatar_url DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- New columns for broadcast dispatch
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS category_id     TEXT,
  ADD COLUMN IF NOT EXISTS client_province TEXT;

-- Index speeds up the "open requests" query in provider dashboard
CREATE INDEX IF NOT EXISTS idx_bookings_open_requests
  ON bookings (status, client_province)
  WHERE provider_id IS NULL AND status = 'pending';

-- RLS: providers can see broadcast bookings in their province
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'bookings' AND policyname = 'View open requests'
  ) THEN
    CREATE POLICY "View open requests" ON bookings
      FOR SELECT TO authenticated
      USING (provider_id IS NULL AND status = 'pending');
  END IF;
END $$;

-- RLS: providers can accept open requests (set provider_id on pending bookings)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'bookings' AND policyname = 'Accept open requests'
  ) THEN
    CREATE POLICY "Accept open requests" ON bookings
      FOR UPDATE TO authenticated
      USING  (provider_id IS NULL AND status = 'pending')
      WITH CHECK (provider_id IS NOT NULL);
  END IF;
END $$;
