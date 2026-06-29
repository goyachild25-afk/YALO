-- ============================================================
-- Panel de administración: destrabar acceso de rol 'admin'
-- Ejecutar en: Supabase Dashboard → SQL Editor (o vía MCP apply_migration)
-- Idempotente.
--
-- Contexto: profiles.role solo permitía 'client'|'provider', por lo que
-- las políticas RLS que ya comparaban role = 'admin' (bookings, disputes,
-- provider_profiles, verification_requests) eran código muerto — ningún
-- usuario podía tener ese valor. Esto también destrababa "suspender" o
-- "promover a admin" desde el panel, ya que no existía ninguna política
-- que permitiera a un admin escribir sobre el perfil de OTRO usuario.
-- ============================================================

-- 1. Permitir 'admin' como valor válido de profiles.role
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('client', 'provider', 'admin'));

-- 2. Política: un admin puede leer/escribir cualquier fila de profiles
--    (necesario para suspender usuarios o promover nuevos admins)
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 3. Promover la cuenta admin inicial
UPDATE profiles SET role = 'admin'
WHERE id = '4dbea02e-0221-4e75-b09b-58a3f12173db';

-- 4. Corregir typo de la migración 20260619_fix_dispatch_accept_and_notify.sql
--    ("TO authenticcated" hizo fallar silenciosamente esta política — hoy es
--    inofensivo porque "provider_accept_booking" ya cubre el mismo acceso,
--    pero se recrea correctamente por prolijidad).
DROP POLICY IF EXISTS "View open requests" ON bookings;
CREATE POLICY "View open requests" ON bookings
  FOR SELECT TO authenticated
  USING (provider_id IS NULL AND status = 'pending');

-- 5. Verificación
SELECT id, email, role FROM profiles WHERE role = 'admin';
