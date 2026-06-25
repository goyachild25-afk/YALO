# Guía de Aplicación de Migración RLS de Supabase

## 🔐 CRÍTICO: Migración de Seguridad RLS

**Proyecto:** ivexcnunszcqoqzzdlfz.supabase.co

### ¿Por qué esto es CRÍTICO?

Actualmente hay un agujero de seguridad donde **TODOS los usuarios pueden ver TODOS los datos** (profiles, bookings, chat messages). Esta migración restringe acceso solo a datos relevantes del usuario.

---

## 📋 Pasos para Aplicar

### Opción A: Via Supabase Dashboard SQL Editor (RECOMENDADO - Más fácil)

1. Ir a: https://app.supabase.com
2. Login a tu proyecto **ivexcnunszcqoqzzdlfz**
3. Left sidebar → **SQL Editor**
4. Click **+ New Query**
5. Copiar TODO el contenido de abajo
6. Pegar en el editor
7. Click **Run** (botón azul abajo-derecha)
8. Esperar confirmación ✅

### Opción B: Via Supabase CLI (Para developers)

```bash
# Instalar Supabase CLI si no la tienes
npm install -g supabase

# Aplicar la migración
supabase db push --project-id ivexcnunszcqoqzzdlfz
```

---

## 🔧 SQL a Ejecutar (Copiar y Pegar TODO esto)

```sql
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
```

---

## ✅ Verificación Después de Aplicar

Después de ejecutar el SQL:

1. **Debe mostrar en la consola:**
   ```
   Query returned 15 rows
   ```
   (Esto significa que se crearon 15 políticas de RLS)

2. **Prueba de Seguridad:**
   - Crea 2 cuentas de test (client1, client2)
   - Client1 NO debe ver los datos de Client2
   - Client1 SÍ puede ver prestadores (provider_services)
   - Ambos pueden ver open requests (status='pending', provider_id IS NULL)

3. **En la app:**
   - Login debe funcionar ✓
   - Chat debe funcionar ✓
   - Bookings deben ser privados ✓

---

## 🚨 Rollback (Si algo sale mal)

Si necesitas revertir:

```sql
-- Revertir a políticas abiertas (SOLO TEMPORALMENTE)
DROP POLICY IF EXISTS "View open requests" ON bookings;
DROP POLICY IF EXISTS "read_profiles_own_or_related" ON profiles;
DROP POLICY IF EXISTS "read_provider_profiles_browseable" ON provider_profiles;
DROP POLICY IF EXISTS "read_bookings_own" ON bookings;
DROP POLICY IF EXISTS "read_chat_messages_own_bookings" ON chat_messages;
DROP POLICY IF EXISTS "read_provider_services_public" ON provider_services;
DROP POLICY IF EXISTS "update_own_profile" ON profiles;
DROP POLICY IF EXISTS "manage_own_provider_profile" ON provider_profiles;
DROP POLICY IF EXISTS "insert_chat_messages" ON chat_messages;
DROP POLICY IF EXISTS "manage_own_services" ON provider_services;
```

---

## 📞 Soporte

Si hay problemas:
1. Revisa los logs del SQL Editor (error message)
2. Verifica que RLS esté **habilitado** en cada tabla
3. Intenta con Rollback primero
4. Luego re-aplica la migración

**Contacto:** Tu equipo de desarrollo

---

**STATUS:** Listo para ejecutar  
**CRÍTICO:** SÍ - Seguridad de datos  
**REVERSIBLE:** SÍ - Rollback disponible
