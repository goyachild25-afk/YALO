-- ============================================================
-- CRITICAL: Fix RLS Security Gaps
-- - Fix typo "authenticcated" → "authenticated"
-- - Restrict data access to only relevant users
-- - Ensure proper row-level security enforcement
-- ============================================================

-- ── 1. FIX TYPO IN DISPATCH POLICY (CRITICAL) ──────────────────────────────────
DROP POLICY IF EXISTS "View open requests" ON bookings;
CREATE POLICY "View open requests" ON bookings
  FOR SELECT TO authenticated
  USING (provider_id IS NULL AND status = 'pending');

-- ── 2. RESTRICT PROFILE ACCESS TO OWN PROFILE + RELATED USERS ─────────────────
DROP POLICY IF EXISTS "read_profiles_authenticated" ON profiles;
CREATE POLICY "read_profiles_own_or_related" ON profiles
  FOR SELECT TO authenticated
  USING (
    -- Own profile
    auth.uid() = id
    -- Profile of client in a booking
    OR auth.uid() IN (SELECT provider_id FROM bookings WHERE client_id = auth.uid())
    -- Profile of provider in a booking
    OR auth.uid() IN (SELECT client_id FROM bookings WHERE provider_id = auth.uid())
    -- Chat participants
    OR id IN (
      SELECT DISTINCT sender_id FROM chat_messages
      WHERE booking_id IN (
        SELECT id FROM bookings
        WHERE client_id = auth.uid() OR provider_id = auth.uid()
      )
    )
  );

-- ── 3. RESTRICT PROVIDER PROFILE ACCESS ────────────────────────────────────────
DROP POLICY IF EXISTS "read_provider_profiles_authenticated" ON provider_profiles;
CREATE POLICY "read_provider_profiles_browseable" ON provider_profiles
  FOR SELECT TO authenticated
  USING (
    -- Own profile
    user_id = auth.uid()
    -- Related via booking
    OR user_id IN (
      SELECT provider_id FROM bookings
      WHERE client_id = auth.uid() OR provider_id = auth.uid()
    )
  );

-- ── 4. RESTRICT BOOKING ACCESS ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "read_bookings_authenticated" ON bookings;
CREATE POLICY "read_bookings_own" ON bookings
  FOR SELECT TO authenticated
  USING (
    -- Own booking as client
    client_id = auth.uid()
    -- Own booking as provider
    OR provider_id = auth.uid()
    -- Browse open requests for providers (provider_id IS NULL means open)
    OR (provider_id IS NULL AND status = 'pending')
  );

-- ── 5. RESTRICT CHAT MESSAGE ACCESS ────────────────────────────────────────────
DROP POLICY IF EXISTS "read_chat_messages_authenticated" ON chat_messages;
CREATE POLICY "read_chat_messages_own_bookings" ON chat_messages
  FOR SELECT TO authenticated
  USING (
    booking_id IN (
      SELECT id FROM bookings
      WHERE client_id = auth.uid() OR provider_id = auth.uid()
    )
  );

-- ── 6. RESTRICT PROVIDER SERVICES ACCESS ───────────────────────────────────────
DROP POLICY IF EXISTS "read_provider_services_authenticated" ON provider_services;
CREATE POLICY "read_provider_services_public" ON provider_services
  FOR SELECT TO authenticated
  USING (is_active = TRUE);

-- ── 7. INSERT/UPDATE POLICIES ──────────────────────────────────────────────────
-- Allow users to update their own profile
DROP POLICY IF EXISTS "update_own_profile" ON profiles;
CREATE POLICY "update_own_profile" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to insert/update their own provider profile
DROP POLICY IF EXISTS "manage_own_provider_profile" ON provider_profiles;
CREATE POLICY "manage_own_provider_profile" ON provider_profiles
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow inserting own chat messages
DROP POLICY IF EXISTS "insert_chat_messages" ON chat_messages;
CREATE POLICY "insert_chat_messages" ON chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND booking_id IN (
      SELECT id FROM bookings
      WHERE client_id = auth.uid() OR provider_id = auth.uid()
    )
  );

-- Allow providers to manage their services
DROP POLICY IF EXISTS "manage_own_services" ON provider_services;
CREATE POLICY "manage_own_services" ON provider_services
  FOR ALL TO authenticated
  USING (provider_id IN (SELECT id FROM provider_profiles WHERE user_id = auth.uid()))
  WITH CHECK (provider_id IN (SELECT id FROM provider_profiles WHERE user_id = auth.uid()));

-- ── 8. VERIFICATION ────────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd FROM pg_policies
WHERE tablename IN ('profiles', 'provider_profiles', 'bookings', 'chat_messages', 'provider_services')
ORDER BY tablename, policyname;
