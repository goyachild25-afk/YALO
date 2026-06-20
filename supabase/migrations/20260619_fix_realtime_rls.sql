-- ARREGLAR REALTIME SUSCRIBEEXCEPTION EN MÓVIL

-- 1. Asegurar que REPLICA IDENTITY está configurado
ALTER TABLE bookings REPLICA IDENTITY FULL;
ALTER TABLE profiles REPLICA IDENTITY FULL;
ALTER TABLE provider_profiles REPLICA IDENTITY FULL;
ALTER TABLE provider_services REPLICA IDENTITY FULL;
ALTER TABLE chat_messages REPLICA IDENTITY FULL;

-- 2. Asegurar que las tablas están en la publicación de realtime
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE provider_profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE provider_services;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- 3. Verificar que RLS está habilitado
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- 4. Políticas para bookings (permitir a autenticados leer)
DROP POLICY IF EXISTS "read_bookings_authenticated" ON bookings;
CREATE POLICY "read_bookings_authenticated" ON bookings
  FOR SELECT TO authenticated
  USING (true);

-- 5. Políticas para profiles (permitir a autenticados leer)
DROP POLICY IF EXISTS "read_profiles_authenticated" ON profiles;
CREATE POLICY "read_profiles_authenticated" ON profiles
  FOR SELECT TO authenticated
  USING (true);

-- 6. Políticas para provider_profiles (permitir a autenticados leer)
DROP POLICY IF EXISTS "read_provider_profiles_authenticated" ON provider_profiles;
CREATE POLICY "read_provider_profiles_authenticated" ON provider_profiles
  FOR SELECT TO authenticated
  USING (true);

-- 7. Políticas para provider_services (permitir a autenticados leer)
DROP POLICY IF EXISTS "read_provider_services_authenticated" ON provider_services;
CREATE POLICY "read_provider_services_authenticated" ON provider_services
  FOR SELECT TO authenticated
  USING (true);

-- 8. Políticas para chat_messages (permitir a autenticados leer)
DROP POLICY IF EXISTS "read_chat_messages_authenticated" ON chat_messages;
CREATE POLICY "read_chat_messages_authenticated" ON chat_messages
  FOR SELECT TO authenticated
  USING (true);

COMMIT;
